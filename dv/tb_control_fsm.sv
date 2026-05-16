`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_control_fsm
// Description: Directed unit testbench for control_fsm (6-state Moore FSM)
//              SystemVerilog — SVA assertions + functional coverage, no UVM
//
// Test List:
//   TC1: test_reset_to_idle       — Reset brings FSM to IDLE
//   TC2: test_idle_to_scan        — IDLE transitions to SCAN_ROW unconditionally
//   TC3: test_scan_no_key         — SCAN_ROW holds when col_valid=0
//   TC4: test_scan_to_sample      — SCAN_ROW → SAMPLE_COL on col_valid
//   TC5: test_sample_to_debounce  — SAMPLE_COL → DEBOUNCE (unconditional)
//   TC6: test_debounce_wait       — DEBOUNCE holds when debounced_press=0
//   TC7: test_debounce_to_valid   — DEBOUNCE → KEY_VALID on debounced_press
//   TC8: test_valid_to_wait_rel   — KEY_VALID → WAIT_RELEASE (unconditional)
//   TC9: test_wait_release_hold   — WAIT_RELEASE holds when debounced_release=0
//   TC10: test_wait_to_scan       — WAIT_RELEASE → SCAN_ROW on debounced_release
//   TC11: test_full_cycle         — Complete FSM cycle end-to-end
//   TC12: test_output_per_state   — Verify all 4 outputs in every state
//   TC13: test_reset_from_debounce— Reset mid-DEBOUNCE cleans up
//   TC14: test_back_to_back_keys  — Two consecutive key cycles
//////////////////////////////////////////////////////////////////////////////////

module tb_control_fsm;

  //===========================================================================
  // Parameters
  //===========================================================================
  localparam CLK_PERIOD = 10;

  // FSM state encodings (mirror DUT localparams)
  localparam [2:0] IDLE         = 3'b000,
                   SCAN_ROW     = 3'b001,
                   SAMPLE_COL   = 3'b010,
                   DEBOUNCE     = 3'b011,
                   KEY_VALID    = 3'b100,
                   WAIT_RELEASE = 3'b101;

  //===========================================================================
  // DUT Signals
  //===========================================================================
  reg  clk, rst_n;
  reg  col_valid, debounced_press, debounced_release;
  wire row_scan_en, debounce_en, key_latch_en, key_valid;

  //===========================================================================
  // Test Tracking
  //===========================================================================
  integer pass_count = 0;
  integer fail_count = 0;

  //===========================================================================
  // DUT Instantiation
  //===========================================================================
  control_fsm dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .col_valid        (col_valid),
    .debounced_press  (debounced_press),
    .debounced_release(debounced_release),
    .row_scan_en      (row_scan_en),
    .debounce_en      (debounce_en),
    .key_latch_en     (key_latch_en),
    .key_valid        (key_valid)
  );

  // Hierarchical state access
  wire [2:0] dut_state = dut.state;

  //===========================================================================
  // Clock
  //===========================================================================
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  //===========================================================================
  // SVA Assertions (A1–A10)
  //===========================================================================

  // A1: State must always be one of the 6 legal values
  a1_legal_state: assert property (
    @(posedge clk) disable iff (!rst_n)
    dut_state inside {IDLE, SCAN_ROW, SAMPLE_COL, DEBOUNCE, KEY_VALID, WAIT_RELEASE}
  ) else $error("[A1 FAIL] Illegal state: %0b", dut_state);

  // A2: IDLE always transitions to SCAN_ROW
  a2_idle_to_scan: assert property (
    @(posedge clk) disable iff (!rst_n)
    (dut_state == IDLE) |=> (dut_state == SCAN_ROW)
  ) else $error("[A2 FAIL] IDLE did not transition to SCAN_ROW");

  // A3: SCAN_ROW → SAMPLE_COL only when col_valid
  a3_scan_to_sample: assert property (
    @(posedge clk) disable iff (!rst_n)
    (dut_state == SCAN_ROW && col_valid) |=> (dut_state == SAMPLE_COL)
  ) else $error("[A3 FAIL] SCAN_ROW did not go to SAMPLE_COL on col_valid");

  // A4: SAMPLE_COL always transitions to DEBOUNCE
  a4_sample_to_debounce: assert property (
    @(posedge clk) disable iff (!rst_n)
    (dut_state == SAMPLE_COL) |=> (dut_state == DEBOUNCE)
  ) else $error("[A4 FAIL] SAMPLE_COL did not go to DEBOUNCE");

  // A5: DEBOUNCE → KEY_VALID only when debounced_press
  a5_debounce_to_valid: assert property (
    @(posedge clk) disable iff (!rst_n)
    (dut_state == DEBOUNCE && debounced_press) |=> (dut_state == KEY_VALID)
  ) else $error("[A5 FAIL] DEBOUNCE did not go to KEY_VALID on debounced_press");

  // A6: KEY_VALID always transitions to WAIT_RELEASE
  a6_valid_to_wait: assert property (
    @(posedge clk) disable iff (!rst_n)
    (dut_state == KEY_VALID) |=> (dut_state == WAIT_RELEASE)
  ) else $error("[A6 FAIL] KEY_VALID did not go to WAIT_RELEASE");

  // A7: WAIT_RELEASE → SCAN_ROW only when debounced_release
  a7_wait_to_scan: assert property (
    @(posedge clk) disable iff (!rst_n)
    (dut_state == WAIT_RELEASE && debounced_release) |=> (dut_state == SCAN_ROW)
  ) else $error("[A7 FAIL] WAIT_RELEASE did not go to SCAN_ROW on debounced_release");

  // A8: row_scan_en and debounce_en never both high
  a8_mutual_exclusion: assert property (
    @(posedge clk) disable iff (!rst_n)
    !(row_scan_en && debounce_en)
  ) else $error("[A8 FAIL] row_scan_en and debounce_en both high");

  // A9: key_valid implies row_scan_en is 0
  a9_valid_no_scan: assert property (
    @(posedge clk) disable iff (!rst_n)
    key_valid |-> !row_scan_en
  ) else $error("[A9 FAIL] key_valid and row_scan_en both high");

  // A10: key_latch_en only in SAMPLE_COL
  a10_latch_only_sample: assert property (
    @(posedge clk) disable iff (!rst_n)
    key_latch_en |-> (dut_state == SAMPLE_COL)
  ) else $error("[A10 FAIL] key_latch_en asserted outside SAMPLE_COL");

  //===========================================================================
  // Functional Coverage
  //===========================================================================
  covergroup cg_fsm_states @(posedge clk);
    cp_state: coverpoint dut_state {
      bins idle         = {IDLE};
      bins scan_row     = {SCAN_ROW};
      bins sample_col   = {SAMPLE_COL};
      bins debounce     = {DEBOUNCE};
      bins key_valid_st = {KEY_VALID};
      bins wait_release = {WAIT_RELEASE};
      illegal_bins illegal = {3'b110, 3'b111};
    }

    cp_transitions: coverpoint dut_state {
      bins idle_to_scan       = (IDLE         => SCAN_ROW);
      bins scan_hold          = (SCAN_ROW     => SCAN_ROW);
      bins scan_to_sample     = (SCAN_ROW     => SAMPLE_COL);
      bins sample_to_debounce = (SAMPLE_COL   => DEBOUNCE);
      bins debounce_hold      = (DEBOUNCE     => DEBOUNCE);
      bins debounce_to_valid  = (DEBOUNCE     => KEY_VALID);
      bins valid_to_wait      = (KEY_VALID    => WAIT_RELEASE);
      bins wait_hold          = (WAIT_RELEASE => WAIT_RELEASE);
      bins wait_to_scan       = (WAIT_RELEASE => SCAN_ROW);
    }

    cp_outputs: coverpoint {row_scan_en, debounce_en, key_latch_en, key_valid} {
      bins scan_active    = {4'b1000};
      bins latch_active   = {4'b0010};
      bins debounce_active= {4'b0100};
      bins valid_active   = {4'b0001};
      bins all_off        = {4'b0000};
    }
  endgroup

  cg_fsm_states cov_fsm = new();

  //===========================================================================
  // Helper Tasks
  //===========================================================================
  task automatic apply_reset(int cycles = 3);
    rst_n = 0;
    col_valid = 0;
    debounced_press = 0;
    debounced_release = 0;
    repeat(cycles) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
  endtask

  task automatic wait_clks(int n);
    repeat(n) @(posedge clk);
  endtask

  // Drive FSM through: IDLE → SCAN_ROW → SAMPLE_COL → DEBOUNCE
  // (common setup for many tests)
  task automatic drive_to_debounce();
    // IDLE → SCAN_ROW (automatic, 1 cycle)
    @(posedge clk);
    // SCAN_ROW: assert col_valid to move to SAMPLE_COL
    col_valid = 1;
    @(posedge clk);
    col_valid = 0;
    // SAMPLE_COL → DEBOUNCE (automatic, 1 cycle)
    @(posedge clk);
  endtask

  // Drive FSM all the way to WAIT_RELEASE
  task automatic drive_to_wait_release();
    drive_to_debounce();
    // DEBOUNCE: assert debounced_press
    debounced_press = 1;
    @(posedge clk);
    debounced_press = 0;
    // KEY_VALID → WAIT_RELEASE (automatic, 1 cycle)
    @(posedge clk);
  endtask

  task automatic check(string tc, bit cond, string msg = "");
    if (cond) begin
      $display("[PASS] %s %s", tc, msg);
      pass_count++;
    end else begin
      $display("[FAIL] %s %s", tc, msg);
      fail_count++;
    end
  endtask

  // Check all 4 outputs match expected values
  task automatic check_outputs(string tc,
    bit exp_scan, bit exp_deb, bit exp_latch, bit exp_valid);
    check(tc, row_scan_en  == exp_scan,
      $sformatf("row_scan_en: exp=%0b got=%0b", exp_scan, row_scan_en));
    check(tc, debounce_en  == exp_deb,
      $sformatf("debounce_en: exp=%0b got=%0b", exp_deb, debounce_en));
    check(tc, key_latch_en == exp_latch,
      $sformatf("key_latch_en: exp=%0b got=%0b", exp_latch, key_latch_en));
    check(tc, key_valid    == exp_valid,
      $sformatf("key_valid: exp=%0b got=%0b", exp_valid, key_valid));
  endtask

  //===========================================================================
  // Test Cases
  //===========================================================================

  task automatic test_reset_to_idle();  // TC1
    $display("\n===== TC1: test_reset_to_idle =====");
    apply_reset();
    // After reset, state should be IDLE (but IDLE→SCAN_ROW is immediate next cycle)
    // Check at the reset deassertion edge
    check("TC1", dut_state == IDLE || dut_state == SCAN_ROW,
      $sformatf("State after reset: %0b", dut_state));
  endtask

  task automatic test_idle_to_scan();  // TC2
    $display("\n===== TC2: test_idle_to_scan =====");
    apply_reset();
    // IDLE is 1 cycle, then automatically SCAN_ROW
    wait_clks(1);
    check("TC2", dut_state == SCAN_ROW,
      $sformatf("Expected SCAN_ROW, got %0b", dut_state));
  endtask

  task automatic test_scan_no_key();  // TC3
    $display("\n===== TC3: test_scan_no_key =====");
    apply_reset();
    wait_clks(1); // get to SCAN_ROW
    col_valid = 0;
    wait_clks(10);
    check("TC3", dut_state == SCAN_ROW,
      "FSM should hold in SCAN_ROW when col_valid=0");
  endtask

  task automatic test_scan_to_sample();  // TC4
    $display("\n===== TC4: test_scan_to_sample =====");
    apply_reset();
    wait_clks(1); // SCAN_ROW
    col_valid = 1;
    @(posedge clk);
    check("TC4", dut_state == SAMPLE_COL,
      $sformatf("Expected SAMPLE_COL, got %0b", dut_state));
    col_valid = 0;
  endtask

  task automatic test_sample_to_debounce();  // TC5
    $display("\n===== TC5: test_sample_to_debounce =====");
    apply_reset();
    wait_clks(1);
    col_valid = 1; @(posedge clk); col_valid = 0; // → SAMPLE_COL
    @(posedge clk); // SAMPLE_COL → DEBOUNCE
    check("TC5", dut_state == DEBOUNCE,
      $sformatf("Expected DEBOUNCE, got %0b", dut_state));
  endtask

  task automatic test_debounce_wait();  // TC6
    $display("\n===== TC6: test_debounce_wait =====");
    apply_reset();
    drive_to_debounce();
    debounced_press = 0;
    wait_clks(10);
    check("TC6", dut_state == DEBOUNCE,
      "FSM should hold in DEBOUNCE when debounced_press=0");
  endtask

  task automatic test_debounce_to_valid();  // TC7
    $display("\n===== TC7: test_debounce_to_valid =====");
    apply_reset();
    drive_to_debounce();
    debounced_press = 1;
    @(posedge clk);
    debounced_press = 0;
    check("TC7", dut_state == KEY_VALID,
      $sformatf("Expected KEY_VALID, got %0b", dut_state));
  endtask

  task automatic test_valid_to_wait_rel();  // TC8
    $display("\n===== TC8: test_valid_to_wait_rel =====");
    apply_reset();
    drive_to_debounce();
    debounced_press = 1; @(posedge clk); debounced_press = 0; // → KEY_VALID
    @(posedge clk); // KEY_VALID → WAIT_RELEASE
    check("TC8", dut_state == WAIT_RELEASE,
      $sformatf("Expected WAIT_RELEASE, got %0b", dut_state));
  endtask

  task automatic test_wait_release_hold();  // TC9
    $display("\n===== TC9: test_wait_release_hold =====");
    apply_reset();
    drive_to_wait_release();
    debounced_release = 0;
    wait_clks(10);
    check("TC9", dut_state == WAIT_RELEASE,
      "FSM should hold in WAIT_RELEASE when debounced_release=0");
  endtask

  task automatic test_wait_to_scan();  // TC10
    $display("\n===== TC10: test_wait_to_scan =====");
    apply_reset();
    drive_to_wait_release();
    debounced_release = 1;
    @(posedge clk);
    debounced_release = 0;
    check("TC10", dut_state == SCAN_ROW,
      $sformatf("Expected SCAN_ROW, got %0b", dut_state));
  endtask

  task automatic test_full_cycle();  // TC11
    $display("\n===== TC11: test_full_cycle =====");
    apply_reset();

    // Track every state visited
    wait_clks(1); // IDLE → SCAN_ROW
    check("TC11", dut_state == SCAN_ROW, "Step 1: SCAN_ROW");

    col_valid = 1; @(posedge clk); col_valid = 0;
    check("TC11", dut_state == SAMPLE_COL, "Step 2: SAMPLE_COL");

    @(posedge clk);
    check("TC11", dut_state == DEBOUNCE, "Step 3: DEBOUNCE");

    debounced_press = 1; @(posedge clk); debounced_press = 0;
    check("TC11", dut_state == KEY_VALID, "Step 4: KEY_VALID");

    @(posedge clk);
    check("TC11", dut_state == WAIT_RELEASE, "Step 5: WAIT_RELEASE");

    debounced_release = 1; @(posedge clk); debounced_release = 0;
    check("TC11", dut_state == SCAN_ROW, "Step 6: back to SCAN_ROW");
  endtask

  task automatic test_output_per_state();  // TC12
    $display("\n===== TC12: test_output_per_state =====");
    apply_reset();

    // IDLE (outputs visible combinationally)
    // After reset, IDLE is brief — check on same cycle
    // Actually after apply_reset we already advanced 1 clk past rst_n=1
    // So we might be in SCAN_ROW. Let's just do a fresh reset and check immediately.
    rst_n = 0; @(posedge clk); rst_n = 1;
    // Now state=IDLE, outputs should reflect IDLE (row_scan_en=1)
    #1; // small delta for combinational output settle
    check_outputs("TC12-IDLE", 1, 0, 0, 0);

    @(posedge clk); // → SCAN_ROW
    #1;
    check_outputs("TC12-SCAN_ROW", 1, 0, 0, 0);

    col_valid = 1; @(posedge clk); col_valid = 0; // → SAMPLE_COL
    #1;
    check_outputs("TC12-SAMPLE_COL", 0, 0, 1, 0);

    @(posedge clk); // → DEBOUNCE
    #1;
    check_outputs("TC12-DEBOUNCE", 0, 1, 0, 0);

    debounced_press = 1; @(posedge clk); debounced_press = 0; // → KEY_VALID
    #1;
    check_outputs("TC12-KEY_VALID", 0, 0, 0, 1);

    @(posedge clk); // → WAIT_RELEASE
    #1;
    check_outputs("TC12-WAIT_RELEASE", 0, 0, 0, 1);
  endtask

  task automatic test_reset_from_debounce();  // TC13
    $display("\n===== TC13: test_reset_from_debounce =====");
    apply_reset();
    drive_to_debounce();
    check("TC13", dut_state == DEBOUNCE, "Reached DEBOUNCE");

    // Assert reset
    rst_n = 0;
    @(posedge clk);
    check("TC13", dut_state == IDLE, "Reset → IDLE");
    #1;
    check_outputs("TC13-RST", 1, 0, 0, 0); // IDLE outputs

    rst_n = 1;
    wait_clks(2);
  endtask

  task automatic test_back_to_back_keys();  // TC14
    $display("\n===== TC14: test_back_to_back_keys =====");
    apply_reset();

    // First key cycle
    drive_to_wait_release();
    debounced_release = 1; @(posedge clk); debounced_release = 0;
    check("TC14", dut_state == SCAN_ROW, "1st cycle: back to SCAN_ROW");

    // Second key cycle (immediately)
    col_valid = 1; @(posedge clk); col_valid = 0;
    check("TC14", dut_state == SAMPLE_COL, "2nd cycle: SAMPLE_COL");

    @(posedge clk); // → DEBOUNCE
    debounced_press = 1; @(posedge clk); debounced_press = 0;
    check("TC14", dut_state == KEY_VALID, "2nd cycle: KEY_VALID");

    @(posedge clk); // → WAIT_RELEASE
    debounced_release = 1; @(posedge clk); debounced_release = 0;
    check("TC14", dut_state == SCAN_ROW, "2nd cycle: back to SCAN_ROW");
  endtask

  //===========================================================================
  // Main Test Sequencer
  //===========================================================================
  initial begin
    $dumpfile("tb_control_fsm.vcd");
    $dumpvars(0, tb_control_fsm);

    $display("==========================================================");
    $display(" Control FSM Testbench — Directed Tests");
    $display("==========================================================");

    test_reset_to_idle();
    test_idle_to_scan();
    test_scan_no_key();
    test_scan_to_sample();
    test_sample_to_debounce();
    test_debounce_wait();
    test_debounce_to_valid();
    test_valid_to_wait_rel();
    test_wait_release_hold();
    test_wait_to_scan();
    test_full_cycle();
    test_output_per_state();
    test_reset_from_debounce();
    test_back_to_back_keys();

    $display("\n==========================================================");
    $display(" TEST SUMMARY");
    $display("==========================================================");
    $display(" Total checks:  %0d", pass_count + fail_count);
    $display(" Passed:        %0d", pass_count);
    $display(" Failed:        %0d", fail_count);
    $display("==========================================================");
    if (fail_count == 0)
      $display(" >>> ALL TESTS PASSED <<<");
    else
      $display(" >>> %0d TESTS FAILED <<<", fail_count);
    $display("==========================================================\n");

    #100;
    $finish;
  end

  // Timeout watchdog
  initial begin
    #500_000;
    $display("[TIMEOUT] Simulation exceeded maximum time");
    $finish;
  end

endmodule

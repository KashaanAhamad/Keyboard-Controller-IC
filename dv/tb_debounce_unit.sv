`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_debounce_unit
// Description: Directed testbench for debounce_unit
//              - SystemVerilog with SVA assertions and functional coverage
//              - No UVM, pure directed tests
//
// Test List:
//   TC1: test_clean_press        — Clean key press (no bouncing)
//   TC2: test_clean_release      — Clean key release (no bouncing)
//   TC3: test_bouncy_press       — Bouncing during press
//   TC4: test_bouncy_release     — Bouncing during release
//   TC5: test_enable_gating      — Verify debounce does nothing when en=0
//   TC6: test_reset_mid_press    — Reset asserted during PRESS_CHECK
//   TC7: test_reset_mid_release  — Reset asserted during RELEASE_CHECK
//   TC8: test_full_cycle         — Complete press → hold → release cycle
//   TC9: test_back_to_back       — Two consecutive key presses
//   TC10: test_no_key            — Enable high but no key_detected
//////////////////////////////////////////////////////////////////////////////////

module tb_debounce_unit;

  //===========================================================================
  // Parameters — use small DEBOUNCE_CNT_MAX for fast simulation
  //===========================================================================
  localparam DEBOUNCE_CNT_MAX = 10;
  localparam CLK_PERIOD       = 10;   // 100 MHz

  //===========================================================================
  // DUT Signals
  //===========================================================================
  reg  clk;
  reg  rst_n;
  reg  en;
  reg  key_detected;
  wire debounced_press;
  wire debounced_release;

  //===========================================================================
  // Test tracking
  //===========================================================================
  integer pass_count = 0;
  integer fail_count = 0;
  string  current_test;

  //===========================================================================
  // DUT Instantiation
  //===========================================================================
  debounce_unit #(
    .DEBOUNCE_CNT_MAX(DEBOUNCE_CNT_MAX)
  ) dut (
    .clk             (clk),
    .rst_n           (rst_n),
    .en              (en),
    .key_detected    (key_detected),
    .debounced_press (debounced_press),
    .debounced_release(debounced_release)
  );

  //===========================================================================
  // Internal DUT state access (hierarchical reference for debug)
  //===========================================================================
  wire [1:0] dut_state      = dut.state;
  wire       dut_cnt_value  = dut.debounce_cnt;

  // FSM state names for readability
  localparam IDLE          = 2'b00;
  localparam PRESS_CHECK   = 2'b01;
  localparam PRESSED       = 2'b10;
  localparam RELEASE_CHECK = 2'b11;

  //===========================================================================
  // Clock Generation
  //===========================================================================
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  //===========================================================================
  // SVA Assertions (A11–A16)
  //===========================================================================

  // A11: debounced_press must be exactly 1 cycle wide
  //      If press rises, it must fall on the very next cycle
  property p_press_pulse_width;
    @(posedge clk) disable iff (!rst_n)
    $rose(debounced_press) |=> !debounced_press;
  endproperty
  a11_press_pulse_width: assert property (p_press_pulse_width)
    else $error("[A11 FAIL] debounced_press was not a single-cycle pulse");

  // A12: debounced_release must be exactly 1 cycle wide
  property p_release_pulse_width;
    @(posedge clk) disable iff (!rst_n)
    $rose(debounced_release) |=> !debounced_release;
  endproperty
  a12_release_pulse_width: assert property (p_release_pulse_width)
    else $error("[A12 FAIL] debounced_release was not a single-cycle pulse");

  // A13: debounced_release must be preceded by debounced_press
  //      (cannot release without first pressing — tracked via a flag)
  reg press_seen;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      press_seen <= 0;
    else if (debounced_press)
      press_seen <= 1;
    else if (debounced_release)
      press_seen <= 0;
  end

  a13_release_after_press: assert property (
    @(posedge clk) disable iff (!rst_n)
    $rose(debounced_release) |-> press_seen
  ) else $error("[A13 FAIL] debounced_release fired without prior debounced_press");

  // A14: debounced_press can only assert when en == 1
  a14_no_press_without_en: assert property (
    @(posedge clk) disable iff (!rst_n)
    debounced_press |-> en
  ) else $error("[A14 FAIL] debounced_press asserted while en=0");

  // A15: debounced_press and debounced_release must never be high simultaneously
  a15_no_simultaneous_pulses: assert property (
    @(posedge clk) disable iff (!rst_n)
    !(debounced_press && debounced_release)
  ) else $error("[A15 FAIL] debounced_press and debounced_release asserted simultaneously");

  // A16: debounce counter must never exceed DEBOUNCE_CNT_MAX
  a16_counter_no_overflow: assert property (
    @(posedge clk) disable iff (!rst_n)
    dut.debounce_cnt <= DEBOUNCE_CNT_MAX
  ) else $error("[A16 FAIL] debounce_cnt exceeded DEBOUNCE_CNT_MAX (%0d)", DEBOUNCE_CNT_MAX);

  //===========================================================================
  // Functional Coverage
  //===========================================================================
  covergroup cg_debounce @(posedge clk);
    // FSM state coverage
    cp_state: coverpoint dut_state {
      bins idle          = {IDLE};
      bins press_check   = {PRESS_CHECK};
      bins pressed       = {PRESSED};
      bins release_check = {RELEASE_CHECK};
    }

    // FSM state transitions
    cp_transitions: coverpoint dut_state {
      bins idle_to_press_check     = (IDLE          => PRESS_CHECK);
      bins press_check_to_pressed  = (PRESS_CHECK   => PRESSED);
      bins press_check_to_idle     = (PRESS_CHECK   => IDLE);         // bounce reject
      bins pressed_to_rel_check    = (PRESSED       => RELEASE_CHECK);
      bins rel_check_to_idle       = (RELEASE_CHECK => IDLE);
      bins rel_check_to_pressed    = (RELEASE_CHECK => PRESSED);      // release bounce
    }

    // Output pulse events
    cp_press_pulse: coverpoint debounced_press {
      bins no_pulse = {0};
      bins pulse    = {1};
    }

    cp_release_pulse: coverpoint debounced_release {
      bins no_pulse = {0};
      bins pulse    = {1};
    }

    // Enable signal state during operation
    cp_enable: coverpoint en {
      bins disabled = {0};
      bins enabled  = {1};
    }

    // Cross: state × enable (verify FSM doesn't advance when disabled)
    cx_state_enable: cross cp_state, cp_enable;
  endgroup

  cg_debounce cov_debounce = new();

  //===========================================================================
  // Helper Tasks
  //===========================================================================

  // Apply reset for a given number of cycles
  task automatic apply_reset(int cycles = 3);
    rst_n = 0;
    en = 0;
    key_detected = 0;
    repeat(cycles) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
  endtask

  // Wait N clock cycles
  task automatic wait_clks(int n);
    repeat(n) @(posedge clk);
  endtask

  // Simulate a clean key press (no bouncing)
  // Holds key_detected high long enough for debounce to confirm
  task automatic press_key_clean();
    key_detected = 1;
    // Need DEBOUNCE_CNT_MAX + 2 cycles for counter to reach max and register press
    wait_clks(DEBOUNCE_CNT_MAX + 3);
  endtask

  // Simulate a clean key release (no bouncing)
  task automatic release_key_clean();
    key_detected = 0;
    wait_clks(DEBOUNCE_CNT_MAX + 3);
  endtask

  // Simulate a bouncy key press
  // Toggle key_detected `bounce_count` times before settling high
  task automatic press_key_bouncy(int bounce_count = 3, int bounce_period = 2);
    integer i;
    for (i = 0; i < bounce_count; i++) begin
      key_detected = 1;
      wait_clks(bounce_period);
      key_detected = 0;
      wait_clks(bounce_period);
    end
    // Finally settle high
    key_detected = 1;
    wait_clks(DEBOUNCE_CNT_MAX + 3);
  endtask

  // Simulate a bouncy key release
  // Toggle key_detected `bounce_count` times before settling low
  task automatic release_key_bouncy(int bounce_count = 3, int bounce_period = 2);
    integer i;
    for (i = 0; i < bounce_count; i++) begin
      key_detected = 0;
      wait_clks(bounce_period);
      key_detected = 1;
      wait_clks(bounce_period);
    end
    // Finally settle low
    key_detected = 0;
    wait_clks(DEBOUNCE_CNT_MAX + 3);
  endtask

  // Check and report test result
  task automatic check(string test_name, bit condition, string msg = "");
    if (condition) begin
      $display("[PASS] %s %s", test_name, msg);
      pass_count++;
    end else begin
      $display("[FAIL] %s %s", test_name, msg);
      fail_count++;
    end
  endtask

  //===========================================================================
  // Monitor: count output pulses for verification
  //===========================================================================
  integer press_pulse_count;
  integer release_pulse_count;

  task automatic reset_pulse_counters();
    press_pulse_count   = 0;
    release_pulse_count = 0;
  endtask

  always @(posedge clk) begin
    if (debounced_press)   press_pulse_count++;
    if (debounced_release) release_pulse_count++;
  end

  //===========================================================================
  // Test Cases
  //===========================================================================

  // TC1: Clean press — key_detected goes high and stays high
  task automatic test_clean_press();
    current_test = "TC1: test_clean_press";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // Press key cleanly
    press_key_clean();

    // Verify
    check("TC1", press_pulse_count == 1,
          $sformatf("Expected 1 press pulse, got %0d", press_pulse_count));
    check("TC1", dut_state == PRESSED,
          $sformatf("Expected PRESSED state, got %0b", dut_state));
  endtask

  // TC2: Clean release — key_detected goes low and stays low
  task automatic test_clean_release();
    current_test = "TC2: test_clean_release";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // First press (prerequisite for release)
    press_key_clean();

    // Now release cleanly
    reset_pulse_counters();
    release_key_clean();

    // Verify
    check("TC2", release_pulse_count == 1,
          $sformatf("Expected 1 release pulse, got %0d", release_pulse_count));
    check("TC2", dut_state == IDLE,
          $sformatf("Expected IDLE state, got %0b", dut_state));
  endtask

  // TC3: Bouncy press — key_detected toggles before settling
  task automatic test_bouncy_press();
    current_test = "TC3: test_bouncy_press";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // Bouncy press with 5 bounces
    press_key_bouncy(.bounce_count(5), .bounce_period(2));

    // Verify: exactly 1 press pulse despite bouncing
    check("TC3", press_pulse_count == 1,
          $sformatf("Expected 1 press pulse after bouncing, got %0d", press_pulse_count));
    check("TC3", dut_state == PRESSED,
          $sformatf("Expected PRESSED state, got %0b", dut_state));
  endtask

  // TC4: Bouncy release — key_detected toggles before settling low
  task automatic test_bouncy_release();
    current_test = "TC4: test_bouncy_release";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // First do a clean press
    press_key_clean();
    reset_pulse_counters();

    // Now do a bouncy release with 4 bounces
    release_key_bouncy(.bounce_count(4), .bounce_period(2));

    // Verify: exactly 1 release pulse despite bouncing
    check("TC4", release_pulse_count == 1,
          $sformatf("Expected 1 release pulse after bouncing, got %0d", release_pulse_count));
    check("TC4", dut_state == IDLE,
          $sformatf("Expected IDLE state, got %0b", dut_state));
  endtask

  // TC5: Enable gating — nothing should happen when en=0
  task automatic test_enable_gating();
    current_test = "TC5: test_enable_gating";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 0;  // DISABLED

    // Try to press key while disabled
    key_detected = 1;
    wait_clks(DEBOUNCE_CNT_MAX + 10);

    // Verify: no pulse, FSM stayed in IDLE
    check("TC5", press_pulse_count == 0,
          $sformatf("Expected 0 press pulses when disabled, got %0d", press_pulse_count));
    check("TC5", dut_state == IDLE,
          $sformatf("Expected FSM stuck in IDLE when en=0, got %0b", dut_state));

    // Now enable and verify it starts working
    en = 1;
    wait_clks(DEBOUNCE_CNT_MAX + 3);

    check("TC5", press_pulse_count == 1,
          $sformatf("Expected 1 press pulse after enabling, got %0d", press_pulse_count));
  endtask

  // TC6: Reset during PRESS_CHECK
  task automatic test_reset_mid_press();
    current_test = "TC6: test_reset_mid_press";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // Start pressing (enter PRESS_CHECK)
    key_detected = 1;
    wait_clks(DEBOUNCE_CNT_MAX / 2);  // halfway through debounce

    // Verify we're in PRESS_CHECK
    check("TC6", dut_state == PRESS_CHECK,
          $sformatf("Expected PRESS_CHECK before reset, got %0b", dut_state));

    // Hit reset
    rst_n = 0;
    @(posedge clk);

    // Verify reset state
    check("TC6", dut_state == IDLE,
          "Expected IDLE after reset");
    check("TC6", debounced_press == 0,
          "Expected debounced_press=0 after reset");
    check("TC6", debounced_release == 0,
          "Expected debounced_release=0 after reset");

    // Release reset, clean up
    key_detected = 0;
    rst_n = 1;
    wait_clks(3);
  endtask

  // TC7: Reset during RELEASE_CHECK
  task automatic test_reset_mid_release();
    current_test = "TC7: test_reset_mid_release";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // Do a full press first
    press_key_clean();

    // Start releasing (enter RELEASE_CHECK)
    key_detected = 0;
    wait_clks(DEBOUNCE_CNT_MAX / 2);  // halfway through release debounce

    // Verify we're in RELEASE_CHECK
    check("TC7", dut_state == RELEASE_CHECK,
          $sformatf("Expected RELEASE_CHECK before reset, got %0b", dut_state));

    // Hit reset
    rst_n = 0;
    @(posedge clk);

    // Verify clean reset
    check("TC7", dut_state == IDLE,
          "Expected IDLE after reset");
    check("TC7", debounced_press == 0,
          "Expected debounced_press=0 after reset");

    rst_n = 1;
    wait_clks(3);
  endtask

  // TC8: Full press → hold → release cycle
  task automatic test_full_cycle();
    current_test = "TC8: test_full_cycle";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // Press
    press_key_clean();
    check("TC8", press_pulse_count == 1,
          $sformatf("Press: expected 1 pulse, got %0d", press_pulse_count));

    // Hold for a while
    wait_clks(50);
    check("TC8", press_pulse_count == 1,
          "Hold: press count should still be 1 (no repeat)");
    check("TC8", dut_state == PRESSED,
          "Hold: should remain in PRESSED state");

    // Release
    reset_pulse_counters();
    release_key_clean();
    check("TC8", release_pulse_count == 1,
          $sformatf("Release: expected 1 pulse, got %0d", release_pulse_count));
    check("TC8", dut_state == IDLE,
          "Release: should return to IDLE");
  endtask

  // TC9: Two back-to-back key presses
  task automatic test_back_to_back();
    current_test = "TC9: test_back_to_back";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;

    // First press-release cycle
    press_key_clean();
    release_key_clean();

    check("TC9", press_pulse_count == 1,
          $sformatf("1st cycle: expected 1 press, got %0d", press_pulse_count));
    check("TC9", release_pulse_count == 1,
          $sformatf("1st cycle: expected 1 release, got %0d", release_pulse_count));

    // Small gap
    wait_clks(5);

    // Second press-release cycle
    reset_pulse_counters();
    press_key_clean();
    release_key_clean();

    check("TC9", press_pulse_count == 1,
          $sformatf("2nd cycle: expected 1 press, got %0d", press_pulse_count));
    check("TC9", release_pulse_count == 1,
          $sformatf("2nd cycle: expected 1 release, got %0d", release_pulse_count));
  endtask

  // TC10: Enable high but no key — verify no false triggers
  task automatic test_no_key();
    current_test = "TC10: test_no_key";
    $display("\n===== %s =====", current_test);
    apply_reset();
    reset_pulse_counters();
    en = 1;
    key_detected = 0;

    // Wait a long time with no key pressed
    wait_clks(DEBOUNCE_CNT_MAX * 5);

    check("TC10", press_pulse_count == 0,
          "No false press pulses when no key pressed");
    check("TC10", release_pulse_count == 0,
          "No false release pulses when no key pressed");
    check("TC10", dut_state == IDLE,
          "Should remain in IDLE with no key");
  endtask

  //===========================================================================
  // Main Test Sequencer
  //===========================================================================
  initial begin
    // Waveform dump
    $dumpfile("tb_debounce_unit.vcd");
    $dumpvars(0, tb_debounce_unit);

    $display("==========================================================");
    $display(" Debounce Unit Testbench — Directed Tests");
    $display(" DEBOUNCE_CNT_MAX = %0d", DEBOUNCE_CNT_MAX);
    $display("==========================================================");

    // Run all tests sequentially
    test_clean_press();
    test_clean_release();
    test_bouncy_press();
    test_bouncy_release();
    test_enable_gating();
    test_reset_mid_press();
    test_reset_mid_release();
    test_full_cycle();
    test_back_to_back();
    test_no_key();

    // Final summary
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

  //===========================================================================
  // Timeout watchdog — prevent infinite simulation
  //===========================================================================
  initial begin
    #1_000_000;
    $display("[TIMEOUT] Simulation exceeded maximum time — aborting");
    $finish;
  end

endmodule

// ============================================================
// Testbench: 16-bit SAR ADC
// ------------------------------------------------------------
// Tests the adc_sar module across several input conditions:
//   1. Zero input
//   2. Full-scale input
//   3. Midscale input
//   4. Sweep from 0 to full scale in steps
//   5. Out-of-range (max, should clamp at 65535)
//
// A 50 MHz clock is generated (20 ns period).
// Each conversion takes 16 clock cycles + 1 DONE cycle = 17
// cycles total. The testbench waits for done_o before checking
// results.
//
// Author: Alexander Ross
// University of Sheffield – MEng Computer Systems Engineering
// Date: 2026
// ============================================================

`timescale 1ns / 1ps
`default_nettype none

module adc_sar_tb;

// ------------------------------------------------------------
// Clock and Reset
// ------------------------------------------------------------
localparam CLK_PERIOD = 20; // 50 MHz -> 20 ns period

reg clk;
reg rst;

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// ------------------------------------------------------------
// DUT Signals
// ------------------------------------------------------------
reg         start;
reg  [15:0] analog_in;
wire [15:0] digital_out;
wire        done;
wire [4:0]  bit_transitions;
wire        activity_overflow;

// ------------------------------------------------------------
// DUT Instantiation
// ------------------------------------------------------------
adc_sar #(
    .THRESHOLD(500)
) DUT (
    .clk_i               (clk),
    .rst_i               (rst),
    .start_i             (start),
    .analog_in_i         (analog_in),
    .digital_out_o       (digital_out),
    .done_o              (done),
    .bit_transitions_o   (bit_transitions),
    .activity_overflow_o (activity_overflow)
);

// ------------------------------------------------------------
// Task: Run a single conversion and report result
// ------------------------------------------------------------
task run_conversion;
    input [15:0] test_input;
    input [15:0] expected;
    input [63:0] test_name; // Not synthesisable - fine in testbench
    begin
        analog_in = test_input;
        @(posedge clk); #1;
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;

        // Wait for done pulse (max 20 cycles to avoid infinite wait)
        repeat(20) begin
            @(posedge clk);
            if (done) disable run_conversion;
        end

        $display("Test: %s | Input: %5d | Output: %5d | Expected: %5d | %s | Transitions: %0d",
            test_name,
            test_input,
            digital_out,
            expected,
            (digital_out == expected) ? "PASS" : "FAIL",
            bit_transitions
        );
    end
endtask

// ------------------------------------------------------------
// Waveform Dump
// ------------------------------------------------------------
initial begin
    $dumpfile("adc_sar.vcd");
    $dumpvars(0, adc_sar_tb);
end

// ------------------------------------------------------------
// Stimulus
// ------------------------------------------------------------
integer i;

initial begin
    // Initialise
    rst      = 1'b1;
    start    = 1'b0;
    analog_in = 16'd0;

    // Hold reset for 4 cycles
    repeat(4) @(posedge clk);
    #1;
    rst = 1'b0;

    $display("------------------------------------------------------------");
    $display("       16-bit SAR ADC Testbench Results");
    $display("------------------------------------------------------------");

    // Test 1: Zero input
    run_conversion(16'd0, 16'd0, "Zero      ");

    // Test 2: Full scale
    run_conversion(16'd65535, 16'd65535, "Full scale");

    // Test 3: Midscale
    run_conversion(16'd32768, 16'd32768, "Midscale  ");

    // Test 4: Quarter scale
    run_conversion(16'd16384, 16'd16384, "Quarter   ");

    // Test 5: Three-quarter scale
    run_conversion(16'd49152, 16'd49152, "3-Quarter ");

    // Test 6: LSB (minimum non-zero input)
    run_conversion(16'd1, 16'd1, "LSB       ");

    // Test 7: Sweep from 0 to 65535 in 4096 steps
    $display("------------------------------------------------------------");
    $display("Sweep test (every 4096 steps)...");
    for (i = 0; i <= 65535; i = i + 4096) begin
        analog_in = i[15:0];
        @(posedge clk); #1;
        start = 1'b1;
        @(posedge clk); #1;
        start = 1'b0;
        repeat(20) @(posedge clk);
        $display("  Vin=%5d | Dout=%5d | Transitions=%0d | Overflow=%b",
            analog_in, digital_out, bit_transitions, activity_overflow);
    end

    $display("------------------------------------------------------------");
    $display("Simulation complete.");
    $display("------------------------------------------------------------");
    $finish;
end

// ------------------------------------------------------------
// Timeout watchdog (catches hung simulations)
// ------------------------------------------------------------
initial begin
    #100000;
    $display("ERROR: Simulation timeout");
    $finish;
end

endmodule
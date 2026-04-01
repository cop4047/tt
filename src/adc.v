// ============================================================
// 16-bit Successive Approximation Register (SAR) ADC
// ------------------------------------------------------------
// Synthesisable RTL model of a 16-bit unipolar SAR ADC.
//
// Input range:  0 to 65535 (represents 0V to 3.3V)
//               i.e. input is pre-scaled: 1 LSB = ~50.4 uV
//
// The SAR algorithm performs a binary search over 16 clock
// cycles to determine the digital output. A new conversion
// starts when start_i is asserted. done_o pulses high for
// one cycle when the result is ready.
//
// Also includes a switching activity estimator which counts
// bit transitions between conversions as a proxy for dynamic
// power dissipation (P proportional to alpha * C * V^2 * f).
//
// Author: Alexander Ross
// University of Sheffield – MEng Computer Systems Engineering
// Date: 2026
// ============================================================

`timescale 1ns / 1ps
`default_nettype none

module adc_sar (
    input  wire        clk_i,          // System clock (50 MHz)
    input  wire        rst_i,          // Synchronous active-high reset
    input  wire        start_i,        // Start conversion pulse
    input  wire [15:0] analog_in_i,    // Scaled analogue input (0–65535)
    output reg  [15:0] digital_out_o,  // 16-bit conversion result
    output reg         done_o,         // Conversion complete (1-cycle pulse)
    output reg  [4:0]  bit_transitions_o, // Switching activity count
    output reg         activity_overflow_o // High if activity exceeds threshold
);

// ------------------------------------------------------------
// Parameters
// ------------------------------------------------------------
parameter THRESHOLD = 500; // Accumulated activity overflow limit

// ------------------------------------------------------------
// FSM State Encoding
// ------------------------------------------------------------
localparam IDLE    = 2'b00;
localparam CONVERT = 2'b01;
localparam DONE    = 2'b10;

// ------------------------------------------------------------
// Internal Signals
// ------------------------------------------------------------
reg [1:0]  state;
reg [3:0]  bit_index;      // Tracks which bit we are testing (15 down to 0)
reg [15:0] sar_reg;        // The SAR approximation register
reg [15:0] prev_result;    // Previous conversion result (for activity tracking)
reg [15:0] activity_acc;   // Accumulated switching activity counter

// ------------------------------------------------------------
// Function: Count bit transitions between two samples
// Used to estimate switching activity / dynamic power
// ------------------------------------------------------------
function [4:0] count_transitions;
    input [15:0] a;
    input [15:0] b;
    integer i;
    reg [4:0] count;
    begin
        count = 5'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (a[i] != b[i])
                count = count + 1'b1;
        end
        count_transitions = count;
    end
endfunction

// ------------------------------------------------------------
// SAR ADC FSM
// ------------------------------------------------------------
always @(posedge clk_i) begin
    if (rst_i) begin
        state               <= IDLE;
        bit_index           <= 4'd15;
        sar_reg             <= 16'd0;
        digital_out_o       <= 16'd0;
        done_o              <= 1'b0;
        prev_result         <= 16'd0;
        activity_acc        <= 16'd0;
        bit_transitions_o   <= 5'd0;
        activity_overflow_o <= 1'b0;

    end else begin
        done_o <= 1'b0; // Default: done is low unless we just finished

        case (state)

            // ------------------------------------------------
            // IDLE: wait for a start pulse
            // ------------------------------------------------
            IDLE: begin
                if (start_i) begin
                    sar_reg   <= 16'd0;
                    bit_index <= 4'd15;
                    state     <= CONVERT;
                end
            end

            // ------------------------------------------------
            // CONVERT: SAR binary search
            // Each cycle we test one bit, MSB first.
            // We build the trial value by OR-ing the current
            // sar_reg with a 1 in the current bit position,
            // then compare against the input. If the trial
            // exceeds the input, that bit stays 0. Otherwise 1.
            // ------------------------------------------------
            CONVERT: begin
                // Build trial value with current bit set
                // and decide whether to keep it
                if ((sar_reg | (16'd1 << bit_index)) <= analog_in_i)
                    sar_reg <= sar_reg | (16'd1 << bit_index);
                // else: bit stays 0, sar_reg unchanged

                if (bit_index == 4'd0) begin
                    state <= DONE;
                end else begin
                    bit_index <= bit_index - 1'b1;
                end
            end

            // ------------------------------------------------
            // DONE: latch result, compute switching activity
            // ------------------------------------------------
            DONE: begin
                digital_out_o <= sar_reg;
                done_o        <= 1'b1;

                // Switching activity estimation
                bit_transitions_o <= count_transitions(prev_result, sar_reg);
                prev_result       <= sar_reg;

                // Accumulate activity and check for overflow
                activity_acc <= activity_acc + count_transitions(prev_result, sar_reg);
                if (activity_acc + count_transitions(prev_result, sar_reg) >= THRESHOLD)
                    activity_overflow_o <= 1'b1;

                state <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end
end

endmodule
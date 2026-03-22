// ============================================================
// 16-bit Analog-to-Digital Converter (ADC)
// ------------------------------------------------------------
// Description:
// Behavioural model of a 16-bit ADC with bipolar input range
// (-10V to +10V). Includes conversion delay and a simple
// switching activity estimator (for power approximation).
//
// Author: Alexander Ross 
// Date: 2026
// ============================================================

`timescale 1 ns / 1 ps

module ADC_16bit (
    input  [63:0] analog_in,     // Real value packed as 64-bit
    output [15:0] digital_out    // 16-bit ADC output
);

// ---------------- PARAMETERS ----------------
parameter conversion_time = 25.0;     // ns delay
parameter charge_limit    = 1000000;  // switching threshold

// ---------------- INTERNAL REGISTERS ----------------
reg [15:0] delayed_output;
reg [15:0] prev_sample, current_sample;
reg [4:0]  bit_diff;
reg [19:0] charge;
reg        charge_overflow;
reg        reset_charge;

// ============================================================
// FUNCTION: Analog → Digital Conversion
// Converts real voltage (-10V to +10V) into 16-bit signed output
// ============================================================
function [15:0] adc_convert;

    parameter MAX_DIGITAL = 32767;
    parameter MAX_VOLTAGE = 10.0;

    input [63:0] analog_in;

    real analog_value, limited_value;
    integer digital_value;

begin
    analog_value = $bitstoreal(analog_in);

    // Clamp input to ADC range
    if (analog_value > MAX_VOLTAGE)
        limited_value = MAX_VOLTAGE;
    else if (analog_value < -MAX_VOLTAGE)
        limited_value = -MAX_VOLTAGE;
    else
        limited_value = analog_value;

    // Convert to digital value
    if (limited_value == MAX_VOLTAGE)
        digital_value = MAX_DIGITAL;
    else if (limited_value == -MAX_VOLTAGE)
        digital_value = -MAX_DIGITAL;
    else
        digital_value = $rtoi(limited_value * 3276.8);

    adc_convert = digital_value;
end

endfunction

// ============================================================
// FUNCTION: Bit Change Counter
// Estimates switching activity between samples
// ============================================================
function [4:0] count_bit_changes;

    input [15:0] prev_sample, current_sample;
    integer i;

begin
    count_bit_changes = 0;
    for (i = 0; i < 16; i = i + 1)
        if (prev_sample[i] != current_sample[i])
            count_bit_changes = count_bit_changes + 1;
end

endfunction

// ============================================================
// RESET CHARGE ACCUMULATION
// ============================================================
always @(posedge reset_charge) begin
    charge <= 0;
    charge_overflow <= 0;
end

// ============================================================
// UPDATE ON SIGNAL CHANGE (Activity Tracking)
// ============================================================
always @(adc_convert(analog_in)) begin
    current_sample = adc_convert(analog_in);
    bit_diff = count_bit_changes(prev_sample, current_sample);
    prev_sample = current_sample;

    charge = charge + (bit_diff * 3);

    if (charge > charge_limit)
        charge_overflow = 1;
end

// ============================================================
// CONVERSION DELAY MODEL
// ============================================================
always
    #conversion_time delayed_output = adc_convert(analog_in);

// Output assignment
assign digital_out = delayed_output;

endmodule

`timescale 1 ns / 1 ps
`default_nettype none

module ADC_16bit_tf;

  localparam real step = 0.1;
  localparam integer nsteps = 1000;
  localparam real maxval = 11.0;
  localparam real minval = -11.0;

  real analog_in_real = 0.0;
  
  reg [63:0] analog_in;
  wire [15:0] digital_out;

  initial begin : stimulus 
    integer i;
    real sign;
    sign = 1.0;

    for (i = 0; i < nsteps; i = i + 1) begin
      #10;
      analog_in_real = analog_in_real + (sign * step);

      if (analog_in_real >= maxval)
        sign = -1.0;
      if (analog_in_real <= minval)
        sign = +1.0;

      analog_in = $realtobits(analog_in_real);
    end

    $stop;
  end  

  // DUT
  ADC_16bit DUT (
    .analog_in(analog_in),
    .digital_out(digital_out)
  ); 
  
  // Monitor
  initial begin
    $monitor("t=%0t | Vin=%f V | Dout=%d",
              $time, $bitstoreal(analog_in), digital_out);
  end

  // Waveform dump
  initial begin
    $dumpfile("adc.vcd");
    $dumpvars(0, ADC_16bit_tf);
  end

endmodule

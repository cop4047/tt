# 16-bit SAR ADC — Synthesisable Verilog RTL

A synthesisable RTL implementation of a 16-bit unipolar Successive Approximation Register (SAR) ADC, written in Verilog. Designed for FPGA/ASIC implementation and compatible with Tiny Tapeout submission requirements.

---

## Overview

A Successive Approximation Register ADC determines the digital output through a binary search algorithm — testing each bit from MSB to LSB over successive clock cycles. For a 16-bit result, this takes exactly 16 clock cycles per conversion, making it predictable and well-suited to synchronous digital design.

This implementation models the digital control logic of a SAR ADC. The analogue input is represented as a pre-scaled 16-bit integer (0–65535 mapping to 0–3.3V), which is standard practice for digital verification of mixed-signal interfaces. The core FSM, switching activity estimator, and all control logic are fully synthesisable.

---

## Specification

| Parameter            | Value                                  |
|----------------------|----------------------------------------|
| Resolution           | 16-bit unsigned                        |
| Input range          | 0 to 65535 (0V to 3.3V mapped linearly)|
| LSB size             | ~50.4 µV                               |
| Conversion cycles    | 16 (one bit resolved per clock cycle)  |
| Clock frequency      | 50 MHz (20 ns period)                  |
| Throughput           | ~2.94 MSPS (50 MHz / 17 cycles)        |
| Reset                | Synchronous, active-high               |

---

## Architecture

### SAR FSM

The core logic is a three-state FSM:

```
        start_i
IDLE ──────────► CONVERT ──── (16 cycles) ────► DONE ──► IDLE
                  (bit_index 15 → 0)             │
                                                 └── done_o pulse
```

- **IDLE**: Waits for `start_i` pulse. Resets internal registers.
- **CONVERT**: Each cycle, tests one bit position by OR-ing the current approximation with a trial bit. If the trial value is less than or equal to the input, the bit is kept; otherwise it is discarded. `bit_index` decrements from 15 to 0.
- **DONE**: Latches the final result to `digital_out_o`, pulses `done_o` for one cycle, computes switching activity, then returns to IDLE.

### Switching Activity Estimator

A bit-transition counter compares each conversion result against the previous one, counting the number of bits that changed. This is accumulated across conversions as a proxy for dynamic power dissipation:

> P ∝ α · C · V² · f

where α (the activity factor) is approximated by the normalised transition count. An overflow flag is raised when accumulated activity exceeds a configurable threshold, useful for detecting high-frequency or high-swing input conditions.

---

## File Structure

```
├── adc_sar.v        # Synthesisable SAR ADC RTL module
├── adc_sar_tb.v     # Clocked testbench with sweep and directed tests
├── adc_sar.vcd      # Waveform output (generated on simulation)
└── README.md
```

---

## Port Description

### `adc_sar.v`

| Port                  | Direction | Width  | Description                                    |
|-----------------------|-----------|--------|------------------------------------------------|
| `clk_i`               | input     | 1-bit  | System clock (50 MHz)                          |
| `rst_i`               | input     | 1-bit  | Synchronous active-high reset                  |
| `start_i`             | input     | 1-bit  | Begin conversion (1-cycle pulse)               |
| `analog_in_i`         | input     | 16-bit | Scaled input sample (0–65535)                  |
| `digital_out_o`       | output    | 16-bit | Conversion result                              |
| `done_o`              | output    | 1-bit  | Conversion complete (1-cycle pulse)            |
| `bit_transitions_o`   | output    | 5-bit  | Switching activity count (current sample)      |
| `activity_overflow_o` | output    | 1-bit  | High if accumulated activity exceeds threshold |

---

## Simulation

### Requirements
- [iverilog](http://iverilog.icarus.com/) — open-source Verilog simulator
- [GTKWave](http://gtkwave.sourceforge.net/) — waveform viewer

### Running the Simulation

```bash
# Compile
iverilog -o adc_sim adc_sar.v adc_sar_tb.v

# Run
vvp adc_sim

# View waveforms
gtkwave adc_sar.vcd
```

### Testbench Coverage

The testbench runs the following directed tests before a full sweep:

| Test          | Input   | Expected Output |
|---------------|---------|-----------------|
| Zero          | 0       | 0               |
| Full scale    | 65535   | 65535           |
| Midscale      | 32768   | 32768           |
| Quarter scale | 16384   | 16384           |
| Three-quarter | 49152   | 49152           |
| LSB           | 1       | 1               |

Followed by a sweep from 0 to 65535 in steps of 4096, reporting conversion result, bit transitions, and overflow flag at each step.

**Note on quantisation:** Power-of-two input values (0, 16384, 32768, 49152, 65535) will match exactly. Arbitrary values may exhibit ±1 LSB quantisation error — this is expected behaviour consistent with real SAR ADC operation and the finite resolution of the binary search.

---

## Why SAR?

SAR is the dominant architecture for medium-to-high resolution ADCs (12–18 bit) in the 1 MSPS – 10 MSPS range. It offers a good balance of resolution, speed, and power consumption, and its binary search algorithm maps naturally to synchronous digital logic — making it an ideal architecture to implement at RTL level.

Alternative architectures for context:

| Architecture | Resolution  | Speed     | Complexity            |
|--------------|-------------|-----------|-----------------------|
| Flash        | Low (6–8b)  | Very fast | High (2ⁿ comparators)|
| SAR          | Medium–High | Medium    | Low–Medium            |
| Delta-Sigma  | Very high   | Slow      | Medium (DSP)          |
| Pipeline     | Medium      | Fast      | High                  |

---

## Author

Alexander Ross — MEng Computer Systems Engineering, University of Sheffield  
[linkedin.com/in/alexandeross](https://linkedin.com/in/alexandeross)
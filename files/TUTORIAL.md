# VCO Digital Calibration Loop — Verilog Tutorial
### A complete beginner-friendly walkthrough

> **How to use this file:**
> Open this in VS Code. Press `Ctrl+Shift+V` to open Markdown Preview side-by-side.
> Read the theory, then write the code in the `.v` files in this same folder.
> Run everything using the terminal commands given at the end.

---

## What are we building?

You designed a real LC VCO at MNIT Jaipur. It had varactors — voltage-controlled capacitors — that let you tune the oscillation frequency by changing a control voltage.

In a real chip, you don't set that control voltage by hand. A **digital calibration loop** does it automatically at startup:

1. It checks whether the VCO frequency is too high, too low, or correct
2. It adjusts a digital trim code (which maps to the varactor control voltage)
3. It repeats until the frequency is locked

That calibration loop is what we're building in Verilog. Three files, three modules:

```
┌─────────────────────────────────────────────────────────┐
│                    tb.v  (testbench)                    │
│                                                         │
│  clk_vco ──→ ┌──────────────┐                           │
│              │  freq_detect  │──→ freq_low, freq_high   │
│  clk_ref ──→ └──────┬───────┘                           │
│                     │                                   │
│             ┌───────▼────────┐                          │
│             │   trim_fsm     │──→ trim_code[3:0]        │
│             └────────────────┘                          │
└─────────────────────────────────────────────────────────┘
```

- **`freq_detect.v`** — counts VCO cycles per reference clock cycle, decides if frequency is too low, too high, or locked
- **`trim_fsm.v`** — the state machine that adjusts the trim code based on those signals
- **`tb.v`** — the testbench that connects everything, generates clocks, and lets you watch the system converge

---

## Before you write any code — Verilog in 5 minutes

### Module: the basic building block

Every circuit in Verilog is a `module`. Think of it like a chip with pins.

```verilog
module my_chip (
    input  clk,        // input pin
    input  rst,        // input pin
    output reg q       // output pin
);
    // circuit logic goes here

endmodule
```

`input` = signal coming in. `output` = signal going out.
`reg` means this signal is stored (like a flip-flop). If you're driving an output from an `always` block, it must be `reg`.

---

### always block: where your logic lives

```verilog
always @(posedge clk) begin
    // this runs on every rising edge of clk
end
```

`posedge` = rising edge (0→1 transition).
Everything inside this block describes what your flip-flops do each clock cycle.

---

### Blocking vs Non-blocking (you already know this)

- `=`  blocking → use in combinational logic (`always @(*)`)
- `<=` non-blocking → use in sequential logic (`always @(posedge clk)`)

**Rule: In every `always @(posedge clk)` block, always use `<=`. Always.**

---

### if / else inside always blocks

```verilog
always @(posedge clk) begin
    if (rst)
        q <= 0;          // reset condition
    else if (enable)
        q <= d;          // normal operation
    else
        q <= q;          // hold value (you can also just omit this line)
end
```

---

### Parameters: constants you can configure

```verilog
module freq_detect #(
    parameter N_TARGET = 8,   // expected VCO cycles per ref cycle
    parameter N_TOL    = 1    // tolerance window
) ( ... );
```

`#( )` before the port list = parameters. Like `#define` in C. Lets you reuse the module with different settings.

---

### Case statement: perfect for state machines

```verilog
case (state)
    IDLE:  next_state <= COARSE;
    COARSE: begin
        if (freq_low)  next_state <= COARSE;
        else           next_state <= CHECK_C;
    end
    default: next_state <= IDLE;
endcase
```

---

## Part 1 — `freq_detect.v`

### Theory: how does it count frequency?

The idea is simple:

> "In every reference clock cycle, count how many VCO rising edges occur."

If your ref clock is 1 MHz and your VCO target is 8 MHz, you expect 8 VCO edges per ref cycle.

- Count < 7 → VCO too slow → assert `freq_low`
- Count > 9 → VCO too fast → assert `freq_high`
- 7 ≤ count ≤ 9 → locked → both signals are 0

### How the counter resets

We need to reset the counter at the start of each reference clock cycle. We detect the rising edge of `clk_ref` using a technique called **edge detection**:

```verilog
reg clk_ref_prev;

always @(posedge clk_vco) begin
    clk_ref_prev <= clk_ref;           // remember last cycle's value
end

wire ref_rising = (clk_ref == 1) && (clk_ref_prev == 0);  // 0→1 transition
```

When `ref_rising` is 1, a new ref cycle has started — latch the count and reset.

### The complete `freq_detect.v`

**Create a file called `freq_detect.v` and type this out:**

```verilog
// ============================================================
// freq_detect.v
// Counts VCO rising edges per reference clock cycle
// and outputs freq_low / freq_high flags
// ============================================================

module freq_detect #(
    parameter N_TARGET = 8,    // expected VCO cycles per ref cycle
    parameter N_TOL    = 1     // acceptable tolerance on either side
)(
    input  wire clk_vco,       // VCO clock (the fast one)
    input  wire clk_ref,       // reference clock (the slow one)
    input  wire rst,           // active-high synchronous reset
    output reg  freq_low,      // 1 = VCO too slow, need to increase trim
    output reg  freq_high      // 1 = VCO too fast, need to decrease trim
);

    // ── internal registers ──────────────────────────────────
    reg [7:0] count;           // counts VCO edges in current ref cycle
    reg [7:0] count_latch;     // snapshot of count at end of ref cycle
    reg       clk_ref_prev;    // previous value of clk_ref (for edge detect)

    // ── detect rising edge of clk_ref, sampled on clk_vco ──
    wire ref_rising = (clk_ref == 1'b1) && (clk_ref_prev == 1'b0);

    // ── Step 1: Count VCO edges, reset on each ref rising edge ──
    always @(posedge clk_vco) begin
        if (rst) begin
            count        <= 8'd0;
            clk_ref_prev <= 1'b0;
            count_latch  <= 8'd0;
            freq_low     <= 1'b0;
            freq_high    <= 1'b0;
        end else begin
            clk_ref_prev <= clk_ref;   // update edge-detect register

            if (ref_rising) begin
                // ── end of ref cycle: latch and compare ──
                count_latch <= count;

                // YOUR TURN (1): Write the comparison logic here.
                // If count < (N_TARGET - N_TOL), freq_low  should be 1
                // If count > (N_TARGET + N_TOL), freq_high should be 1
                // Otherwise both should be 0
                // Use if / else if / else
                // ─────────────────────────────────────────
                // (delete this comment block and write your code here)
                // ─────────────────────────────────────────

                count <= 8'd1;         // reset counter (this edge counts as 1)
            end else begin
                count <= count + 8'd1; // increment every VCO edge
            end
        end
    end

endmodule
```

> **YOUR TURN (1):** Fill in the comparison logic where marked.
> It's just a 3-branch if/else comparing `count` to `N_TARGET - N_TOL` and `N_TARGET + N_TOL`.
> Use `<=` non-blocking assignment. Both `freq_low` and `freq_high` are `output reg` so you can drive them directly.

---

## Part 2 — `trim_fsm.v`

### Theory: Finite State Machines

A state machine is a circuit that:
1. Is always in exactly one **state**
2. Moves to a new state based on **inputs**
3. Produces **outputs** based on its state

We use a pattern called **3-block FSM** — the cleanest way to write synthesisable state machines:

```
Block 1: State register    — sequential, uses <=, updates state on clock edge
Block 2: Next-state logic  — combinational, uses =, computes where to go next
Block 3: Output logic      — combinational, uses =, computes outputs from state
```

### Our states

```
IDLE ──→ COARSE_TRIM ──→ CHECK_COARSE ──→ FINE_TRIM ──→ CHECK_FINE ──→ LOCKED
              ↑                │                 ↑              │
              └────────────────┘                 └──────────────┘
            (still freq_low/high)            (still freq_low/high)
```

- **IDLE** — waiting, trim code is reset to middle value (8 out of 15)
- **COARSE_TRIM** — increment or decrement trim by 2 (big steps)
- **CHECK_COARSE** — check if freq_low/freq_high are cleared; if yes, move to fine
- **FINE_TRIM** — increment or decrement trim by 1 (small steps)
- **CHECK_FINE** — check if locked; if yes, done
- **LOCKED** — stay here, output stable trim code

### State encoding

We define states as parameters so the code is readable:

```verilog
parameter IDLE         = 3'd0;
parameter COARSE_TRIM  = 3'd1;
parameter CHECK_COARSE = 3'd2;
parameter FINE_TRIM    = 3'd3;
parameter CHECK_FINE   = 3'd4;
parameter LOCKED       = 3'd5;
```

`3'd0` means: 3-bit wide, decimal value 0. The `3'd` prefix sets the bit width.

### The complete `trim_fsm.v`

**Create a file called `trim_fsm.v` and type this out:**

```verilog
// ============================================================
// trim_fsm.v
// 6-state FSM that adjusts a 4-bit trim code to lock
// VCO frequency using coarse + fine calibration
// ============================================================

module trim_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       freq_low,    // from freq_detect: VCO too slow
    input  wire       freq_high,   // from freq_detect: VCO too fast
    output reg  [3:0] trim_code,   // 4-bit code: 0=min freq, 15=max freq
    output reg        locked       // 1 = calibration complete
);

    // ── State encoding ──────────────────────────────────────
    parameter IDLE         = 3'd0;
    parameter COARSE_TRIM  = 3'd1;
    parameter CHECK_COARSE = 3'd2;
    parameter FINE_TRIM    = 3'd3;
    parameter CHECK_FINE   = 3'd4;
    parameter LOCKED_STATE = 3'd5;

    reg [2:0] state, next_state;

    // ════════════════════════════════════════════════════════
    // BLOCK 1: State register (sequential)
    // This is the memory of the FSM — it holds the current state
    // On every clock edge, move to next_state
    // ════════════════════════════════════════════════════════
    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ════════════════════════════════════════════════════════
    // BLOCK 2: Next-state logic (combinational)
    // Given current state and inputs, decide where to go next
    // ════════════════════════════════════════════════════════
    always @(*) begin
        next_state = state;    // default: stay in current state

        case (state)
            IDLE: begin
                next_state = COARSE_TRIM;
            end

            COARSE_TRIM: begin
                next_state = CHECK_COARSE;
            end

            CHECK_COARSE: begin
                // YOUR TURN (2): Fill in the transition logic.
                // If freq_low or freq_high is still asserted,
                //   go back to COARSE_TRIM (still not locked)
                // If neither is asserted (we're close enough),
                //   go to FINE_TRIM
                // ─────────────────────────────────────────
                // (write your if/else here)
                // ─────────────────────────────────────────
            end

            FINE_TRIM: begin
                next_state = CHECK_FINE;
            end

            CHECK_FINE: begin
                // YOUR TURN (3): Same idea as CHECK_COARSE.
                // If freq_low or freq_high still asserted → FINE_TRIM
                // If neither asserted → LOCKED_STATE
                // ─────────────────────────────────────────
                // (write your if/else here)
                // ─────────────────────────────────────────
            end

            LOCKED_STATE: begin
                next_state = LOCKED_STATE;   // stay here forever
            end

            default: next_state = IDLE;
        endcase
    end

    // ════════════════════════════════════════════════════════
    // BLOCK 3: Output logic + trim code update (sequential)
    // Based on current state, update trim_code and locked flag
    // ════════════════════════════════════════════════════════
    always @(posedge clk) begin
        if (rst) begin
            trim_code <= 4'd8;     // start in the middle of the range
            locked    <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    trim_code <= 4'd8;
                    locked    <= 1'b0;
                end

                COARSE_TRIM: begin
                    locked <= 1'b0;
                    if (freq_low) begin
                        // VCO too slow → increase trim (but don't overflow past 15)
                        if (trim_code <= 4'd13)
                            trim_code <= trim_code + 4'd2;
                        else
                            trim_code <= 4'd15;
                    end else if (freq_high) begin
                        // YOUR TURN (4): VCO too fast → decrease trim by 2
                        // Don't let it go below 0 (underflow on 4-bit = wraps to 15, bad!)
                        // Hint: check if trim_code >= 2 before subtracting
                        // ─────────────────────────────────────────
                        // (write your if/else here)
                        // ─────────────────────────────────────────
                    end
                end

                FINE_TRIM: begin
                    locked <= 1'b0;
                    if (freq_low) begin
                        // VCO too slow → increase trim by 1
                        if (trim_code < 4'd15)
                            trim_code <= trim_code + 4'd1;
                    end else if (freq_high) begin
                        // YOUR TURN (5): VCO too fast → decrease trim by 1
                        // Same underflow protection as above
                        // ─────────────────────────────────────────
                        // (write your if/else here)
                        // ─────────────────────────────────────────
                    end
                end

                LOCKED_STATE: begin
                    locked <= 1'b1;    // we're done!
                end

                default: begin
                    trim_code <= 4'd8;
                    locked    <= 1'b0;
                end
            endcase
        end
    end

endmodule
```

> **YOUR TURN (2) and (3):** The CHECK state transitions. Just an `if/else` checking `freq_low | freq_high`.
>
> **YOUR TURN (4) and (5):** The coarse/fine decrement. Mirror the increment logic but subtract instead.

---

## Part 3 — `tb.v`

### Theory: what is a testbench?

A testbench is a Verilog file that is **not synthesised** — it only runs in simulation. It has no ports (no `input`/`output`). Its job is to:

1. Generate clocks
2. Instantiate your modules and wire them together
3. Apply stimulus (set inputs, wait, change inputs)
4. Print results so you can see what happened

### Generating a clock in Verilog

```verilog
reg clk;
initial clk = 0;                    // start at 0
always #5 clk = ~clk;              // flip every 5 time units → period = 10
```

`#5` means "wait 5 time units". The timescale at the top of the file sets what 1 time unit means.

### The VCO clock trick

We need `clk_vco` to change frequency as `trim_code` changes. We do this with a **lookup table** inside an `always` block:

```verilog
reg [31:0] vco_half_period;

always @(trim_code) begin
    case (trim_code)
        4'd0:  vco_half_period = 50;   // slowest
        4'd7:  vco_half_period = 32;
        4'd8:  vco_half_period = 30;   // target: matches ref×8
        4'd15: vco_half_period = 20;   // fastest
        default: vco_half_period = 30;
    endcase
end
```

Then generate `clk_vco` using that period:

```verilog
always begin
    #(vco_half_period) clk_vco = ~clk_vco;
end
```

This is behavioral — not real silicon. But it perfectly models the idea that "higher trim_code = faster VCO."

### The complete `tb.v`

**Create a file called `tb.v` and type this out:**

```verilog
// ============================================================
// tb.v — Testbench for VCO digital calibration loop
// ============================================================
`timescale 1ns/1ps

module tb;

    // ── Clock and control signals ────────────────────────────
    reg clk_ref;
    reg clk_vco;
    reg rst;

    // ── Wires connecting modules ─────────────────────────────
    wire freq_low;
    wire freq_high;
    wire [3:0] trim_code;
    wire locked;

    // ── VCO period (changes with trim_code) ──────────────────
    reg [31:0] vco_half_period;

    // ════════════════════════════════════════════════════════
    // Generate reference clock: 10ns period = 100 MHz
    // ════════════════════════════════════════════════════════
    initial clk_ref = 0;
    always #5 clk_ref = ~clk_ref;

    // ════════════════════════════════════════════════════════
    // Generate VCO clock: period depends on trim_code
    // Target: 8 VCO cycles per ref cycle
    // ref period = 10ns → target vco period = 10/8 = 1.25ns
    // half period ≈ 0.625ns → use timescale 1ps → 625ps half-period
    //
    // For simplicity we use integer half-periods:
    //   trim 8 (target) → half period = 625 (ps)
    //   lower trim → slower → larger half period
    //   higher trim → faster → smaller half period
    // ════════════════════════════════════════════════════════
    initial clk_vco = 0;

    always @(trim_code) begin
        case (trim_code)
            4'd0:  vco_half_period = 32'd900;
            4'd1:  vco_half_period = 32'd850;
            4'd2:  vco_half_period = 32'd800;
            4'd3:  vco_half_period = 32'd750;
            4'd4:  vco_half_period = 32'd720;
            4'd5:  vco_half_period = 32'd700;
            4'd6:  vco_half_period = 32'd680;
            4'd7:  vco_half_period = 32'd650;
            4'd8:  vco_half_period = 32'd625;   // ← TARGET (8 cycles per ref)
            4'd9:  vco_half_period = 32'd600;
            4'd10: vco_half_period = 32'd575;
            4'd11: vco_half_period = 32'd550;
            4'd12: vco_half_period = 32'd530;
            4'd13: vco_half_period = 32'd510;
            4'd14: vco_half_period = 32'd490;
            4'd15: vco_half_period = 32'd470;
            default: vco_half_period = 32'd625;
        endcase
    end

    always begin
        #(vco_half_period) clk_vco = ~clk_vco;
    end

    // ════════════════════════════════════════════════════════
    // Instantiate freq_detect
    // ════════════════════════════════════════════════════════
    freq_detect #(
        .N_TARGET(8),
        .N_TOL(1)
    ) u_freq_detect (
        .clk_vco  (clk_vco),
        .clk_ref  (clk_ref),
        .rst      (rst),
        .freq_low (freq_low),
        .freq_high(freq_high)
    );

    // ════════════════════════════════════════════════════════
    // Instantiate trim_fsm
    // ════════════════════════════════════════════════════════
    trim_fsm u_trim_fsm (
        .clk      (clk_ref),      // FSM runs on ref clock (slow, clean)
        .rst      (rst),
        .freq_low (freq_low),
        .freq_high(freq_high),
        .trim_code(trim_code),
        .locked   (locked)
    );

    // ════════════════════════════════════════════════════════
    // Stimulus: apply reset, then let it run
    // ════════════════════════════════════════════════════════
    initial begin
        // Setup waveform dump (creates vcd file for GTKWave)
        $dumpfile("sim.vcd");
        $dumpvars(0, tb);

        // Apply reset
        rst = 1;
        #100;          // hold reset for 100ns
        rst = 0;

        // Let the calibration loop run
        #5000;

        // YOUR TURN (6): Add $display statements here to print results
        // Hint: $display("trim_code = %0d, locked = %0b", trim_code, locked);
        // ─────────────────────────────────────────
        // (write your display statements here)
        // ─────────────────────────────────────────

        // Check if it locked
        if (locked)
            $display("SUCCESS: VCO locked at trim_code = %0d", trim_code);
        else
            $display("FAIL: VCO did not lock. trim_code = %0d", trim_code);

        $finish;
    end

    // ════════════════════════════════════════════════════════
    // Monitor: print every time trim_code or locked changes
    // ════════════════════════════════════════════════════════
    initial begin
        $monitor("t=%0t | trim=%0d | freq_low=%0b freq_high=%0b | locked=%0b",
                 $time, trim_code, freq_low, freq_high, locked);
    end

endmodule
```

> **YOUR TURN (6):** Add a few `$display` lines before `$finish` to print intermediate state.
> Try printing `trim_code` at different time points using `#delay` and `$display`.

---

## Part 4 — Running the simulation

### Install Icarus Verilog (if you haven't)

**Windows:** Download from [bleyer.org/icarus](http://bleyer.org/icarus/) and install. Make sure to tick "Add to PATH".

**Mac:** `brew install icarus-verilog`

**Linux:** `sudo apt install iverilog`

Verify it works: open a terminal and type `iverilog -v`

---

### Compile and run

Open a terminal in your project folder and run:

```bash
# Step 1: Compile all three files
iverilog -o sim.out freq_detect.v trim_fsm.v tb.v

# Step 2: Run the simulation
vvp sim.out
```

You should see output like:
```
t=100000 | trim=8 | freq_low=0 freq_high=0 | locked=0
t=110000 | trim=8 | freq_low=0 freq_high=0 | locked=0
...
SUCCESS: VCO locked at trim_code = 8
```

---

### View waveforms in GTKWave (optional but satisfying)

```bash
gtkwave sim.vcd
```

In GTKWave: drag `trim_code`, `freq_low`, `freq_high`, and `locked` from the left panel into the wave view. You'll see `trim_code` stepping toward 8 and `locked` going high at the end.

---

## What to do if it doesn't lock

Common issues:

| Symptom | Likely cause |
|---|---|
| `trim_code` keeps incrementing past 15 | Missing overflow protection in YOUR TURN (4)/(5) |
| `locked` never goes high | Check YOUR TURN (2)/(3) — transition condition wrong |
| `freq_low`/`freq_high` never change | Check YOUR TURN (1) — comparison logic wrong |
| Simulation hangs forever | Missing `$finish` or `#5000` delay too short — increase it |

---

## What you've built

When this works, you have a complete behavioral model of a digital VCO calibration loop:

- A **frequency detector** that counts clock edges across domains
- A **6-state FSM** implementing coarse + fine calibration
- A **closed-loop testbench** where trim_code actually affects VCO frequency
- A working **VCD waveform dump** you can open in GTKWave

This maps directly to real digital calibration loops used in PLLs and clock generators in SoCs — exactly the kind of thing gChips builds.

---

## Resume bullet (fill this in once it works)

```
Implemented a 6-state digital calibration FSM in Verilog for VCO trim control;
modeled closed-loop frequency convergence with a behavioral VCO and frequency
detector; verified coarse and fine trim sequencing via testbench simulation
in Icarus Verilog.
```

Replace `[tool]` and `[date]` in your resume `.tex` file with the above.

---

*Good luck. Come back if you get stuck on any of the YOUR TURN sections.*

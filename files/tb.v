// ============================================================
// tb.v — Testbench for VCO digital calibration loop
// ============================================================
`timescale 1ps/1ps

module tb;

    reg clk_ref;
    reg clk_vco;
    reg rst;

    wire freq_low;
    wire freq_high;
    wire [3:0] trim_code;
    wire locked;

    reg [31:0] vco_half_period;

    // ── Reference clock: 10ns period (100 MHz) ───────────────
    initial clk_ref = 0;
    always #5000 clk_ref = ~clk_ref;

    // ── VCO clock: period controlled by trim_code ────────────
    initial clk_vco = 0;

    // CRITICAL: initialize before simulation starts
    initial vco_half_period = 32'd720;

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
            4'd8:  vco_half_period = 32'd625;   // target
            4'd9:  vco_half_period = 32'd600;
            4'd10: vco_half_period = 32'd575;
            4'd11: vco_half_period = 32'd550;
            4'd12: vco_half_period = 32'd530;
            4'd13: vco_half_period = 32'd510;
            4'd14: vco_half_period = 32'd490;
            4'd15: vco_half_period = 32'd470;
            default: vco_half_period = 32'd720;
        endcase
    end

    always begin
        #(vco_half_period) clk_vco = ~clk_vco;
    end

    // ── Instantiate freq_detect ───────────────────────────────
    freq_detect #(
        .N_TARGET(9),
        .N_TOL(1)
    ) u_freq_detect (
        .clk_vco  (clk_vco),
        .clk_ref  (clk_ref),
        .rst      (rst),
        .freq_low (freq_low),
        .freq_high(freq_high)
    );

    // ── Instantiate trim_fsm ──────────────────────────────────
    trim_fsm u_trim_fsm (
        .clk      (clk_ref),
        .rst      (rst),
        .freq_low (freq_low),
        .freq_high(freq_high),
        .trim_code(trim_code),
        .locked   (locked)
    );

    // ── Stimulus ──────────────────────────────────────────────
    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, tb);

        // apply reset
        rst = 1;
        #100;
        rst = 0;

        // run for 200 ref clock cycles and print state each cycle
        repeat(200) begin
            @(posedge clk_ref);
            $display("state=%0d | trim=%0d | low=%0b high=%0b | locked=%0b",
                     u_trim_fsm.state, trim_code, freq_low, freq_high, locked);
        end

        // final result
        if (locked)
            $display("SUCCESS: VCO locked at trim_code = %0d", trim_code);
        else
            $display("FAIL: Did not lock. trim_code = %0d", trim_code);

        $finish;
    end

endmodule

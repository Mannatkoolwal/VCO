// ============================================================
// freq_detect.v
// Counts VCO rising edges per reference clock cycle.
// Latches count at end of each ref cycle, then outputs
// freq_low / freq_high on the NEXT ref clock edge (clean,
// one-cycle delayed, fully stable when FSM reads them).
// ============================================================

module freq_detect #(
    parameter N_TARGET = 8,
    parameter N_TOL    = 1
)(
    input  wire clk_vco,
    input  wire clk_ref,
    input  wire rst,
    output reg  freq_low,
    output reg  freq_high
);

    reg [7:0] count;
    reg [7:0] count_latch;
    reg       clk_ref_prev;

    // ── detect ref rising edge in VCO domain ─────────────────
    wire ref_rising = (clk_ref == 1'b1) && (clk_ref_prev == 1'b0);

    // ── Block 1: count VCO edges, latch on ref rising edge ───
    // Runs in VCO domain — just counts and latches.
    // Does NOT set freq_low/high here to avoid race condition.
    always @(posedge clk_vco) begin
        if (rst) begin
            count        <= 8'd0;
            clk_ref_prev <= 1'b0;
            count_latch  <= 8'd0;
        end else begin
            clk_ref_prev <= clk_ref;

            if (ref_rising) begin
                count_latch <= count;  // save completed count
                count       <= 8'd1;  // reset for next cycle
            end else begin
                count <= count + 8'd1;
            end
        end
    end

    // ── Block 2: compare in ref domain ───────────────────────
    // Runs one ref cycle after count_latch is written.
    // By now count_latch is fully stable — no race condition.
    reg [7:0] count_latch2;

// in the clk_ref always block:
    always @(posedge clk_ref) begin
        count_latch2 <= count_latch;   // extra pipeline stage

        freq_low  <= 1'b0;
        freq_high <= 1'b0;

        if (count_latch2 > N_TARGET + N_TOL)
            freq_high <= 1'b1;
        else if (count_latch2 < N_TARGET - N_TOL)
            freq_low  <= 1'b1;
    end

endmodule

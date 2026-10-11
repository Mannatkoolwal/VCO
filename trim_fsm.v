// ============================================================
// trim_fsm.v
// 6-state FSM: coarse + fine VCO trim calibration
// ============================================================

module trim_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       freq_low,
    input  wire       freq_high,
    output reg  [3:0] trim_code,
    output reg        locked
);

    parameter IDLE         = 3'd0;
    parameter COARSE_TRIM  = 3'd1;
    parameter CHECK_COARSE = 3'd2;
    parameter FINE_TRIM    = 3'd3;
    parameter CHECK_FINE   = 3'd4;
    parameter LOCKED_STATE = 3'd5;

    reg [2:0] state, next_state;

    // ── BLOCK 1: State register ───────────────────────────────
    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ── BLOCK 2: Next-state logic ─────────────────────────────
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                next_state = COARSE_TRIM;

            COARSE_TRIM:
                next_state = CHECK_COARSE;

            CHECK_COARSE: begin
                if (freq_low || freq_high)
                    next_state = COARSE_TRIM;
                else
                    next_state = FINE_TRIM;
            end

            FINE_TRIM:
                next_state = CHECK_FINE;

            CHECK_FINE: begin
                if (freq_low || freq_high)
                    next_state = FINE_TRIM;
                else
                    next_state = LOCKED_STATE;
            end

            LOCKED_STATE:
                next_state = LOCKED_STATE;

            default: next_state = IDLE;
        endcase
    end

    // ── BLOCK 3: Output logic ─────────────────────────────────
    // trim_code is only updated in CHECK states — AFTER the
    // FSM has read freq_low/high and decided to trim again.
    // This ensures we always act on a fresh, stable measurement.
    always @(posedge clk) begin
    if (rst) begin
        trim_code <= 4'd4;
        locked    <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                trim_code <= 4'd4;
                locked    <= 1'b0;
            end

            COARSE_TRIM: begin         // ← ADD THIS
                // hold trim_code      // ← ADD THIS
            end                        // ← ADD THIS

            CHECK_COARSE: begin
                locked <= 1'b0;
                if (freq_low) begin
                    if (trim_code <= 4'd13)
                        trim_code <= trim_code + 4'd2;
                    else
                        trim_code <= 4'd15;
                end else if (freq_high) begin
                    if (trim_code >= 4'd2)
                        trim_code <= trim_code - 4'd2;
                    else
                        trim_code <= 4'd0;
                end
            end

            FINE_TRIM: begin           // ← ADD THIS
                // hold trim_code      // ← ADD THIS
            end                        // ← ADD THIS

            CHECK_FINE: begin
                locked <= 1'b0;
                if (freq_low) begin
                    if (trim_code < 4'd15)
                        trim_code <= trim_code + 4'd1;
                end else if (freq_high) begin
                    if (trim_code > 4'd0)
                        trim_code <= trim_code - 4'd1;
                end
            end

            LOCKED_STATE: begin
                locked <= 1'b1;
            end

            default: begin
                trim_code <= 4'd4;
                locked    <= 1'b0;
            end
        endcase
    end
end

endmodule

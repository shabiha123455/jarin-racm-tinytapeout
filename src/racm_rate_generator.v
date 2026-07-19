`default_nettype none

module racm_rate_generator (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [1:0] div_sel,
    output wire       run_tick,
    output wire       debug_rate
);

    reg [2:0] divider_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            divider_count <= 3'b000;
        else if (enable)
            divider_count <= divider_count + 1'b1;
        else
            divider_count <= 3'b000;
    end

    assign run_tick =
        enable &&
        ((div_sel == 2'b00) ||
         ((div_sel == 2'b01) && (divider_count[0] == 1'b0)) ||
         ((div_sel == 2'b10) && (divider_count[1:0] == 2'b00)) ||
         ((div_sel == 2'b11) && (divider_count[2:0] == 3'b000)));

    // Measurement-only output. It never clocks internal state.
    assign debug_rate =
        !enable ? 1'b0 :
        (div_sel == 2'b00) ? clk :
        (div_sel == 2'b01) ? divider_count[0] :
        (div_sel == 2'b10) ? divider_count[1] :
                             divider_count[2];

endmodule

`default_nettype wire

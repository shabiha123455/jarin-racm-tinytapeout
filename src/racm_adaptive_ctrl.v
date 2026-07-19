`default_nettype none

module racm_adaptive_ctrl #(
    parameter integer HYST_WINDOWS = 3
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       window_tick,
    input  wire [1:0] activity_level,
    output reg  [1:0] div_sel,
    output reg        switch_pulse
);

    localparam integer HW =
        (HYST_WINDOWS <= 1) ? 1 : $clog2(HYST_WINDOWS + 1);

    reg [1:0] pending_div;
    reg [HW-1:0] stable_count;
    reg [1:0] requested_div;

    always @(*) begin
        case (activity_level)
            2'b11: requested_div = 2'b00; // high   -> /1
            2'b10: requested_div = 2'b01; // medium -> /2
            2'b01: requested_div = 2'b10; // low    -> /4
            default: requested_div = 2'b11; // idle -> /8
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_sel      <= 2'b00;
            pending_div  <= 2'b00;
            stable_count <= {HW{1'b0}};
            switch_pulse <= 1'b0;
        end else begin
            switch_pulse <= 1'b0;

            if (window_tick) begin
                if (requested_div != pending_div) begin
                    pending_div  <= requested_div;
                    stable_count <= {{(HW-1){1'b0}}, 1'b1};
                end else if (requested_div == div_sel) begin
                    stable_count <= {HW{1'b0}};
                end else if (HYST_WINDOWS <= 1 ||
                             stable_count >= HYST_WINDOWS - 1) begin
                    div_sel      <= requested_div;
                    stable_count <= {HW{1'b0}};
                    switch_pulse <= 1'b1;
                end else begin
                    stable_count <= stable_count + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire

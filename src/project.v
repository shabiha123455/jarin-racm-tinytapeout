`default_nettype none

module tt_um_jarin_racm (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire internal_rst_n = rst_n & ena;

    wire [1:0] activity_level;
    wire [1:0] div_sel;
    wire sleep_req;
    wire wake_ack;
    wire debug_rate;
    wire [7:0] demo_counter;

    racm_core u_racm_core (
        .clk            (clk),
        .rst_n          (internal_rst_n),
        .core_stall     (ui_in[0]),
        .core_valid     (ui_in[1]),
        .wake_request   (ui_in[2]),
        .activity_level (activity_level),
        .div_sel        (div_sel),
        .sleep_req      (sleep_req),
        .wake_ack       (wake_ack),
        .debug_rate     (debug_rate),
        .demo_counter   (demo_counter)
    );

    assign uo_out = ena ? {
        demo_counter[7],
        debug_rate,
        wake_ack,
        sleep_req,
        div_sel,
        activity_level
    } : 8'h00;

    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    wire _unused = &{uio_in, ui_in[7:3], 1'b0};

endmodule

`default_nettype wire

`default_nettype none

module racm_core #(
    parameter integer WINDOW = 64,
    parameter integer HYST_WINDOWS = 3,
    parameter integer IDLE_WINDOWS_TO_SLEEP = 8,
    parameter integer WAKE_CYCLES = 4
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       core_stall,
    input  wire       core_valid,
    input  wire       wake_request,
    output wire [1:0] activity_level,
    output wire [1:0] div_sel,
    output wire       sleep_req,
    output wire       wake_ack,
    output wire       debug_rate,
    output reg  [7:0] demo_counter
);

    wire window_tick;
    wire switch_pulse;
    wire run_tick;
    wire run_enable;

    racm_activity_monitor #(
        .WINDOW(WINDOW)
    ) u_activity_monitor (
        .clk            (clk),
        .rst_n          (rst_n),
        .sample_valid   (run_enable),
        .core_stall     (core_stall),
        .core_valid     (core_valid),
        .activity_level (activity_level),
        .window_tick    (window_tick)
    );

    racm_adaptive_ctrl #(
        .HYST_WINDOWS(HYST_WINDOWS)
    ) u_adaptive_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .window_tick    (window_tick),
        .activity_level (activity_level),
        .div_sel        (div_sel),
        .switch_pulse   (switch_pulse)
    );

    racm_sleep_ctrl #(
        .IDLE_WINDOWS_TO_SLEEP(IDLE_WINDOWS_TO_SLEEP),
        .WAKE_CYCLES(WAKE_CYCLES)
    ) u_sleep_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .window_tick    (window_tick),
        .activity_level (activity_level),
        .wake_request   (wake_request),
        .sleep_req      (sleep_req),
        .wake_ack       (wake_ack),
        .run_enable     (run_enable)
    );

    racm_rate_generator u_rate_generator (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (run_enable),
        .div_sel    (div_sel),
        .run_tick   (run_tick),
        .debug_rate (debug_rate)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            demo_counter <= 8'h00;
        else if (run_tick)
            demo_counter <= demo_counter + 1'b1;
    end

    wire _unused = switch_pulse;

endmodule

`default_nettype wire

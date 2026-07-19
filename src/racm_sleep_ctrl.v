`default_nettype none

module racm_sleep_ctrl #(
    parameter integer IDLE_WINDOWS_TO_SLEEP = 8,
    parameter integer WAKE_CYCLES = 4
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       window_tick,
    input  wire [1:0] activity_level,
    input  wire       wake_request,
    output reg        sleep_req,
    output reg        wake_ack,
    output wire       run_enable
);

    localparam integer IW =
        (IDLE_WINDOWS_TO_SLEEP <= 1) ? 1 : $clog2(IDLE_WINDOWS_TO_SLEEP + 1);
    localparam integer WW =
        (WAKE_CYCLES <= 1) ? 1 : $clog2(WAKE_CYCLES + 1);

    localparam [1:0] S_ACTIVE = 2'b00;
    localparam [1:0] S_SLEEP  = 2'b01;
    localparam [1:0] S_WAKING = 2'b10;

    reg [1:0] state;
    reg [IW-1:0] idle_windows;
    reg [WW-1:0] wake_count;

    assign run_enable = (state == S_ACTIVE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_ACTIVE;
            idle_windows <= {IW{1'b0}};
            wake_count   <= {WW{1'b0}};
            sleep_req    <= 1'b0;
            wake_ack     <= 1'b0;
        end else begin
            wake_ack <= 1'b0;

            case (state)
                S_ACTIVE: begin
                    sleep_req <= 1'b0;
                    wake_count <= {WW{1'b0}};

                    if (window_tick) begin
                        if (activity_level == 2'b00) begin
                            if (IDLE_WINDOWS_TO_SLEEP <= 1 ||
                                idle_windows >= IDLE_WINDOWS_TO_SLEEP - 1) begin
                                idle_windows <= {IW{1'b0}};
                                sleep_req    <= 1'b1;
                                state        <= S_SLEEP;
                            end else begin
                                idle_windows <= idle_windows + 1'b1;
                            end
                        end else begin
                            idle_windows <= {IW{1'b0}};
                        end
                    end
                end

                S_SLEEP: begin
                    sleep_req <= 1'b1;
                    idle_windows <= {IW{1'b0}};
                    if (wake_request) begin
                        sleep_req  <= 1'b0;
                        wake_count <= {WW{1'b0}};
                        state      <= S_WAKING;
                    end
                end

                S_WAKING: begin
                    sleep_req <= 1'b0;
                    if (WAKE_CYCLES <= 1 || wake_count >= WAKE_CYCLES - 1) begin
                        wake_count <= {WW{1'b0}};
                        wake_ack   <= 1'b1;
                        state      <= S_ACTIVE;
                    end else begin
                        wake_count <= wake_count + 1'b1;
                    end
                end

                default: begin
                    state        <= S_ACTIVE;
                    idle_windows <= {IW{1'b0}};
                    wake_count   <= {WW{1'b0}};
                    sleep_req    <= 1'b0;
                end
            endcase
        end
    end

endmodule

`default_nettype wire

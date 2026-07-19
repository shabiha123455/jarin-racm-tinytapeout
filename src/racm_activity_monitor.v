`default_nettype none

module racm_activity_monitor #(
    parameter integer WINDOW = 64
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sample_valid,
    input  wire       core_stall,
    input  wire       core_valid,
    output reg  [1:0] activity_level,
    output reg        window_tick
);

    localparam integer CW = (WINDOW <= 1) ? 1 : $clog2(WINDOW);
    localparam integer AW = (WINDOW <= 1) ? 1 : $clog2(WINDOW + 1);

    reg [CW-1:0] window_count;
    reg [AW-1:0] active_count;

    wire active_sample = sample_valid && core_valid && !core_stall;
    wire [AW:0] final_active_count =
        {1'b0, active_count} + (active_sample ? 1'b1 : 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_count   <= {CW{1'b0}};
            active_count   <= {AW{1'b0}};
            activity_level <= 2'b11;
            window_tick    <= 1'b0;
        end else begin
            window_tick <= 1'b0;

            if (sample_valid) begin
                if (window_count == WINDOW - 1) begin
                    window_count <= {CW{1'b0}};
                    active_count <= {AW{1'b0}};
                    window_tick  <= 1'b1;

                    if ((final_active_count * 4) >= (WINDOW * 3))
                        activity_level <= 2'b11;
                    else if ((final_active_count * 2) >= WINDOW)
                        activity_level <= 2'b10;
                    else if ((final_active_count * 4) >= WINDOW)
                        activity_level <= 2'b01;
                    else
                        activity_level <= 2'b00;
                end else begin
                    window_count <= window_count + 1'b1;
                    if (active_sample)
                        active_count <= active_count + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire

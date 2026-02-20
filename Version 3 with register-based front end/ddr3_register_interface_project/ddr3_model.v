`timescale 1ns / 1ps

module ddr3_model (
    input wire clk,
    input wire rst,

    input wire app_en,
    input wire [2:0] app_cmd,
    input wire [27:0] app_addr,
    input wire [127:0] app_wdf_data,
    input wire app_wdf_wren,

    output reg app_rdy,
    output reg app_wdf_rdy,
    output reg [127:0] app_rd_data,
    output reg app_rd_data_valid
);

    reg [127:0] mem_array [0:1023];

    parameter LATENCY_CYCLES = 5;
    parameter FIFO_DEPTH = 16;

    reg [27:0] rd_addr_fifo [0:FIFO_DEPTH-1];
    reg [3:0] rd_timer_fifo [0:FIFO_DEPTH-1];
    reg [3:0] fifo_head, fifo_tail;
    reg [3:0] fifo_count;

    integer i;

    initial begin
        app_rdy = 1;
        app_wdf_rdy = 1;
        app_rd_data = 0;
        app_rd_data_valid = 0;
        fifo_head = 0;
        fifo_tail = 0;
        fifo_count = 0;
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            rd_timer_fifo[i] = 0;
            rd_addr_fifo[i] = 0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            app_rd_data_valid <= 0;
            app_rd_data <= 0;
            fifo_head <= 0;
            fifo_tail <= 0;
            fifo_count <= 0;
            for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
                rd_timer_fifo[i] <= 0;
                rd_addr_fifo[i] <= 0;
            end
        end else begin
            app_rd_data_valid <= 0;

            if (app_en && app_cmd == 3'b000 && app_wdf_wren) begin
                mem_array[app_addr] <= app_wdf_data;
            end

            if (app_en && app_cmd == 3'b001 && fifo_count < FIFO_DEPTH) begin
                rd_addr_fifo[fifo_tail] <= app_addr;
                rd_timer_fifo[fifo_tail] <= LATENCY_CYCLES;
                fifo_tail <= fifo_tail + 1;
                fifo_count <= fifo_count + 1;
            end

            if (fifo_count > 0) begin
                if (rd_timer_fifo[fifo_head] > 0) begin
                    rd_timer_fifo[fifo_head] <= rd_timer_fifo[fifo_head] - 1;
                end else begin
                    app_rd_data <= mem_array[rd_addr_fifo[fifo_head]];
                    app_rd_data_valid <= 1;
                    fifo_head <= fifo_head + 1;
                    fifo_count <= fifo_count - 1;
                end
            end
        end
    end
endmodule
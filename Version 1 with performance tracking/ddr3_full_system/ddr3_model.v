// ddr3_model.v - Custom Behavioral DDR3 Simulation Model
`timescale 1ns / 1ps

module ddr3_model (
    input wire clk,
    input wire rst,

    input wire app_en,
    input wire [2:0] app_cmd,         // 3'b000: write, 3'b001: read
    input wire [27:0] app_addr,
    input wire [127:0] app_wdf_data,
    input wire app_wdf_wren,

    output reg app_rdy,
    output reg app_wdf_rdy,
    output reg [127:0] app_rd_data,
    output reg app_rd_data_valid
);

    // Simulated memory (128-bit wide, 512 locations)
    reg [127:0] mem_array [0:511];

    // Delay tracking
    parameter LATENCY_CYCLES = 5;
    reg [4:0] delay_counter;
    reg [127:0] read_buffer;
    reg [27:0] read_addr;
    reg pending_read;

    initial begin
        app_rdy = 1;
        app_wdf_rdy = 1;
        app_rd_data = 0;
        app_rd_data_valid = 0;
        delay_counter = 0;
        pending_read = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            app_rd_data_valid <= 0;
            delay_counter <= 0;
            pending_read <= 0;
        end else begin
            app_rd_data_valid <= 0;

            if (app_en && app_cmd == 3'b000 && app_wdf_wren) begin
                // WRITE
                mem_array[app_addr] <= app_wdf_data;
                $display("[DDR3_MODEL] WRITE to addr 0x%h = 0x%h", app_addr, app_wdf_data);
            end
            else if (app_en && app_cmd == 3'b001) begin
                // READ: register request
                read_addr <= app_addr;
                pending_read <= 1;
                delay_counter <= 0;
                $display("[DDR3_MODEL] READ request for addr 0x%h", app_addr);
            end

            // READ pipeline
            if (pending_read) begin
                delay_counter <= delay_counter + 1;
                if (delay_counter == LATENCY_CYCLES) begin //simulates real-world delay
                    app_rd_data <= mem_array[read_addr];
                    app_rd_data_valid <= 1;
                    $display("[DDR3_MODEL] READ response from addr 0x%h = 0x%h", read_addr, mem_array[read_addr]);
                    pending_read <= 0;
                end
            end
        end
    end
endmodule
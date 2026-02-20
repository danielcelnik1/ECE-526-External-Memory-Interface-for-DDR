// tb_ddr3_full_system.v - Full system testbench with controller and DDR model
`timescale 1ns / 1ps

module tb_ddr3_full_system();

    reg clk = 0;
    reg rst = 1;

    wire app_rdy;
    wire app_wdf_rdy;
    wire app_rd_data_valid;
    wire [127:0] app_rd_data;

    wire app_en;
    wire [2:0] app_cmd;
    wire [27:0] app_addr;
    wire [127:0] app_wdf_data;
    wire app_wdf_wren;

    wire [1:0] status;
    wire [31:0] transfer_counter;
    wire [31:0] cycle_counter;

    ddr3_interface ctrl (
        .clk(clk),
        .rst(rst),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rd_data(app_rd_data),
        .app_en(app_en),
        .app_cmd(app_cmd),
        .app_addr(app_addr),
        .app_wdf_data(app_wdf_data),
        .app_wdf_wren(app_wdf_wren),
        .status(status),
        .transfer_counter(transfer_counter),
        .cycle_counter(cycle_counter)
    );

    ddr3_model mem (
        .clk(clk),
        .rst(rst),
        .app_en(app_en),
        .app_cmd(app_cmd),
        .app_addr(app_addr),
        .app_wdf_data(app_wdf_data),
        .app_wdf_wren(app_wdf_wren),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_rd_data(app_rd_data),
        .app_rd_data_valid(app_rd_data_valid)
    );

    always #5 clk = ~clk;

    initial begin
        $display("Starting full DDR3 system simulation...");
        $dumpfile("ddr3_full_system.vcd");
        $dumpvars(0, tb_ddr3_full_system);

        #20 rst = 0;

        wait (status != 2'b00);
        #10;

        if (status == 2'b01) begin
            $display("✅ TEST PASSED: All transfers correct.");
        end else if (status == 2'b10) begin
            $display("❌ TEST FAILED: Data mismatch detected.");
        end

        $display("Transfers: %0d, Total Latency: %0d cycles, Avg Latency: %.2f",
            transfer_counter, cycle_counter,
            (transfer_counter != 0) ? (cycle_counter * 1.0 / transfer_counter) : 0.0);

        #20 $finish;
    end
endmodule
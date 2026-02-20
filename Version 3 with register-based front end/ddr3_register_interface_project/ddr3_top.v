// ddr3_top.v - Top-level integration with register-based front-end
`timescale 1ns / 1ps

module ddr3_top();
    reg clk = 0;
    reg rst = 1;

    // Interface registers
    reg        write_trigger;
    reg [27:0] write_addr_reg;
    reg [127:0] write_data_reg;

    reg        read_trigger;
    reg [27:0] read_addr_reg;
    wire [127:0] read_data_reg;
    wire [1:0] status_reg;

    wire app_rdy, app_wdf_rdy, app_rd_data_valid;
    wire [127:0] app_rd_data;
    wire app_en, app_wdf_wren;
    wire [2:0] app_cmd;
    wire [27:0] app_addr;
    wire [127:0] app_wdf_data;

    // Instantiate controller
    ddr3_interface_regctrl controller (
        .clk(clk),
        .rst(rst),
        .write_trigger(write_trigger),
        .write_addr(write_addr_reg),
        .write_data(write_data_reg),
        .read_trigger(read_trigger),
        .read_addr(read_addr_reg),
        .read_data(read_data_reg),
        .status(status_reg),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rd_data(app_rd_data),
        .app_en(app_en),
        .app_cmd(app_cmd),
        .app_addr(app_addr),
        .app_wdf_data(app_wdf_data),
        .app_wdf_wren(app_wdf_wren)
    );

    // Instantiate memory model
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

    // Simulate CPU register writes
    initial begin
        $display("Starting full DDR3 register interface test...");
        #10 rst = 0;
        write_trigger = 0;
        read_trigger = 0;

        // Burst write to address 0
        write_addr_reg = 28'd0;
        write_data_reg = 128'hCAFEBABE_DEADBEEF_11223344_55667788;
        #20 write_trigger = 1;
        #10 write_trigger = 0;

        // Wait before burst read
        #100;
        read_addr_reg = 28'd0;
        #20 read_trigger = 1;
        #10 read_trigger = 0;

        // Wait for read to finish
        wait (status_reg != 2'b00);
        #10;
        $display("Final Read Result: %h", read_data_reg);
        $display("Status: %b", status_reg);

        #50 $finish;
    end

    always #5 clk = ~clk;
endmodule
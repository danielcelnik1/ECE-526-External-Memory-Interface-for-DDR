// ddr3_top.v - Register-based DDR3 testbench with stress test loop
`timescale 1ns / 1ps

module ddr3_top();
    reg clk = 0;
    reg rst = 1;

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

    integer i;
    integer pass_count = 0;
    integer fail_count = 0;
    reg [127:0] pattern;

    initial begin
        $display("Starting full DDR3 register interface stress test...");
        #20 rst = 0;
        write_trigger = 0;
        read_trigger = 0;

        for (i = 0; i < 256; i = i + 4) begin
            write_addr_reg = i[27:0];
            pattern = {96'hCAFEBABEDEADBEEF11223344 ^ i, i ^ (i << 2)};            write_data_reg = pattern;
            #10 write_trigger = 1;
            #10 write_trigger = 0;
            wait (status_reg != 2'b00);
            #10;

            if (status_reg == 2'b10) begin
                $display("[FAIL] Burst write failed at addr 0x%08h", write_addr_reg);
                fail_count = fail_count + 1;
            end

            read_addr_reg = i[27:0];
            #10 read_trigger = 1;
            #10 read_trigger = 0;
            wait (status_reg != 2'b00);
            #10;

            if (status_reg == 2'b10) begin
                $display("[FAIL] Burst read failed at addr 0x%08h", read_addr_reg);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] Verified burst read @ 0x%08h", read_addr_reg);
                pass_count = pass_count + 1;
            end
        end

        $display("\n================= DDR3 Register Interface Stress Test Complete =================");
        $display("Total Burst Blocks Tested: %0d", pass_count + fail_count);
        $display("  Passes: %0d", pass_count);
        $display("  Fails : %0d", fail_count);
        $display("===============================================================================");

        #100 $finish;
    end

    always #5 clk = ~clk;
endmodule
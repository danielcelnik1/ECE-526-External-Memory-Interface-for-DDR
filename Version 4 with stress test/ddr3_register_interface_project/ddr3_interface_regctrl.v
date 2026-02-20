// ddr3_interface_regctrl.v - Register-based burst controller with debug logging
module ddr3_interface_regctrl (
    input wire clk,
    input wire rst,

    input wire write_trigger,
    input wire [27:0] write_addr,
    input wire [127:0] write_data,

    input wire read_trigger,
    input wire [27:0] read_addr,
    output reg [127:0] read_data,
    output reg [1:0] status,

    input wire app_rdy,
    input wire app_wdf_rdy,
    input wire app_rd_data_valid,
    input wire [127:0] app_rd_data,

    output reg app_en,
    output reg [2:0] app_cmd,
    output reg [27:0] app_addr,
    output reg [127:0] app_wdf_data,
    output reg app_wdf_wren
);

    reg [2:0] state;
    parameter IDLE = 3'd0,
              ISSUE_WRITE = 3'd1,
              ISSUE_WRITE_BURST = 3'd2,
              WAIT_BEFORE_READ = 3'd3,
              ISSUE_READ = 3'd4,
              ISSUE_READ_BURST = 3'd5,
              COMPLETE = 3'd6;

    parameter BURST_LENGTH = 4;

    reg [2:0] burst_counter;
    reg [27:0] base_addr;
    reg [127:0] base_data;
    reg [127:0] compare_expected;
    reg [2:0] read_req_counter;
    reg [2:0] read_resp_counter;
    reg [2:0] settle_delay;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            app_en <= 0;
            app_cmd <= 0;
            app_addr <= 0;
            app_wdf_data <= 0;
            app_wdf_wren <= 0;
            read_data <= 0;
            status <= 2'b00;
            burst_counter <= 0;
            read_req_counter <= 0;
            read_resp_counter <= 0;
            base_addr <= 0;
            base_data <= 0;
            settle_delay <= 0;
        end else begin
            app_en <= 0;
            app_wdf_wren <= 0;
            app_cmd <= 3'b000;

            case (state)
                IDLE: begin
                    status <= 2'b00;
                    if (write_trigger) begin
                        base_addr <= write_addr;
                        base_data <= write_data;
                        burst_counter <= 0;
                        $display("[REGCTRL] Write trigger received. Starting burst write at addr 0x%08h", write_addr);
                        state <= ISSUE_WRITE;
                    end else if (read_trigger) begin
                        base_addr <= read_addr;
                        burst_counter <= 0;
                        $display("[REGCTRL] Read trigger received. Starting burst read at addr 0x%08h", read_addr);
                        state <= ISSUE_READ;
                    end
                end

                ISSUE_WRITE: begin
                    if (app_rdy && app_wdf_rdy) begin
                        app_en <= 1;
                        app_cmd <= 3'b000;
                        app_addr <= base_addr;
                        app_wdf_data <= base_data;
                        app_wdf_wren <= 1;
                        burst_counter <= 1;
                        $display("[REGCTRL] WRITE 0x%08h = 0x%032h", base_addr, base_data);
                        state <= ISSUE_WRITE_BURST;
                    end
                end

                ISSUE_WRITE_BURST: begin
                    if (burst_counter < BURST_LENGTH && app_rdy && app_wdf_rdy) begin
                        app_en <= 1;
                        app_cmd <= 3'b000;
                        app_addr <= base_addr + burst_counter;
                        app_wdf_data <= base_data ^ burst_counter;
                        app_wdf_wren <= 1;
                        $display("[REGCTRL] WRITE 0x%08h = 0x%032h", base_addr + burst_counter, base_data ^ burst_counter);
                        burst_counter <= burst_counter + 1;
                        if (burst_counter == BURST_LENGTH - 1)
                            state <= WAIT_BEFORE_READ;
                    end
                end

                WAIT_BEFORE_READ: begin
                    settle_delay <= settle_delay + 1;
                    if (settle_delay == 3'd3) begin
                        settle_delay <= 0;
                        state <= COMPLETE;
                        $display("[REGCTRL] Write burst complete.");
                        status <= 2'b01;
                    end
                end

                ISSUE_READ: begin
                    if (app_rdy) begin
                        app_en <= 1;
                        app_cmd <= 3'b001;
                        app_addr <= base_addr;
                        read_req_counter <= 1;
                        read_resp_counter <= 0;
                        burst_counter <= 1;
                        $display("[REGCTRL] READ request for addr 0x%08h", base_addr);
                        state <= ISSUE_READ_BURST;
                    end
                end

                ISSUE_READ_BURST: begin
                    if (read_req_counter < BURST_LENGTH && app_rdy) begin
                        app_en <= 1;
                        app_cmd <= 3'b001;
                        app_addr <= base_addr + read_req_counter;
                        $display("[REGCTRL] READ request for addr 0x%08h", base_addr + read_req_counter);
                        read_req_counter <= read_req_counter + 1;
                    end
                    if (app_rd_data_valid) begin
                        compare_expected = base_data ^ read_resp_counter;
                        if (app_rd_data == compare_expected) begin
                            $display("[REGCTRL] READ OK   Addr: 0x%08h Data: 0x%032h", base_addr + read_resp_counter, app_rd_data);
                            read_resp_counter <= read_resp_counter + 1;
                            if (read_resp_counter == BURST_LENGTH - 1) begin
                                read_data <= app_rd_data;
                                status <= 2'b01;
                                $display("[REGCTRL] Burst read complete and verified.");
                                state <= COMPLETE;
                            end
                        end else begin
                            $display("[REGCTRL] READ FAIL Addr: 0x%08h Data: 0x%032h Expected: 0x%032h",
                                     base_addr + read_resp_counter, app_rd_data, compare_expected);
                            status <= 2'b10;
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    $display("[REGCTRL] Returning to IDLE.");
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
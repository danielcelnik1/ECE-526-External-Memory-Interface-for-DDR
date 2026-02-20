// ddr3_interface.v - Clean version with polished output for logging
module ddr3_interface (
    input wire clk,
    input wire rst,

    input wire app_rdy,
    input wire app_wdf_rdy,
    input wire app_rd_data_valid,
    input wire [127:0] app_rd_data,

    output reg app_en,
    output reg [2:0] app_cmd,
    output reg [27:0] app_addr,
    output reg [127:0] app_wdf_data,
    output reg app_wdf_wren,

    output reg [1:0] status,
    output reg [31:0] transfer_counter,
    output reg [31:0] cycle_counter
);

    reg [2:0] state;
    parameter S_IDLE = 3'd0,
              S_WRITE = 3'd1,
              S_WRITE_BURST = 3'd2,
              S_WAIT_BEFORE_READ = 3'd3,
              S_READ = 3'd4,
              S_READ_BURST = 3'd5;

    parameter BURST_LENGTH = 4;
    parameter MAX_ADDR = 28'd32;

    reg [27:0] addr;
    reg [127:0] expected_data;
    reg [127:0] compare_expected;
    reg [31:0] latency_counter;
    reg measuring;

    reg [2:0] burst_counter;
    reg [2:0] read_req_counter;
    reg [2:0] read_resp_counter;
    reg [2:0] write_settle_counter;

    reg [27:0] next_addr;
    reg [127:0] next_data;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            app_en <= 0;
            app_cmd <= 0;
            app_addr <= 0;
            app_wdf_data <= 0;
            app_wdf_wren <= 0;
            addr <= 0;
            transfer_counter <= 0;
            cycle_counter <= 0;
            latency_counter <= 0;
            measuring <= 0;
            status <= 0;
            burst_counter <= 0;
            read_req_counter <= 0;
            read_resp_counter <= 0;
            write_settle_counter <= 0;
        end else begin
            app_en <= 0;
            app_wdf_wren <= 0;
            app_cmd <= 3'b000;

            case (state)

                S_IDLE: begin
                    burst_counter <= 0;
                    read_req_counter <= 0;
                    read_resp_counter <= 0;
                    latency_counter <= 0;
                    measuring <= 0;
                    write_settle_counter <= 0;

                    $display("\\n== New Burst @ Address 0x%08h ==", addr);
                    expected_data <= 128'hCAFEBABE_DEADBEEF_11223344_55667788 ^ addr;
                    state <= S_WRITE;
                end

                S_WRITE: begin
                    if (app_rdy && app_wdf_rdy) begin
                        app_en <= 1;
                        app_cmd <= 3'b000;
                        app_addr <= addr;
                        app_wdf_data <= expected_data;
                        app_wdf_wren <= 1;
                        burst_counter <= 0;
                        write_settle_counter <= 0;
                        $display("  [WRITE] Addr: 0x%08h Data: 0x%032h", addr, expected_data);
                        state <= S_WRITE_BURST;
                    end
                end

                S_WRITE_BURST: begin
                    if (burst_counter < BURST_LENGTH - 1 && app_rdy && app_wdf_rdy) begin
                        next_addr = addr + burst_counter + 1;
                        next_data = 128'hCAFEBABE_DEADBEEF_11223344_55667788 ^ next_addr;

                        app_en <= 1;
                        app_cmd <= 3'b000;
                        app_addr <= next_addr;
                        app_wdf_data <= next_data;
                        app_wdf_wren <= 1;

                        $display("  [WRITE] Addr: 0x%08h Data: 0x%032h", next_addr, next_data);

                        burst_counter <= burst_counter + 1;
                    end else if (burst_counter >= BURST_LENGTH - 1) begin
                        state <= S_WAIT_BEFORE_READ;
                    end
                end

                S_WAIT_BEFORE_READ: begin
                    if (write_settle_counter < 3)
                        write_settle_counter <= write_settle_counter + 1;
                    else
                        state <= S_READ;
                end

                S_READ: begin
                    if (app_rdy) begin
                        burst_counter <= 0;
                        read_req_counter <= 0;
                        read_resp_counter <= 0;
                        measuring <= 1;
                        latency_counter <= 0;
                        $display("  [READ ] Starting burst read @ Address 0x%08h", addr);
                        state <= S_READ_BURST;
                    end
                end

                S_READ_BURST: begin
                    if (measuring)
                        latency_counter <= latency_counter + 1;

                    if (app_rdy && read_req_counter < BURST_LENGTH) begin
                        app_en <= 1;
                        app_cmd <= 3'b001;
                        app_addr <= addr + read_req_counter;
                        read_req_counter <= read_req_counter + 1;
                    end

                    if (app_rd_data_valid) begin
                        compare_expected = 128'hCAFEBABE_DEADBEEF_11223344_55667788 ^ (addr + read_resp_counter);

                        if (app_rd_data == compare_expected) begin
                            $display("  [READ ] Addr: 0x%08h OK   Data: 0x%032h", addr + read_resp_counter, app_rd_data);
                            read_resp_counter <= read_resp_counter + 1;
                            burst_counter <= burst_counter + 1;

                            if (burst_counter + 1 == BURST_LENGTH) begin
                                measuring <= 0;
                                transfer_counter <= transfer_counter + BURST_LENGTH;
                                cycle_counter <= cycle_counter + latency_counter;
                                addr <= addr + BURST_LENGTH;

                                if (addr + BURST_LENGTH < MAX_ADDR)
                                    state <= S_IDLE;
                                else begin
                                    status <= 2'b01;
                                    state <= S_IDLE;
                                end
                            end
                        end else begin
                            $display("  [READ ] Addr: 0x%08h FAIL Data: 0x%032h (Expected: 0x%032h)", addr + read_resp_counter, app_rd_data, compare_expected);
                            measuring <= 0;
                            status <= 2'b10;
                            state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end
endmodule

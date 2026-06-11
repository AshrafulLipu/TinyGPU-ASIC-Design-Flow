
`timescale 1ns/1ns
`default_nettype none

module gpu_tb;

    parameter DATA_MEM_ADDR_BITS       = 8;
    parameter DATA_MEM_DATA_BITS       = 8;
    parameter DATA_MEM_NUM_CHANNELS    = 4;
    parameter PROGRAM_MEM_ADDR_BITS    = 8;
    parameter PROGRAM_MEM_DATA_BITS    = 16;
    parameter PROGRAM_MEM_NUM_CHANNELS = 1;
    parameter NUM_CORES                = 2;
    parameter THREADS_PER_BLOCK        = 4;

    reg clk;
    reg reset;
    reg start;
    wire done;

    reg        device_control_write_enable;
    reg  [7:0] device_control_data;

    wire [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
    wire [(PROGRAM_MEM_NUM_CHANNELS*PROGRAM_MEM_ADDR_BITS)-1:0] program_mem_read_address;
    reg  [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
    reg  [(PROGRAM_MEM_NUM_CHANNELS*PROGRAM_MEM_DATA_BITS)-1:0] program_mem_read_data;

    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
    wire [(DATA_MEM_NUM_CHANNELS*DATA_MEM_ADDR_BITS)-1:0] data_mem_read_address;
    reg  [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
    reg  [(DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS)-1:0] data_mem_read_data;

    wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
    wire [(DATA_MEM_NUM_CHANNELS*DATA_MEM_ADDR_BITS)-1:0] data_mem_write_address;
    wire [(DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS)-1:0] data_mem_write_data;
    reg  [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready;

    reg [15:0] program_mem [0:255];
    reg [7:0]  data_mem    [0:255];

    integer i;
    integer ch;

    gpu #(
        .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
        .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
        .DATA_MEM_NUM_CHANNELS(DATA_MEM_NUM_CHANNELS),
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .PROGRAM_MEM_NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS),
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),

        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),

        .program_mem_read_valid(program_mem_read_valid),
        .program_mem_read_address(program_mem_read_address),
        .program_mem_read_ready(program_mem_read_ready),
        .program_mem_read_data(program_mem_read_data),

        .data_mem_read_valid(data_mem_read_valid),
        .data_mem_read_address(data_mem_read_address),
        .data_mem_read_ready(data_mem_read_ready),
        .data_mem_read_data(data_mem_read_data),
        .data_mem_write_valid(data_mem_write_valid),
        .data_mem_write_address(data_mem_write_address),
        .data_mem_write_data(data_mem_write_data),
        .data_mem_write_ready(data_mem_write_ready)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        program_mem_read_ready <= 1'b0;

        if (program_mem_read_valid[0]) begin
            program_mem_read_ready <= 1'b1;
            program_mem_read_data[15:0] <= program_mem[
                program_mem_read_address[PROGRAM_MEM_ADDR_BITS-1:0]
            ];
        end
    end

    always @(posedge clk) begin
        data_mem_read_ready  <= {DATA_MEM_NUM_CHANNELS{1'b0}};
        data_mem_write_ready <= {DATA_MEM_NUM_CHANNELS{1'b0}};

        for (ch = 0; ch < DATA_MEM_NUM_CHANNELS; ch = ch + 1) begin
            if (data_mem_read_valid[ch]) begin
                data_mem_read_ready[ch] <= 1'b1;
                data_mem_read_data[ch*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS]
                    <= data_mem[data_mem_read_address[ch*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS]];
            end

            if (data_mem_write_valid[ch]) begin
                data_mem_write_ready[ch] <= 1'b1;
                data_mem[data_mem_write_address[ch*DATA_MEM_ADDR_BITS +: DATA_MEM_ADDR_BITS]]
                    <= data_mem_write_data[ch*DATA_MEM_DATA_BITS +: DATA_MEM_DATA_BITS];
            end
        end
    end

    initial begin
        $dumpfile("gpu_tb.vcd");
        $dumpvars(0, gpu_tb);

        clk = 1'b0;
        reset = 1'b1;
        start = 1'b0;

        device_control_write_enable = 1'b0;
        device_control_data = 8'd0;

        program_mem_read_ready = 1'b0;
        program_mem_read_data = {PROGRAM_MEM_DATA_BITS{1'b0}};

        data_mem_read_ready = {DATA_MEM_NUM_CHANNELS{1'b0}};
        data_mem_read_data = {(DATA_MEM_NUM_CHANNELS*DATA_MEM_DATA_BITS){1'b0}};
        data_mem_write_ready = {DATA_MEM_NUM_CHANNELS{1'b0}};

        for (i = 0; i < 256; i = i + 1) begin
            program_mem[i] = 16'h0000;
            data_mem[i] = 8'h00;
        end

        program_mem[0] = 16'h910A; // CONST R1, 10
        program_mem[1] = 16'h9214; // CONST R2, 20
        program_mem[2] = 16'h3312; // ADD R3, R1, R2
        program_mem[3] = 16'h80F3; // STR MEM[R15/threadIdx] = R3
        program_mem[4] = 16'hF000; // RET

        $display("==============================================================");
        $display("                 GPU TESTBENCH MONITOR STARTED               ");
        $display("==============================================================");
        $display("Time | reset start done | ProgValid ProgAddr ProgData | DataWrValid DataWrAddr DataWrData");
        $display("--------------------------------------------------------------");

        $monitor(
            "%4t |   %b     %b    %b  |     %b        %0d      %h   |     %b        %0d        %0d",
            $time,
            reset,
            start,
            done,
            program_mem_read_valid[0],
            program_mem_read_address[7:0],
            program_mem_read_data[15:0],
            data_mem_write_valid,
            data_mem_write_address[7:0],
            data_mem_write_data[7:0]
        );

        #20;
        reset = 1'b0;

        @(posedge clk);
        device_control_write_enable = 1'b1;
        device_control_data = 8'd4;

        @(posedge clk);
        device_control_write_enable = 1'b0;

        @(posedge clk);
        start = 1'b1;

        wait(done == 1'b1);

        #50;

        $display("==============================================================");
        $display("                 FINAL DATA MEMORY RESULT                    ");
        $display("==============================================================");
        $display("DATA_MEM[0] = %0d", data_mem[0]);
        $display("DATA_MEM[1] = %0d", data_mem[1]);
        $display("DATA_MEM[2] = %0d", data_mem[2]);
        $display("DATA_MEM[3] = %0d", data_mem[3]);

        if ((data_mem[0] == 8'd30) &&
            (data_mem[1] == 8'd30) &&
            (data_mem[2] == 8'd30) &&
            (data_mem[3] == 8'd30)) begin
            $display("==============================================================");
            $display("                    GPU TEST PASSED                          ");
            $display("==============================================================");
        end else begin
            $display("==============================================================");
            $display("                    GPU TEST FAILED                          ");
            $display("==============================================================");
        end

        $finish;
    end

    initial begin
        #5000;
        $display("ERROR: Simulation timeout.");
        $finish;
    end

endmodule

`default_nettype wire

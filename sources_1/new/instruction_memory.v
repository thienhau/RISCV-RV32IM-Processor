module instruction_memory (
    input clk, reset,
    input flush,
    input mem_read_req,
    input [11:0] mem_addr,
    output [63:0] mem_read_data,
    output reg mem_read_valid
);
    parameter LATENCY_CYCLE = 2;
    reg [2:0] cycle_count = 0;

    (* ram_style = "block" *)
    reg [31:0] imem [0:1023];
    
    // initial begin
    //     $readmemh("imem.mem", imem);
    // end

    wire [9:0] word_addr = mem_addr[11:2];

    reg [31:0] read_data_low, read_data_high;

    always @(posedge clk) begin
        if (mem_read_req && cycle_count == LATENCY_CYCLE - 1) begin
            read_data_low <= imem[word_addr];
            read_data_high <= imem[word_addr + 1];
        end
        else begin
            read_data_low <= 0;
            read_data_high <= 0;
        end
    end

    assign mem_read_data = {read_data_high, read_data_low};

    // Control logic
    always @(posedge clk) begin
        if (reset) begin
            cycle_count <= 0;
            mem_read_valid <= 0;
        end else if (flush) begin
            cycle_count <= 0;
            mem_read_valid <= 0;
        end else begin
            // Default
            mem_read_valid <= 0;
            
            if (mem_read_req) begin
                if (cycle_count == 0) begin
                    // New fetch
                    cycle_count <= cycle_count + 1;
                end else if (cycle_count < LATENCY_CYCLE - 1) begin
                    cycle_count <= cycle_count + 1;
                end else if (cycle_count == LATENCY_CYCLE - 1) begin
                    mem_read_valid <= 1;
                    cycle_count <= 0;
                end
            end else begin
                cycle_count <= 0;
            end
        end
    end
endmodule
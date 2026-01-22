module data_memory (
    input clk, reset,
    input mem_read_req, 
    input mem_write_req,
    input [11:0] mem_addr,
    input [31:0] mem_write_data,
    output reg [31:0] mem_read_data,
    output reg mem_read_valid, 
    output reg mem_write_back_valid
);
    parameter LATENCY_CYCLE = 2;
    reg [2:0] cycle_count = 0;

    (* ram_style = "block" *)
    reg [31:0] dmem [0:1023];

    initial begin
        $readmemh("dmem.mem", dmem);
    end

    wire [9:0] word_addr = mem_addr[11:2];

    // RAM operations
    always @(posedge clk) begin
        // Write operation
        if (mem_write_req && cycle_count == LATENCY_CYCLE - 1) begin
            dmem[word_addr] <= mem_write_data;
        end
        // Read operation
        else if (mem_read_req && !mem_write_req && cycle_count == LATENCY_CYCLE - 1) begin
            mem_read_data <= dmem[word_addr];
        end
        else begin
            mem_read_data <= 0;
        end
    end

    // Control logic
    always @(posedge clk) begin
        if (reset) begin
            cycle_count <= 0;
            mem_read_valid <= 0;
            mem_write_back_valid <= 0;
        end else begin
            // Default values
            mem_read_valid <= 0;
            mem_write_back_valid <= 0;
            
            if (mem_read_req && !mem_write_req) begin
                // Read operation
                if (cycle_count == 0) begin
                    cycle_count <= cycle_count + 1;
                end else if (cycle_count < LATENCY_CYCLE - 1) begin
                    cycle_count <= cycle_count + 1;
                end else if (cycle_count == LATENCY_CYCLE - 1) begin
                    mem_read_valid <= 1;
                    cycle_count <= 0;
                end
            end 
            else if (mem_write_req) begin
                // Write operation
                if (cycle_count == 0) begin
                    cycle_count <= cycle_count + 1;
                end else if (cycle_count < LATENCY_CYCLE - 1) begin
                    cycle_count <= cycle_count + 1;
                end else if (cycle_count == LATENCY_CYCLE - 1) begin
                    mem_write_back_valid <= 1;
                    cycle_count <= 0;
                end
            end 
            else begin
                cycle_count <= 0;
            end
        end
    end
endmodule

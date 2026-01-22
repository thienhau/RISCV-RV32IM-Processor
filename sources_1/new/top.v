module top (
    input clk,
    input reset,
    input riscv_start,
    output riscv_done,
    output led,
    output led_riscv_start
);
    // Cache interfaces
    wire icache_read_req, icache_hit, icache_stall;
    wire [11:0] icache_addr;
    wire [31:0] icache_read_data;
    
    wire dcache_read_req, dcache_write_req, dcache_hit, dcache_stall;
    wire [11:0] dcache_addr;
    wire [31:0] dcache_write_data, dcache_read_data;
    
    // Memory interfaces
    wire imem_read_req, imem_read_valid;
    wire [11:0] imem_addr;
    wire [63:0] imem_read_data;
    
    wire dmem_read_req, dmem_write_req, dmem_read_valid, dmem_write_back_valid;
    wire [11:0] dmem_addr;
    wire [31:0] dmem_write_data, dmem_read_data;

    wire flush_top;
    wire mem_unsigned_top;
    wire [1:0] mem_size_top;

    reg [31:0] result;

    reg [2:0] reset_sync = 3'b111;
    wire sync_reset;
    
    always @(posedge clk) begin
        reset_sync <= {reset_sync[1:0], reset};
    end
    
    assign sync_reset = reset_sync[2];

    assign led_riscv_start = riscv_start;
    
    // RISC-V Pipeline
    riscv_pipeline RISCV (
        .clk(clk), 
        .reset(sync_reset), 
        .riscv_start(riscv_start), 
        .riscv_done(riscv_done),
        .icache_read_req(icache_read_req),
        .icache_addr(icache_addr),
        .icache_read_data(icache_read_data),
        .icache_hit(icache_hit),
        .icache_stall(icache_stall),
        .dcache_read_req(dcache_read_req),
        .dcache_write_req(dcache_write_req),
        .dcache_addr(dcache_addr),
        .dcache_write_data(dcache_write_data),
        .dcache_read_data(dcache_read_data),
        .dcache_hit(dcache_hit),
        .dcache_stall(dcache_stall),
        .flush_top(flush_top),
        .mem_size_top(mem_size_top),
        .mem_unsigned_top(mem_unsigned_top)
    );
    
    // Instruction Cache
    instruction_cache IC (
        .clk(clk), 
        .reset(sync_reset), 
        .flush(flush_top),
        .cpu_read_req(icache_read_req),
        .cpu_addr(icache_addr),
        .cpu_read_data(icache_read_data),
        .icache_hit(icache_hit),
        .icache_stall(icache_stall),
        .mem_read_req(imem_read_req),
        .mem_addr(imem_addr),
        .mem_read_data(imem_read_data),
        .mem_read_valid(imem_read_valid)
    );
    
    // Data Cache
    data_cache DC (
        .clk(clk), 
        .reset(sync_reset),
        .cpu_read_req(dcache_read_req),
        .cpu_write_req(dcache_write_req),
        .cpu_addr(dcache_addr),
        .cpu_write_data(dcache_write_data),
        .mem_unsigned(mem_unsigned_top), 
        .mem_size(mem_size_top),
        .cpu_read_data(dcache_read_data),
        .dcache_hit(dcache_hit),
        .dcache_stall(dcache_stall),
        .mem_read_req(dmem_read_req),
        .mem_write_req(dmem_write_req),
        .mem_addr(dmem_addr),
        .mem_write_data(dmem_write_data),
        .mem_read_data(dmem_read_data),
        .mem_read_valid(dmem_read_valid),
        .mem_write_back_valid(dmem_write_back_valid)
    );
    
    // Instruction Memory
    instruction_memory IM (
        .clk(clk), 
        .reset(sync_reset), 
        .flush(flush_top),
        .mem_read_req(imem_read_req),
        .mem_addr(imem_addr),
        .mem_read_data(imem_read_data),
        .mem_read_valid(imem_read_valid)
    );
    
    // Data Memory
    data_memory DM (
        .clk(clk), 
        .reset(sync_reset),
        .mem_read_req(dmem_read_req),
        .mem_write_req(dmem_write_req),
        .mem_addr(dmem_addr),
        .mem_write_data(dmem_write_data),
        .mem_read_data(dmem_read_data),
        .mem_read_valid(dmem_read_valid),
        .mem_write_back_valid(dmem_write_back_valid)
    );
    
    always @(posedge clk or posedge sync_reset) begin
        if (sync_reset) begin
            result <= 0;
        end else if (dcache_write_req && dcache_addr == 0) begin
            result <= dcache_write_data;
        end
    end
    
    assign led = (result == 32'd55) ? 1'b1 : 1'b0;
endmodule


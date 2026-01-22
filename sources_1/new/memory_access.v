module memory_access (
    input [31:0] ex_mem_alu_result, ex_mem_mem_write_data,
    input ex_mem_mem_write, ex_mem_mem_read,
    output [31:0] mem_read_data,
    
    // dcache interface
    output dcache_read_req,
    output dcache_write_req,
    output [11:0] dcache_addr,
    output [31:0] dcache_write_data,
    input [31:0] dcache_read_data
);
    // dcache connect
    assign dcache_read_req = ex_mem_mem_read;
    assign dcache_write_req = ex_mem_mem_write;
    assign dcache_addr = ex_mem_alu_result[11:0];
    assign dcache_write_data = ex_mem_mem_write_data;
    assign mem_read_data = dcache_read_data;
endmodule
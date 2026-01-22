module write_back (
    input [31:0] mem_wb_mem_read_data, mem_wb_alu_result,
    input [11:0] mem_wb_pc_plus_4,
    input mem_wb_mem_to_reg, mem_wb_jal,
    output [31:0] mem_wb_write_data
);
    assign mem_wb_write_data = (mem_wb_jal) ? mem_wb_pc_plus_4 :
                                mem_wb_mem_to_reg ? mem_wb_mem_read_data : mem_wb_alu_result;
endmodule
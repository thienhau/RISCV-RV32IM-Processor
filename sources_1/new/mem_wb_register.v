module mem_wb_register (
    input clk, reset,
    input dcache_stall, riscv_start, riscv_done,
    input [31:0] mem_read_data,
    input [11:0] ex_mem_pc_plus_4,
    input ex_mem_mem_to_reg, ex_mem_reg_write, ex_mem_jal,
    input [31:0] ex_mem_alu_result,
    input [4:0] ex_mem_rd,
    input ex_mem_ecall,
    output reg [31:0] mem_wb_mem_read_data,
    output reg [11:0] mem_wb_pc_plus_4,
    output reg mem_wb_mem_to_reg, mem_wb_reg_write, mem_wb_jal,
    output reg [31:0] mem_wb_alu_result,
    output reg [4:0] mem_wb_rd,
    output reg mem_wb_ecall
);
    always @(posedge clk) begin
        if (reset) begin
            mem_wb_mem_read_data <= 0;
            mem_wb_alu_result <= 0;
            mem_wb_rd <= 0;
            mem_wb_mem_to_reg <= 0;
            mem_wb_reg_write <= 0;
            mem_wb_pc_plus_4 <= 0;
            mem_wb_jal <= 0;
            mem_wb_ecall <= 0;
        end 
        
        else if (riscv_start && !riscv_done) begin
            if (dcache_stall) begin

            end 
            
            else begin
                mem_wb_mem_read_data <= mem_read_data;
                mem_wb_pc_plus_4 <= ex_mem_pc_plus_4;
                mem_wb_alu_result <= ex_mem_alu_result;
                mem_wb_rd <= ex_mem_rd;
                mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
                mem_wb_reg_write <= ex_mem_reg_write;
                mem_wb_jal <= ex_mem_jal;
                mem_wb_ecall <= ex_mem_ecall;
            end
        end
    end    
endmodule
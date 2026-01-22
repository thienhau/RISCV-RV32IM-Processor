module ex_mem_register (
    input clk, reset,
    input dcache_stall, md_alu_stall, flush, riscv_start, riscv_done,
    input [31:0] alu_result, id_ex_ext_imm, id_ex_instr,
    input [11:0] id_ex_branch_target, id_ex_pc_plus_4, id_ex_pc_in,
    input [4:0] id_ex_rd,
    input id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg, id_ex_reg_write, id_ex_branch, branch_taken, id_ex_jal, id_ex_mem_unsigned,
    input [1:0] id_ex_mem_size,
    input [31:0] id_ex_read_data2,
    input [31:0] mem_write_data,
    input id_ex_predict_taken, id_ex_btb_hit, id_ex_ecall,
    output reg [31:0] ex_mem_alu_result, ex_mem_instr,
    output reg [4:0] ex_mem_rd,
    output reg [11:0] ex_mem_branch_target, ex_mem_pc_plus_4, ex_mem_pc_in,
    output reg ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg, ex_mem_reg_write, ex_mem_branch, ex_mem_branch_taken, ex_mem_jal, ex_mem_mem_unsigned,
    output reg [1:0] ex_mem_mem_size,
    output reg [31:0] ex_mem_mem_write_data,
    output reg ex_mem_predict_taken, ex_mem_btb_hit, ex_mem_ecall
);
    always @(posedge clk) begin
        if (reset) begin
            ex_mem_alu_result <= 0;
            ex_mem_mem_write_data <= 0;
            ex_mem_rd <= 0;
            ex_mem_branch_target <= 0;
            ex_mem_pc_plus_4 <= 0;
            ex_mem_pc_in <= 0;
            ex_mem_branch <= 0;
            ex_mem_branch_taken <= 0;
            ex_mem_mem_write <= 0;
            ex_mem_mem_read <= 0;
            ex_mem_mem_to_reg <= 0;
            ex_mem_reg_write <= 0;
            ex_mem_jal <= 0;
            ex_mem_mem_unsigned <= 0;
            ex_mem_mem_size <= 0;
            ex_mem_predict_taken <= 0;
            ex_mem_btb_hit <= 0;
            ex_mem_instr <= 0;
            ex_mem_ecall <= 0;
        end 
        
        else if (riscv_start && !riscv_done) begin
            if (flush) begin
                ex_mem_reg_write <= 0;
                ex_mem_mem_write <= 0;
                ex_mem_mem_read <= 0;
                ex_mem_mem_to_reg <= 0;
                ex_mem_branch <= 0;
                ex_mem_jal <= 0;
                ex_mem_pc_in <= 0;
                ex_mem_predict_taken <= 0;
                ex_mem_btb_hit <= 0;
            end
            
            else if (dcache_stall  || md_alu_stall) begin

            end

            else begin
                ex_mem_alu_result <= alu_result;
                ex_mem_rd <= id_ex_rd;
                ex_mem_branch_target <= id_ex_branch_target;
                ex_mem_pc_plus_4 <= id_ex_pc_plus_4;
                ex_mem_pc_in <= id_ex_pc_in;
                ex_mem_branch <= id_ex_branch;
                ex_mem_branch_taken <= branch_taken;
                ex_mem_jal <= id_ex_jal;
                ex_mem_mem_unsigned <= id_ex_mem_unsigned;
                ex_mem_mem_write <= id_ex_mem_write;
                ex_mem_mem_read <= id_ex_mem_read;
                ex_mem_mem_to_reg <= id_ex_mem_to_reg;
                ex_mem_reg_write <= id_ex_reg_write;
                ex_mem_mem_size <= id_ex_mem_size;
                ex_mem_mem_write_data <= mem_write_data;
                ex_mem_predict_taken <= id_ex_predict_taken;
                ex_mem_btb_hit <= id_ex_btb_hit;
                ex_mem_instr <= id_ex_instr;
                ex_mem_ecall <= id_ex_ecall;
            end
        end
    end
endmodule
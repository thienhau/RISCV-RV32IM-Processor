module id_ex_register (
    input clk, reset,
    input dcache_stall, md_alu_stall, load_use_stall, flush, riscv_start, riscv_done,
    input [11:0] if_id_pc_plus_4, if_id_pc_in,
    input [2:0] funct3,
    input [31:0] read_data1, read_data2, ext_imm, if_id_instr,
    input [4:0] rs1, rs2, rd,
    input reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, jal, jalr, lui, auipc, mem_unsigned,
    input [1:0] mem_size,
    input [3:0] alu_ctrl,
    input [11:0] branch_target, jal_target,
    input if_id_predict_taken, if_id_btb_hit, ecall,
    output reg [11:0] id_ex_pc_plus_4, id_ex_pc_in,
    output reg [2:0] id_ex_funct3,
    output reg [31:0] id_ex_read_data1, id_ex_read_data2, id_ex_ext_imm, id_ex_instr,
    output reg [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd,
    output reg id_ex_reg_write, id_ex_alu_src, id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg, id_ex_branch, id_ex_jal, id_ex_jalr, id_ex_lui, id_ex_auipc, id_ex_mem_unsigned,
    output reg [1:0] id_ex_mem_size,
    output reg [3:0] id_ex_alu_ctrl,
    output reg [11:0] id_ex_branch_target, id_ex_jal_target,
    output reg id_ex_predict_taken, id_ex_btb_hit, id_ex_ecall,
    // Mul-div signals
    input md_type,
    input [2:0] md_operation,
    output reg id_ex_md_type,
    output reg [2:0] id_ex_md_operation
);
    always @(posedge clk) begin
        if (reset) begin
            id_ex_pc_plus_4 <= 0;
            id_ex_pc_in <= 0;
            id_ex_funct3 <= 0;
            id_ex_read_data1 <= 0;
            id_ex_read_data2 <= 0;
            id_ex_ext_imm <= 0;
            id_ex_rs1 <= 0;
            id_ex_rs2 <= 0;
            id_ex_rd <= 0;
            id_ex_alu_src <= 0;
            id_ex_mem_write <= 0;
            id_ex_mem_read <= 0;
            id_ex_mem_to_reg <= 0;
            id_ex_reg_write <= 0;
            id_ex_branch <= 0;
            id_ex_jal <= 0;
            id_ex_jalr <= 0;
            id_ex_lui <= 0;
            id_ex_auipc <= 0;
            id_ex_mem_unsigned <= 0;
            id_ex_mem_size <= 0;
            id_ex_alu_ctrl <= 0;
            id_ex_branch_target <= 0;
            id_ex_jal_target <= 0;
            id_ex_predict_taken <= 0;
            id_ex_btb_hit <= 0;
            id_ex_instr <= 0;
            id_ex_ecall <= 0;
            id_ex_md_type <= 0;
            id_ex_md_operation <= 0;
        end 
        
        else if (riscv_start && !riscv_done) begin
            if (flush) begin
                id_ex_reg_write <= 0;
                id_ex_mem_write <= 0;
                id_ex_mem_read <= 0;
                id_ex_mem_to_reg <= 0;
                id_ex_branch <= 0;
                id_ex_jal <= 0;
                id_ex_jalr <= 0;
                id_ex_lui <= 0;
                id_ex_auipc <= 0;
                id_ex_pc_in <= 0;
                id_ex_predict_taken <= 0;
                id_ex_btb_hit <= 0;
            end  

            else if (dcache_stall || md_alu_stall) begin

            end  
            
            else if (load_use_stall) begin
                id_ex_reg_write <= 0;
                id_ex_mem_write <= 0;
                id_ex_mem_read <= 0;
                id_ex_mem_to_reg <= 0;
                id_ex_branch <= 0;
                id_ex_jal <= 0;
                id_ex_jalr <= 0;
                id_ex_lui <= 0;
                id_ex_auipc <= 0;
            end
            
            else begin
                id_ex_pc_plus_4 <= if_id_pc_plus_4;
                id_ex_pc_in <= if_id_pc_in;
                id_ex_funct3 <= funct3;
                id_ex_read_data1 <= read_data1;
                id_ex_read_data2 <= read_data2;
                id_ex_ext_imm <= ext_imm;
                id_ex_branch_target <= branch_target;
                id_ex_jal_target <= jal_target;
                id_ex_rs1 <= rs1;
                id_ex_rs2 <= rs2;
                id_ex_rd <= rd;
                id_ex_alu_src <= alu_src;
                id_ex_mem_write <= mem_write;
                id_ex_mem_read <= mem_read;
                id_ex_mem_to_reg <= mem_to_reg;
                id_ex_reg_write <= reg_write;
                id_ex_branch <= branch;
                id_ex_jal <= jal;
                id_ex_jalr <= jalr;
                id_ex_lui <= lui;
                id_ex_auipc <= auipc;
                id_ex_mem_unsigned <= mem_unsigned;
                id_ex_mem_size <= mem_size;
                id_ex_alu_ctrl <= alu_ctrl;
                id_ex_predict_taken <= if_id_predict_taken;
                id_ex_btb_hit <= if_id_btb_hit;
                id_ex_instr <= if_id_instr;
                id_ex_ecall <= ecall;
                id_ex_md_type <= md_type;
                id_ex_md_operation <= md_operation;
            end
        end
    end
endmodule
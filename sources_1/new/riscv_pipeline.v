module riscv_pipeline (
    input clk,
    input reset,
    input riscv_start,
    output reg riscv_done,
    
    // ICache interface
    output icache_read_req,
    output [11:0] icache_addr,
    input [31:0] icache_read_data,
    input icache_hit,
    input icache_stall,
    
    // DCache interface
    output dcache_read_req,
    output dcache_write_req,
    output [11:0] dcache_addr,
    output [31:0] dcache_write_data,
    input [31:0] dcache_read_data,
    input dcache_hit,
    input dcache_stall,

    output flush_top,
    output [1:0] mem_size_top,
    output mem_unsigned_top
);
    // Instruction Fetch signals
    wire [11:0] pc_in, pc_out;
    wire [11:0] pc_plus_4;
    wire [31:0] instr;

    // Branch Prediction signals
    wire predict_taken, bpu_correct, btb_hit, actual_taken;
    wire [11:0] predict_target;
    
    // IF/ID Pipeline signals
    wire [31:0] if_id_instr;
    wire [11:0] if_id_pc_plus_4, if_id_pc_in;
    wire if_id_predict_taken, if_id_btb_hit;
    
    // Instruction Decode signals
    wire [31:0] read_data1, read_data2, ext_imm;
    wire [4:0] rs1, rs2, rd;
    wire [2:0] funct3;
    wire [6:0] opcode, funct7;
    wire [11:0] jal_target, branch_target;
    wire reg_write, alu_src, mem_write, mem_read, mem_to_reg;
    wire branch, jal, jalr, lui, auipc, mem_unsigned;
    wire [1:0] alu_op, mem_size;
    wire [3:0] alu_ctrl;
    wire ecall;
    wire md_type;
    wire [2:0] md_operation;
    
    // ID/EX Pipeline signals
    wire [11:0] id_ex_pc_plus_4, id_ex_pc_in;
    wire [2:0] id_ex_funct3;
    wire [31:0] id_ex_instr;
    wire [31:0] id_ex_read_data1, id_ex_read_data2, id_ex_ext_imm;
    wire [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd;
    wire id_ex_reg_write, id_ex_alu_src;
    wire id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg;
    wire id_ex_branch, id_ex_jal, id_ex_jalr, id_ex_lui, id_ex_auipc, id_ex_mem_unsigned;
    wire [1:0] id_ex_mem_size;
    wire [3:0] id_ex_alu_ctrl;
    wire [11:0] id_ex_branch_target, id_ex_jal_target;
    wire id_ex_predict_taken, id_ex_btb_hit;
    wire id_ex_ecall;
    wire id_ex_md_type;
    wire [2:0] id_ex_md_operation;
    
    // Forwarding Unit signals
    wire [31:0] alu_in1, alu_in2, mem_write_data;
    
    // Execute signals
    wire [31:0] alu_result;
    wire branch_taken;
    
    // EX/MEM Pipeline signals
    wire [31:0] ex_mem_instr;
    wire [31:0] ex_mem_alu_result, ex_mem_mem_write_data;
    wire [11:0] ex_mem_branch_target, ex_mem_pc_plus_4, ex_mem_pc_in;
    wire [4:0] ex_mem_rd;
    wire ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg, ex_mem_branch, ex_mem_branch_taken, ex_mem_jal, ex_mem_mem_unsigned;
    wire ex_mem_reg_write;
    wire [1:0] ex_mem_mem_size;
    wire ex_mem_predict_taken, ex_mem_btb_hit;
    wire ex_mem_ecall;

    // Memory Access signals
    wire [31:0] mem_read_data;
    
    // MEM/WB Pipeline signals
    wire [31:0] mem_wb_mem_read_data, mem_wb_alu_result;
    wire [11:0] mem_wb_pc_plus_4;
    wire mem_wb_mem_to_reg, mem_wb_reg_write, mem_wb_jal;
    wire [4:0] mem_wb_rd;
    wire mem_wb_ecall;
    
    // Write Back signals
    wire [31:0] mem_wb_write_data;
    
    // Pipeline Control signals
    wire load_use_stall, flush_branch, flush_jal, md_alu_stall;

    // Register File signals
    wire [31:0] read_data1_temp, read_data2_temp;

    // PC register
    reg [11:0] pc_reg = 0;
    always @(posedge clk) begin
        if (reset) begin
            pc_reg <= 0;
        end else if (riscv_start && !riscv_done) begin
            if (flush_branch || flush_jal) begin
                pc_reg <= pc_out;
            end else if (!load_use_stall && !icache_stall && !dcache_stall && !md_alu_stall) begin
                pc_reg <= pc_out;
            end
        end
    end
    assign pc_in = pc_reg;

    // Flush signal register
    reg flush_temp = 0;
    always @(posedge clk) begin
        if (reset) begin
            flush_temp <= 0;
        end else if (riscv_start && !riscv_done) begin
            flush_temp <= flush_branch || flush_jal;
        end
    end

    assign flush_top = flush_temp;
    assign mem_size_top = ex_mem_mem_size;
    assign mem_unsigned_top = ex_mem_mem_unsigned;

    // Instruction Fetch
    instruction_fetch IF (
        .flush_temp(flush_temp),
        .ex_mem_branch_target(ex_mem_branch_target),
        .id_ex_jal_target(id_ex_jal_target),
        .pc_in(pc_in), 
        .ex_mem_pc_in(ex_mem_pc_in),
        .id_ex_jalr(id_ex_jalr), 
        .id_ex_jal(id_ex_jal),
        .btb_hit(btb_hit), 
        .alu_in1(alu_in1),
        .predict_taken(predict_taken), 
        .actual_taken(actual_taken),
        .bpu_correct(bpu_correct), 
        .predict_target(predict_target),
        .pc_out(pc_out), 
        .pc_plus_4(pc_plus_4), 
        .instr(instr),
        .icache_read_req(icache_read_req),
        .icache_addr(icache_addr),
        .icache_read_data(icache_read_data)
    );
    
    // IF/ID Pipeline Register
    if_id_register IF_ID (
        .clk(clk),
        .reset(reset),
        .icache_stall(icache_stall),
        .dcache_stall(dcache_stall),
        .md_alu_stall(md_alu_stall),
        .load_use_stall(load_use_stall),
        .flush(flush_branch || flush_jal),
        .riscv_start(riscv_start),
        .riscv_done(riscv_done),
        .instr(instr),
        .pc_plus_4(pc_plus_4),
        .pc_in(pc_in),
        .predict_taken(predict_taken),
        .btb_hit(btb_hit),
        .if_id_instr(if_id_instr),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_pc_in(if_id_pc_in),
        .if_id_predict_taken(if_id_predict_taken),
        .if_id_btb_hit(if_id_btb_hit)
    );
    
    // Instruction Decode
    instruction_decode ID (
        .if_id_pc_in(if_id_pc_in),
        .if_id_instr(if_id_instr),
        .ext_imm(ext_imm),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .funct3(funct3),
        .opcode(opcode),
        .funct7(funct7),
        .jal_target(jal_target),
        .branch_target(branch_target),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .lui(lui),
        .auipc(auipc),
        .mem_unsigned(mem_unsigned),
        .alu_op(alu_op),
        .mem_size(mem_size),
        .alu_ctrl(alu_ctrl),
        .ecall(ecall),
        .md_type(md_type),
        .md_operation(md_operation)
    );
    
    // Register File
    register_file RF(
        .clk(clk),
        .reset(reset),
        .read_reg1(rs1),
        .read_reg2(rs2),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_write_data(mem_wb_write_data),
        .read_data1(read_data1_temp), 
        .read_data2(read_data2_temp)
    );
    
    // Forwarding from MEM/WB to ID
    assign read_data1 = (rs1 != 0 && rs1 == mem_wb_rd && mem_wb_reg_write) 
                    ? mem_wb_write_data : read_data1_temp;

    assign read_data2 = (rs2 != 0 && rs2 == mem_wb_rd && mem_wb_reg_write)
                    ? mem_wb_write_data : read_data2_temp;
    
    // ID/EX Pipeline Register
    id_ex_register ID_EX (
        .clk(clk),
        .reset(reset),
        .dcache_stall(dcache_stall),
        .md_alu_stall(md_alu_stall),
        .load_use_stall(load_use_stall),
        .flush(flush_branch || flush_jal),
        .riscv_start(riscv_start),
        .riscv_done(riscv_done),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_pc_in(if_id_pc_in),
        .funct3(funct3),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .ext_imm(ext_imm),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .lui(lui),
        .auipc(auipc),
        .mem_unsigned(mem_unsigned),
        .mem_size(mem_size),
        .alu_ctrl(alu_ctrl),
        .branch_target(branch_target),
        .jal_target(jal_target),
        .if_id_predict_taken(if_id_predict_taken),
        .if_id_btb_hit(if_id_btb_hit),
        .ecall(ecall),
        .md_type(md_type),
        .md_operation(md_operation),
        .if_id_instr(if_id_instr),
        .id_ex_pc_plus_4(id_ex_pc_plus_4),
        .id_ex_pc_in(id_ex_pc_in),
        .id_ex_funct3(id_ex_funct3),
        .id_ex_read_data1(id_ex_read_data1),
        .id_ex_read_data2(id_ex_read_data2),
        .id_ex_ext_imm(id_ex_ext_imm),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .id_ex_rd(id_ex_rd),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_alu_src(id_ex_alu_src),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_mem_to_reg(id_ex_mem_to_reg),
        .id_ex_branch(id_ex_branch),
        .id_ex_jal(id_ex_jal),
        .id_ex_jalr(id_ex_jalr),
        .id_ex_lui(id_ex_lui),
        .id_ex_auipc(id_ex_auipc),
        .id_ex_mem_unsigned(id_ex_mem_unsigned),
        .id_ex_mem_size(id_ex_mem_size),
        .id_ex_alu_ctrl(id_ex_alu_ctrl),
        .id_ex_branch_target(id_ex_branch_target),
        .id_ex_jal_target(id_ex_jal_target),
        .id_ex_predict_taken(id_ex_predict_taken),
        .id_ex_btb_hit(id_ex_btb_hit),
        .id_ex_ecall(id_ex_ecall),
        .id_ex_md_type(id_ex_md_type),
        .id_ex_md_operation(id_ex_md_operation),
        .id_ex_instr(id_ex_instr)
    );
    
    // Forwarding Unit
    forwarding_unit FU (
        .id_ex_read_data1(id_ex_read_data1),
        .id_ex_read_data2(id_ex_read_data2),
        .id_ex_ext_imm(id_ex_ext_imm),
        .id_ex_rs1(id_ex_rs1),
        .id_ex_rs2(id_ex_rs2),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_reg_write(mem_wb_reg_write),
        .id_ex_alu_src(id_ex_alu_src),
        .ex_mem_rd(ex_mem_rd),
        .mem_wb_rd(mem_wb_rd),
        .ex_mem_alu_result(ex_mem_alu_result),
        .mem_wb_write_data(mem_wb_write_data),
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .mem_write_data(mem_write_data)
    );
    
    // Execute Stage
    execute EX (
        .clk(clk),
        .reset(reset),
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .id_ex_alu_ctrl(id_ex_alu_ctrl),
        .id_ex_funct3(id_ex_funct3),
        .id_ex_branch(id_ex_branch),
        .id_ex_instr(id_ex_instr),
        .id_ex_lui(id_ex_lui),
        .id_ex_auipc(id_ex_auipc),
        .id_ex_md_type(id_ex_md_type),
        .id_ex_md_operation(id_ex_md_operation),
        .id_ex_pc_in(id_ex_pc_in),
        .id_ex_ext_imm(id_ex_ext_imm),
        .alu_result(alu_result),
        .branch_taken(branch_taken),
        .md_alu_stall(md_alu_stall)
    );
    
    // EX/MEM Pipeline Register
    ex_mem_register EX_MEM (
        .clk(clk),
        .reset(reset),
        .dcache_stall(dcache_stall),
        .md_alu_stall(md_alu_stall),
        .flush(flush_branch),
        .riscv_start(riscv_start),
        .riscv_done(riscv_done),
        .alu_result(alu_result),
        .id_ex_read_data2(id_ex_read_data2),
        .id_ex_ext_imm(id_ex_ext_imm),
        .id_ex_rd(id_ex_rd),
        .id_ex_pc_plus_4(id_ex_pc_plus_4),
        .id_ex_pc_in(id_ex_pc_in),
        .id_ex_branch_target(id_ex_branch_target),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_mem_to_reg(id_ex_mem_to_reg),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_branch(id_ex_branch),
        .branch_taken(branch_taken),
        .id_ex_jal(id_ex_jal),
        .id_ex_mem_unsigned(id_ex_mem_unsigned),
        .id_ex_mem_size(id_ex_mem_size),
        .mem_write_data(mem_write_data),
        .id_ex_predict_taken(id_ex_predict_taken),
        .id_ex_btb_hit(id_ex_btb_hit),
        .id_ex_ecall(id_ex_ecall),
        .id_ex_instr(id_ex_instr),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_mem_write_data(ex_mem_mem_write_data),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_pc_plus_4(ex_mem_pc_plus_4),
        .ex_mem_pc_in(ex_mem_pc_in),
        .ex_mem_branch_target(ex_mem_branch_target),
        .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_to_reg(ex_mem_mem_to_reg),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_branch(ex_mem_branch),
        .ex_mem_branch_taken(ex_mem_branch_taken),
        .ex_mem_jal(ex_mem_jal),
        .ex_mem_mem_unsigned(ex_mem_mem_unsigned),
        .ex_mem_mem_size(ex_mem_mem_size),
        .ex_mem_predict_taken(ex_mem_predict_taken),
        .ex_mem_btb_hit(ex_mem_btb_hit),
        .ex_mem_ecall(ex_mem_ecall),
        .ex_mem_instr(ex_mem_instr)
    );
    
    // Memory Access Stage
    memory_access MEM (
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_mem_write_data(ex_mem_mem_write_data),
        .ex_mem_mem_write(ex_mem_mem_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .mem_read_data(mem_read_data),
        .dcache_read_req(dcache_read_req),
        .dcache_write_req(dcache_write_req),
        .dcache_addr(dcache_addr),
        .dcache_write_data(dcache_write_data),
        .dcache_read_data(dcache_read_data)
    );
    
    // MEM/WB Pipeline Register
    mem_wb_register MEM_WB (
        .clk(clk),
        .reset(reset),
        .dcache_stall(dcache_stall),
        .riscv_start(riscv_start),
        .riscv_done(riscv_done),
        .mem_read_data(mem_read_data),
        .ex_mem_pc_plus_4(ex_mem_pc_plus_4),
        .ex_mem_mem_to_reg(ex_mem_mem_to_reg),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_jal(ex_mem_jal),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_ecall(ex_mem_ecall),
        .mem_wb_mem_read_data(mem_wb_mem_read_data),
        .mem_wb_pc_plus_4(mem_wb_pc_plus_4),
        .mem_wb_mem_to_reg(mem_wb_mem_to_reg),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_jal(mem_wb_jal),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_ecall(mem_wb_ecall)
    );
    
    // Write Back Stage
    write_back WB (
        .mem_wb_mem_read_data(mem_wb_mem_read_data),
        .mem_wb_alu_result(mem_wb_alu_result),
        .mem_wb_pc_plus_4(mem_wb_pc_plus_4),
        .mem_wb_mem_to_reg(mem_wb_mem_to_reg),
        .mem_wb_jal(mem_wb_jal),
        .mem_wb_write_data(mem_wb_write_data)
    );
    
    // Pipeline Control Unit
    pipeline_control_unit PCU (
        .opcode(opcode),
        .funct3(funct3),
        .rs1(rs1),
        .rs2(rs2),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_jal(id_ex_jal),
        .id_ex_jalr(id_ex_jalr),
        .id_ex_rd(id_ex_rd),
        .bpu_correct(bpu_correct),
        .load_use_stall(load_use_stall),
        .flush_branch(flush_branch),
        .flush_jal(flush_jal)
    );
    
    // Branch Prediction Unit
    branch_prediction_unit BPU (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_in), 
        .ex_mem_pc_in(ex_mem_pc_in),
        .ex_mem_branch(ex_mem_branch),
        .ex_mem_branch_taken(ex_mem_branch_taken),
        .ex_mem_predict_taken(ex_mem_predict_taken),
        .ex_mem_btb_hit(ex_mem_btb_hit),
        .ex_mem_branch_target(ex_mem_branch_target),
        .bpu_correct(bpu_correct),
        .predict_taken(predict_taken),
        .btb_hit(btb_hit),
        .actual_taken(actual_taken),
        .predict_target(predict_target)
    );
    
    // Control logic
    always @(posedge clk) begin
        if (reset) begin
            riscv_done <= 1'b0;
        end else if (riscv_start) begin
            if (mem_wb_ecall) begin
                riscv_done <= 1'b1;
            end
        end
    end
endmodule
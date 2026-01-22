module instruction_decode (
    input [11:0] if_id_pc_in,
    input [31:0] if_id_instr,
    output [31:0] ext_imm, 
    output reg [4:0] rs1, rs2, rd,
    output reg [2:0] funct3,
    output reg [6:0] opcode, funct7,
    output [11:0] jal_target, branch_target,
    output reg_write, alu_src, mem_write, mem_read, mem_to_reg, 
    output branch, jal, jalr, lui, auipc, mem_unsigned,
    output [1:0] alu_op, mem_size,
    output [3:0] alu_ctrl,
    output md_type,
    output [2:0] md_operation,
    output ecall
);
    reg [19:0] u_imm = 0;
    reg [11:0] i_imm = 0;
    reg [11:0] s_imm = 0;
    reg [11:0] b_imm = 0;
    reg [19:0] j_imm = 0;
    
    always @(*) begin 
        opcode = if_id_instr[6:0];
        funct3 = if_id_instr[14:12];
        funct7 = if_id_instr[31:25];
        rs1 = if_id_instr[19:15];
        rs2 = if_id_instr[24:20];
        rd = if_id_instr[11:7];
        u_imm = if_id_instr[31:12];
        i_imm = if_id_instr[31:20];
        s_imm = {if_id_instr[31:25], if_id_instr[11:7]};
        b_imm = {if_id_instr[31], if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8]};
        j_imm = {if_id_instr[31], if_id_instr[19:12], if_id_instr[20], if_id_instr[30:21]};
    end
    
    // Immediate extension
    wire [31:0] u_imm_ext = {u_imm, 12'b0};
    wire i_imm_zero_ext = ((opcode == 7'b0010011) && (funct3 == 3'b111 || funct3 == 3'b110 || funct3 == 3'b100)) || // ANDI, ORI, XORI
                          ((opcode == 7'b0010011) && (funct3 == 3'b011)); // SLTIU
    wire [31:0] i_imm_ext = i_imm_zero_ext ? {20'b0, i_imm} : {{20{i_imm[11]}}, i_imm};
    wire [31:0] s_imm_ext = {{20{s_imm[11]}}, s_imm};
    wire [31:0] b_imm_ext = {{19{b_imm[11]}}, b_imm, 1'b0};
    wire [31:0] j_imm_ext = {{11{j_imm[19]}}, j_imm, 1'b0};
    
    assign ext_imm = (opcode == 7'b0110111 || opcode == 7'b0010111) ? u_imm_ext : // LUI, AUIPC
                     (opcode == 7'b0000011 || opcode == 7'b0010011 || opcode == 7'b1100111) ? i_imm_ext : // Load, I-type ALU, JALR
                     (opcode == 7'b0100011) ? s_imm_ext : // Store
                     (opcode == 7'b1100011) ? b_imm_ext : // Branch
                     (opcode == 7'b1101111) ? j_imm_ext : // JAL
                     32'b0;

    // Mul-div instructions
    assign md_type = (opcode == 7'b0110011 && funct7 == 7'b0000001);

    // jal target
    assign jal_target = if_id_pc_in + j_imm_ext[11:0];
    
    // Branch target
    assign branch_target = if_id_pc_in + b_imm_ext[11:0];
    
    // ECALL
    assign ecall = (if_id_instr == 32'h00000073);
    
    main_control_unit MCU (
        .opcode(opcode),
        .funct7(funct7),
        .funct3(funct3),
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
        .md_operation(md_operation)
    );
    
    alu_control_unit ACU (
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7(funct7),
        .opcode(opcode),
        .alu_ctrl(alu_ctrl)
    );
endmodule
module pipeline_control_unit (
    input [6:0] opcode,
    input [2:0] funct3,
    input [4:0] rs1, rs2,
    input id_ex_mem_read, 
    input id_ex_jal, id_ex_jalr,
    input [4:0] id_ex_rd,
    input bpu_correct,
    output reg load_use_stall, flush_branch, flush_jal
);
    reg load_use_hazard = 0;

    always @(*) begin
        load_use_stall= 0;
        flush_branch = 0;
        flush_jal = 0;
        load_use_hazard = 0;

        // Load-use hazard detection
        if (id_ex_mem_read && (id_ex_rd != 0)) begin
            case (opcode)
                7'b0110011: begin  // R-type
                    if ((id_ex_rd == rs1) || (id_ex_rd == rs2)) load_use_hazard = 1;
                end
                7'b0010011: begin  // I-type (ALU)
                    if (id_ex_rd == rs1) load_use_hazard = 1;
                end
                7'b0000011: begin  // Load
                    if (id_ex_rd == rs1) load_use_hazard = 1;
                end
                7'b0100011: begin  // Store
                    if ((id_ex_rd == rs1) || (id_ex_rd == rs2)) load_use_hazard = 1;
                end
                7'b1100011: begin  // Branch
                    if ((id_ex_rd == rs1) || (id_ex_rd == rs2)) load_use_hazard = 1;
                end
                7'b1100111: begin  // JALR
                    if (id_ex_rd == rs1) load_use_hazard = 1;
                end
            endcase
        end

        // Flush
        flush_branch = !bpu_correct;
        flush_jal = id_ex_jal || id_ex_jalr;

        // Load use stall
        load_use_stall= load_use_hazard && !flush_branch && !flush_jal;
    end
endmodule
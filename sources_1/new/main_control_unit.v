module main_control_unit (
    input [6:0] opcode, funct7,
    input [2:0] funct3,
    output reg reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, jal, jalr, lui, auipc, mem_unsigned,
    output reg [1:0] alu_op, mem_size,
    // Mul-div signals
    output reg [2:0] md_operation
);
    always @(*) begin 
        reg_write = 0;
        alu_src = 0;
        mem_write = 0;
        mem_read = 0;
        mem_to_reg = 0;
        branch = 0;
        jal = 0;
        jalr = 0;
        lui = 0;
        auipc = 0;
        alu_op = 2'b00;
        mem_size = 2'b00;
        mem_unsigned = 0;
        md_operation = 3'b000;
        
        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1;
                alu_op = 2'b10;
                if (funct7 == 7'b0000001) begin
                    case (funct3)
                        3'b000: md_operation = 3'b000; // MUL
                        3'b001: md_operation = 3'b001; // MULH
                        3'b010: md_operation = 3'b010; // MULHSU
                        3'b011: md_operation = 3'b011; // MULHU
                        3'b100: md_operation = 3'b100; // DIV
                        3'b101: md_operation = 3'b101; // DIVU
                        3'b110: md_operation = 3'b110; // REM
                        3'b111: md_operation = 3'b111; // REMU
                        default: md_operation = 3'b000;
                    endcase
                end
            end
            7'b0010011: begin // I-type (ALU)
                reg_write = 1;
                alu_src = 1;
                alu_op = 2'b10;
            end
            7'b0000011: begin // Load
                alu_src = 1;
                mem_read = 1;
                mem_to_reg = 1;
                reg_write = 1;
                alu_op = 2'b00;
                case (funct3)
                    3'b000: begin // LB
                        mem_size = 2'b10;
                        mem_unsigned = 0;
                    end
                    3'b001: begin // LH
                        mem_size = 2'b01;
                        mem_unsigned = 0;
                    end
                    3'b010: begin // LW
                        mem_size = 2'b00;
                        mem_unsigned = 0;
                    end
                    3'b100: begin // LBU
                        mem_size = 2'b10;
                        mem_unsigned = 1;
                    end
                    3'b101: begin // LHU
                        mem_size = 2'b01;
                        mem_unsigned = 1;
                    end
                    default: begin
                        mem_size = 2'b00;
                        mem_unsigned = 0;
                    end
                endcase
            end
            7'b0100011: begin // Store
                alu_src = 1;
                mem_write = 1;
                alu_op = 2'b00;
                case (funct3)
                    3'b000: mem_size = 2'b10; // SB
                    3'b001: mem_size = 2'b01; // SH
                    3'b010: mem_size = 2'b00; // SW
                    default: mem_size = 2'b00;
                endcase
            end
            7'b1100011: begin // Branch
                branch = 1;
                alu_op = 2'b01;
            end
            7'b0110111: begin // LUI
                lui = 1;
                reg_write = 1;
            end
            7'b0010111: begin // AUIPC
                auipc = 1;
                reg_write = 1;
            end
            7'b1101111: begin // JAL
                jal = 1;
                reg_write = 1;
            end
            7'b1100111: begin // JALR
                jalr = 1;
                reg_write = 1;
                alu_src = 1;
            end
            default: begin

            end
        endcase
    end
endmodule
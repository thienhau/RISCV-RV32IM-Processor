module alu_control_unit (
    input [1:0] alu_op,
    input [2:0] funct3,
    input [6:0] funct7, opcode,
    output reg [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0010; // add (for loads/stores)
            2'b01: alu_ctrl = 4'b0110; // subtract (for branches)
            2'b10: begin // R-type and I-type
                if (opcode == 7'b0010011) begin // I-type
                    case (funct3)
                        3'b000: alu_ctrl = 4'b0010; // ADDI
                        3'b010: alu_ctrl = 4'b0111; // SLTI
                        3'b011: alu_ctrl = 4'b1010; // SLTIU
                        3'b100: alu_ctrl = 4'b0100; // XORI
                        3'b110: alu_ctrl = 4'b0001; // ORI
                        3'b111: alu_ctrl = 4'b0000; // ANDI
                        3'b001: alu_ctrl = 4'b1000; // SLLI
                        3'b101: alu_ctrl = (funct7[5] ? 4'b1011 : 4'b1001); // SRAI/SRLI
                        default: alu_ctrl = 4'b0010;
                    endcase
                end else begin // R-type
                    case (funct3)
                        3'b000: alu_ctrl = (funct7[5] ? 4'b0110 : 4'b0010); // SUB/ADD
                        3'b001: alu_ctrl = 4'b1000; // SLL
                        3'b010: alu_ctrl = 4'b0111; // SLT
                        3'b011: alu_ctrl = 4'b1010; // SLTU
                        3'b100: alu_ctrl = 4'b0100; // XOR
                        3'b101: alu_ctrl = (funct7[5] ? 4'b1011 : 4'b1001); // SRA/SRL
                        3'b110: alu_ctrl = 4'b0001; // OR
                        3'b111: alu_ctrl = 4'b0000; // AND
                        default: alu_ctrl = 4'b0010;
                    endcase
                end
            end
            default: alu_ctrl = 4'b0010;
        endcase
    end
endmodule
module execute (
    input clk, reset,
    input [31:0] alu_in1, alu_in2, id_ex_instr,
    input [3:0] id_ex_alu_ctrl,
    input [2:0] id_ex_funct3,
    input id_ex_branch,
    input id_ex_lui,
    input id_ex_auipc,
    input id_ex_md_type,
    input [2:0] id_ex_md_operation,
    input [11:0] id_ex_pc_in,
    input [31:0] id_ex_ext_imm,
    output reg [31:0] alu_result,
    output reg branch_taken,
    output md_alu_stall
);  
    wire [31:0] mul_result, div_result;
    wire mul_alu_done, div_alu_done, mul_alu_stall, div_alu_stall;

    multiplier MUL (
        .clk(clk),
        .reset(reset),
        .md_type(id_ex_md_type),
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .md_operation(id_ex_md_operation),
        .md_result(mul_result),
        .md_alu_stall(mul_alu_stall),
        .md_alu_done(mul_alu_done)
    );

    divider DIV (
        .clk(clk),
        .reset(reset),
        .md_type(id_ex_md_type),
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .md_operation(id_ex_md_operation),
        .md_result(div_result),
        .md_alu_stall(div_alu_stall),
        .md_alu_done(div_alu_done)
    );

    assign md_alu_stall = mul_alu_stall || div_alu_stall;

    reg [31:0] prev_id_ex_instr = 0;
    reg [31:0] prev_alu_result = 0;
    reg prev_branch_taken = 0;

    always @(*) begin
        branch_taken = 0;
        if (prev_id_ex_instr == id_ex_instr && !id_ex_md_type) begin
            alu_result = prev_alu_result;
            branch_taken = prev_branch_taken;
        end else begin
            if (id_ex_lui) begin 
                alu_result = id_ex_ext_imm;
            end
            else if (id_ex_auipc) begin
                alu_result = {20'b0, id_ex_pc_in} + id_ex_ext_imm;
            end
            else if (id_ex_md_type) begin // MDU
                alu_result = mul_alu_done ? mul_result : div_alu_done ? div_result : 0;
            end
            else begin 
                case (id_ex_alu_ctrl)
                    4'b0000: alu_result = alu_in1 & alu_in2;  // and
                    4'b0001: alu_result = alu_in1 | alu_in2;  // or
                    4'b0010: alu_result = alu_in1 + alu_in2;  // add
                    4'b0110: begin 
                        alu_result = alu_in1 - alu_in2;  // sub
                        if (id_ex_branch) begin
                            case (id_ex_funct3)
                                3'b000: branch_taken = (alu_result == 0);  // beq
                                3'b001: branch_taken = (alu_result != 0);  // bne
                                3'b100: branch_taken = ($signed(alu_in1) < $signed(alu_in2));  // blt
                                3'b101: branch_taken = ($signed(alu_in1) >= $signed(alu_in2));  // bge
                                3'b110: branch_taken = (alu_in1 < alu_in2);  // bltu
                                3'b111: branch_taken = (alu_in1 >= alu_in2);  // bgeu
                                default: branch_taken = 0;
                            endcase
                        end
                    end
                    4'b0100: alu_result = alu_in1 ^ alu_in2;  // xor
                    4'b0111: alu_result = ($signed(alu_in1) < $signed(alu_in2)) ? 1 : 0;  // slt
                    4'b1010: alu_result = (alu_in1 < alu_in2) ? 1 : 0;  // sltu
                    4'b1000: alu_result = alu_in1 << alu_in2[4:0];  // sll
                    4'b1001: alu_result = alu_in1 >> alu_in2[4:0];  // srl
                    4'b1011: alu_result = $signed(alu_in1) >>> alu_in2[4:0];  // sra
                    default: alu_result = alu_in1 + alu_in2;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            prev_id_ex_instr <= 0;
            prev_alu_result <= 0;
            prev_branch_taken <= 0;
        end else begin
            prev_id_ex_instr <= id_ex_instr;
            prev_alu_result <= alu_result;
            prev_branch_taken <= branch_taken;
        end
    end
endmodule
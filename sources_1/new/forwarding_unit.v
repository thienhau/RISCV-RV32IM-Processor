module forwarding_unit (
    input [31:0] id_ex_read_data1, id_ex_read_data2, id_ex_ext_imm,
    input [4:0] id_ex_rs1, id_ex_rs2,
    input ex_mem_reg_write, mem_wb_reg_write, id_ex_alu_src,
    input [4:0] ex_mem_rd, mem_wb_rd,
    input [31:0] ex_mem_alu_result, mem_wb_write_data,
    output [31:0] alu_in1, alu_in2, mem_write_data
);
    reg [1:0] forward_a = 0;
    reg [1:0] forward_b = 0;
    
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;
        
        // EX hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) begin
            forward_a = 2'b10;
        end
        // MEM hazard
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1) && 
                !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))) begin
            forward_a = 2'b01;
        end
        
        // EX hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) begin
            forward_b = 2'b10;
        end
        // MEM hazard
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2) && 
                !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))) begin
            forward_b = 2'b01;
        end
    end
    
    // ALU input
    assign alu_in1 = ((forward_a == 2'b00) ? id_ex_read_data1 :
                         (forward_a == 2'b01) ? mem_wb_write_data :
                         ex_mem_alu_result);
        
    assign alu_in2 = (id_ex_alu_src) ? id_ex_ext_imm : mem_write_data;
                         
    assign mem_write_data = ((forward_b == 2'b00) ? id_ex_read_data2 :
                         (forward_b == 2'b01) ? mem_wb_write_data :
                         ex_mem_alu_result);
endmodule
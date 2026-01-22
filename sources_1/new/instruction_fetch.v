module instruction_fetch (
    input flush_temp,
    input [11:0] ex_mem_branch_target, id_ex_jal_target, pc_in, ex_mem_pc_in,
    input id_ex_jalr, id_ex_jal, btb_hit,
    input [31:0] alu_in1,
    input predict_taken, actual_taken, bpu_correct,
    input [11:0] predict_target,
    output reg [11:0] pc_out, 
    output [11:0] pc_plus_4,
    output [31:0] instr,
    
    // icache interface
    output icache_read_req,
    output [11:0] icache_addr,
    input [31:0] icache_read_data
);
    // PC update
    always @(*) begin
        if (!bpu_correct && actual_taken) begin
            pc_out = ex_mem_branch_target;
        end 
        
        else if (!bpu_correct && !actual_taken) begin
            pc_out = ex_mem_pc_in + 4;
        end 
        
        else if (btb_hit && predict_taken) begin
            pc_out = predict_target;
        end
        
        else if (id_ex_jalr) begin
            pc_out = alu_in1[11:0];    
        end
        
        else if (id_ex_jal) begin
            pc_out = id_ex_jal_target;
        end 
        
        else if (!flush_temp) begin
            pc_out = pc_in + 4;
        end

        else begin
            pc_out = pc_in;
        end
    end
    
    assign icache_read_req = 1'b1;
    assign icache_addr = pc_in;
    assign instr = icache_read_data;
    
    assign pc_plus_4 = pc_in + 4;
endmodule

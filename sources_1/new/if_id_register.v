module if_id_register (
    input clk, reset,
    input icache_stall, dcache_stall, md_alu_stall, load_use_stall, flush, riscv_start, riscv_done,
    input [31:0] instr,
    input [11:0] pc_plus_4, pc_in,
    input predict_taken, btb_hit,
    output reg [31:0] if_id_instr,
    output reg [11:0] if_id_pc_plus_4, if_id_pc_in,
    output reg if_id_predict_taken, if_id_btb_hit
);
    always @(posedge clk) begin
        if (reset) begin
            if_id_pc_in <= 0;
            if_id_instr <= 0;
            if_id_pc_plus_4 <= 0;
            if_id_predict_taken <= 0;
            if_id_btb_hit <= 0;
        end 
        
        else if (riscv_start && !riscv_done) begin            
            if (flush) begin
                if_id_pc_in <= 0;
                if_id_instr <= 0;
                if_id_pc_plus_4 <= 0;
                if_id_predict_taken <= 0;
                if_id_btb_hit <= 0;
            end

            else if (load_use_stall || icache_stall || dcache_stall || md_alu_stall) begin
                
            end 

            else begin
                if_id_pc_in <= pc_in;
                if_id_instr <= instr;
                if_id_pc_plus_4 <= pc_plus_4;
                if_id_predict_taken <= predict_taken;
                if_id_btb_hit <= btb_hit;
            end
        end
    end
endmodule
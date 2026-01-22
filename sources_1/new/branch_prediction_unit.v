module branch_prediction_unit (
    input clk, reset,
    input [11:0] pc_in, ex_mem_pc_in,
    input ex_mem_branch, ex_mem_branch_taken, ex_mem_predict_taken, ex_mem_btb_hit,
    input [11:0] ex_mem_branch_target,
    output bpu_correct, predict_taken, btb_hit, actual_taken,
    output [11:0] predict_target
);
    assign actual_taken = ex_mem_branch && ex_mem_branch_taken;
    assign bpu_correct = (ex_mem_predict_taken == actual_taken);
    wire [1:0] update_btb = ((!ex_mem_btb_hit && ex_mem_branch && actual_taken) || 
                            (ex_mem_btb_hit && ex_mem_branch && !ex_mem_predict_taken && actual_taken)) ? 2'b01 :
                            ((ex_mem_btb_hit && !ex_mem_branch) ? 2'b10 : 2'b00);
    wire update_bht = ex_mem_branch;

    branch_target_buffer BTB (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_in),
        .ex_mem_pc_in(ex_mem_pc_in),
        .update_btb(update_btb), 
        .actual_target(ex_mem_branch_target),
        .predict_target(predict_target),
        .btb_hit(btb_hit)
    );

    branch_history_table BHT (
        .clk(clk), 
        .reset(reset),
        .pc_in(pc_in),
        .ex_mem_pc_in(ex_mem_pc_in),
        .update_bht(update_bht),
        .btb_hit(btb_hit),
        .actual_taken(actual_taken),
        .predict_taken(predict_taken)
    );
endmodule
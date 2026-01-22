module branch_history_table (
    input clk, reset,
    input [11:0] pc_in, ex_mem_pc_in,
    input update_bht,
    input btb_hit,
    input actual_taken,
    output predict_taken
);
    parameter ENTRY = 16;
    parameter INDEX = 4;
    parameter PREDICT = 2;

    wire [3:0] address = ex_mem_pc_in[5:2];
    wire [INDEX-1:0] index = address[3:0];
    
    reg [PREDICT-1:0] predicts [0:ENTRY-1];

    assign predict_taken = !btb_hit ? 1'b0 : (predicts[pc_in[5:2]] == 2'b10 || predicts[pc_in[5:2]] == 2'b11) ? 1'b1 : 1'b0;

    reg [INDEX-1:0] prev_index = 0;
    reg prev_update_bht = 0;
    reg prev_actual_taken = 0;
    
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRY; i = i + 1) begin
                predicts[i] <= 2'b10; // Reset to weakly taken
            end 
        end else if (update_bht) begin
            if (index == prev_index && update_bht == prev_update_bht && actual_taken == prev_actual_taken) begin

            end else begin
                if (actual_taken) begin
                    if (predicts[index] != 2'b11) begin
                        predicts[index] <= predicts[index] + 1;
                    end
                end else if (!actual_taken) begin
                    if (predicts[index] != 2'b00) begin
                        predicts[index] <= predicts[index] - 1;
                    end
                end
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            prev_index <= 0;
            prev_update_bht <= 0;
            prev_actual_taken <= 0;
        end else begin
            prev_index <= index;
            prev_update_bht <= update_bht;
            prev_actual_taken <= actual_taken;
        end
    end
endmodule

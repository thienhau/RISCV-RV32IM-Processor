module branch_target_buffer (
    input clk, reset,
    input [11:0] pc_in, ex_mem_pc_in,
    input [1:0] update_btb,
    input [11:0] actual_target,
    output [11:0] predict_target,
    output btb_hit
);
    parameter ENTRY = 32;
    parameter INDEX = 5;
    parameter TAG = 5;
    parameter TARGET_ADDR = 10;

    wire [9:0] address = ex_mem_pc_in[11:2];
    wire [TAG-1:0] tag = address[9:5];
    wire [INDEX-1:0] index = address[4:0];
    
    reg [TAG-1:0] tags [0:ENTRY-1];
    reg [TARGET_ADDR-1:0] targets [0:ENTRY-1];
    reg valids [0:ENTRY-1];

    assign btb_hit = valids[pc_in[6:2]] && (tags[pc_in[6:2]] == tag);
    assign predict_target = btb_hit ? {targets[pc_in[6:2]], 2'b00} : (pc_in + 4);
    
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < ENTRY; i = i + 1) begin
                valids[i] <= 1'b0;
                tags[i] <= 5'b0;
                targets[i] <= 10'b0;
            end
        end else begin
            if (update_btb == 2'b01) begin // New or update entry
                tags[index] <= tag;
                targets[index] <= actual_target[11:2];
                valids[index] <= 1'b1;
            end else if (update_btb == 2'b10) begin // Clear entry
                tags[index] <= 0;
                targets[index] <= 0;
                valids[index] <= 0;
            end
        end
    end
endmodule
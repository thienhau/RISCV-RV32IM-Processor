module register_file (
    input clk, reset,
    input [4:0] read_reg1, read_reg2,
    input mem_wb_reg_write,
    input [4:0] mem_wb_rd,
    input [31:0] mem_wb_write_data,
    output [31:0] read_data1, read_data2
);
    reg [31:0] regfile [0:31];
    
    assign read_data1 = (read_reg1 == 0) ? 0 : regfile[read_reg1];
    assign read_data2 = (read_reg2 == 0) ? 0 : regfile[read_reg2];
    
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                regfile[i] <= 0;
            end
            // Set sp (x2) address
            regfile[2] <= 4096;
            regfile[0] <= 0;
        end 
        
        else begin
            if (mem_wb_reg_write) begin
                if (mem_wb_rd != 0) begin
                    regfile[mem_wb_rd] <= mem_wb_write_data;
                end
            end
        end
    end
endmodule
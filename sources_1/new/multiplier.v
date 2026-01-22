module multiplier (
    input         clk,
    input         reset,

    input         md_type,          // 1: instruction thuộc M-extension
    input  [31:0] alu_in1,          // rs1
    input  [31:0] alu_in2,          // rs2
    input  [2:0]  md_operation,     // 000: MUL, 001: MULH, 010: MULHSU, 011: MULHU

    output [31:0] md_result,    // kết quả MUL*
    output        md_alu_stall, // 1: đang bận, yêu cầu stall pipeline
    output        md_alu_done   // 1: kết quả valid (1 chu kỳ)
);

    localparam BITS_PER_CYCLE = 2;   // xử lý 4 bit mỗi chu kỳ
    
    // Decode loại MUL* 
    wire mul_inst_w  = md_type & (~md_operation[2]);  // 0xx => MUL group
    wire is_mul      = mul_inst_w && (md_operation == 3'b000);
    wire is_mulh     = mul_inst_w && (md_operation == 3'b001);
    wire is_mulhsu   = mul_inst_w && (md_operation == 3'b010);
    wire is_mulhu    = mul_inst_w && (md_operation == 3'b011);
    
    // State machine
    localparam [1:0] STATE_IDLE = 2'b00;
    localparam [1:0] STATE_BUSY = 2'b01;
    
    reg [1:0] state, state_next;
    
    // Internal registers
    reg [31:0] a_val, a_val_next;        // giá trị A (đã xử lý signed/unsigned)
    reg [31:0] b_val, b_val_next;        // giá trị B (đã xử lý signed/unsigned)
    reg        a_signed_flag, a_signed_flag_next;  // cờ chỉ định A có signed không
    reg        b_signed_flag, b_signed_flag_next;  // cờ chỉ định B có signed không
    reg [2:0]  opcode_reg, opcode_reg_next;        // lưu md_operation
    
    // Datapath cho multiplication
    reg [63:0] multiplicand, multiplicand_next;  // A mở rộng 64-bit
    reg [31:0] multiplier, multiplier_next;      // B (32-bit)
    reg [63:0] product, product_next;            // tích tích lũy
    reg [5:0]  counter, counter_next;            // đếm số bit đã xử lý
    
    // Output registers
    reg [31:0] md_result_reg;
    reg [31:0] md_result_next;
    reg        md_alu_stall_next;
    reg        md_alu_done_next;
    
    // Start condition
    wire start_mul = (state == STATE_IDLE) && mul_inst_w;
    
    // Khai báo các biến tạm
    reg [63:0] prod_temp;
    reg [63:0] mcand_temp;
    reg [31:0] mplier_temp;
    reg [5:0]  count_temp;
    
    // Biến tạm cho signed multiplication
    reg signed [63:0] signed_product;
    reg        result_sign;  // dấu của kết quả
        
    always @* begin
        // Default values
        state_next = state;
        a_val_next = a_val;
        b_val_next = b_val;
        a_signed_flag_next = a_signed_flag;
        b_signed_flag_next = b_signed_flag;
        multiplicand_next = multiplicand;
        multiplier_next = multiplier;
        product_next = product;
        counter_next = counter;
        opcode_reg_next = opcode_reg;
        
        md_result_next = md_result_reg;
        md_alu_stall_next = 1'b0;
        md_alu_done_next = 1'b0;
        
        // Temporary variables với giá trị mặc định
        prod_temp = 64'b0;
        mcand_temp = 64'b0;
        mplier_temp = 32'b0;
        count_temp = 6'b0;
        signed_product = 64'b0;
        result_sign = 1'b0;
        
        case (state)
            // STATE_IDLE: chờ lệnh nhân
            STATE_IDLE: begin
                if (start_mul) begin
                    // Lưu opcode
                    opcode_reg_next = md_operation;
                    
                    // Xác định signed/unsigned cho từng lệnh
                    case (md_operation)
                        3'b000: begin // MUL: cả hai unsigned cho phép nhân, chỉ lấy 32-bit thấp
                            a_val_next = alu_in1;
                            b_val_next = alu_in2;
                            a_signed_flag_next = 1'b0;
                            b_signed_flag_next = 1'b0;
                        end
                        3'b001: begin // MULH: signed × signed
                            a_val_next = alu_in1;
                            b_val_next = alu_in2;
                            a_signed_flag_next = 1'b1;
                            b_signed_flag_next = 1'b1;
                        end
                        3'b010: begin // MULHSU: signed × unsigned
                            a_val_next = alu_in1;
                            b_val_next = alu_in2;
                            a_signed_flag_next = 1'b1;
                            b_signed_flag_next = 1'b0;
                        end
                        3'b011: begin // MULHU: unsigned × unsigned
                            a_val_next = alu_in1;
                            b_val_next = alu_in2;
                            a_signed_flag_next = 1'b0;
                            b_signed_flag_next = 1'b0;
                        end
                        default: begin
                            a_val_next = alu_in1;
                            b_val_next = alu_in2;
                            a_signed_flag_next = 1'b0;
                            b_signed_flag_next = 1'b0;
                        end
                    endcase
                    
                    // Chuyển đổi giá trị sang dạng làm việc (tính trị tuyệt đối nếu cần)
                    // Khởi tạo datapath cho multiplication
                    if (a_signed_flag_next && a_val_next[31]) begin
                        // A signed và âm -> lấy giá trị tuyệt đối
                        multiplicand_next = {32'b0, -a_val_next};  // mở rộng 64-bit
                    end else begin
                        // A unsigned hoặc dương
                        multiplicand_next = {32'b0, a_val_next};  // mở rộng 64-bit
                    end
                    
                    if (b_signed_flag_next && b_val_next[31]) begin
                        // B signed và âm -> lấy giá trị tuyệt đối
                        multiplier_next = -b_val_next;
                    end else begin
                        // B unsigned hoặc dương
                        multiplier_next = b_val_next;
                    end
                    
                    product_next = 64'b0;    // tích ban đầu = 0
                    counter_next = 6'b0;     // reset counter
                    
                    // Stall pipeline
                    md_alu_stall_next = 1'b1;
                    state_next = STATE_BUSY;
                end
            end
            
            // STATE_BUSY: xử lý multiplication
            STATE_BUSY: begin
                md_alu_stall_next = 1'b1;  // vẫn đang tính toán
                
                // Khởi tạo biến tạm từ các giá trị hiện tại
                prod_temp = product;
                mcand_temp = multiplicand;
                mplier_temp = multiplier;
                count_temp = counter;
                
                // Xử lý 4 bit mỗi chu kỳ
                begin : PROCESS_BITS
                    integer i;
                    for (i = 0; i < BITS_PER_CYCLE; i = i + 1) begin
                        if (count_temp < 32) begin
                            // Kiểm tra bit LSB của multiplier
                            if (mplier_temp[0]) begin
                                // Nếu bit = 1, cộng multiplicand vào product
                                prod_temp = prod_temp + mcand_temp;
                            end
                            
                            // Dịch phải multiplier, dịch trái multiplicand
                            mplier_temp = mplier_temp >> 1;
                            mcand_temp = mcand_temp << 1;
                            count_temp = count_temp + 1;
                        end
                    end
                end
                
                // Cập nhật giá trị sau khi xử lý
                product_next = prod_temp;
                multiplier_next = mplier_temp;
                multiplicand_next = mcand_temp;
                counter_next = count_temp;
                
                // Kiểm tra xem đã xử lý xong chưa (32 bit)
                if (count_temp >= 32) begin
                    // Đã xử lý xong 32 bit
                    md_alu_stall_next = 1'b0;  // không còn stall
                    md_alu_done_next = 1'b1;   // báo done
                    state_next = STATE_IDLE;
                    
                    // Xác định dấu của kết quả dựa trên opcode và giá trị gốc
                    result_sign = 1'b0;
                    if (opcode_reg == 3'b001) begin // MULH: signed × signed
                        // Dấu = a_sign XOR b_sign
                        result_sign = (a_val[31] & a_signed_flag) ^ (b_val[31] & b_signed_flag);
                    end else if (opcode_reg == 3'b010) begin // MULHSU: signed × unsigned
                        // Dấu chỉ phụ thuộc vào A (vì B unsigned luôn dương)
                        result_sign = a_val[31] & a_signed_flag;
                    end
                    // MUL và MULHU luôn cho kết quả dương
                    
                    // Điều chỉnh dấu cho kết quả nếu cần
                    if (result_sign) begin
                        // Kết quả âm, lấy bù 2
                        signed_product = -product_next;
                    end else begin
                        // Kết quả dương
                        signed_product = product_next;
                    end
                    
                    // Xuất kết quả theo opcode
                    case (opcode_reg)
                        3'b000: begin // MUL: lấy 32-bit thấp
                            // MUL chỉ cần lấy 32-bit thấp, không quan tâm dấu
                            md_result_next = product_next[31:0];
                        end
                        3'b001: begin // MULH: signed × signed, lấy 32-bit cao
                            md_result_next = signed_product[63:32];
                        end
                        3'b010: begin // MULHSU: signed × unsigned, lấy 32-bit cao
                            md_result_next = signed_product[63:32];
                        end
                        3'b011: begin // MULHU: unsigned × unsigned, lấy 32-bit cao
                            md_result_next = product_next[63:32];
                        end
                        default: begin
                            md_result_next = 32'b0;
                        end
                    endcase
                end
            end
            
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end
    
    always @(posedge clk) begin
        if (reset) begin
            // Reset tất cả registers
            state <= STATE_IDLE;
            
            a_val <= 32'b0;
            b_val <= 32'b0;
            a_signed_flag <= 1'b0;
            b_signed_flag <= 1'b0;
            
            multiplicand <= 64'b0;
            multiplier <= 32'b0;
            product <= 64'b0;
            counter <= 6'b0;
            opcode_reg <= 3'b0;
            md_result_reg <= 32'b0;
        end else begin
            // Update tất cả registers
            state <= state_next;
            
            a_val <= a_val_next;
            b_val <= b_val_next;
            a_signed_flag <= a_signed_flag_next;
            b_signed_flag <= b_signed_flag_next;
            
            multiplicand <= multiplicand_next;
            multiplier <= multiplier_next;
            product <= product_next;
            counter <= counter_next;
            opcode_reg <= opcode_reg_next;
            md_result_reg <= md_result_next;
        end
    end

    assign md_alu_done = md_alu_done_next;
    assign md_alu_stall = md_alu_stall_next;
    assign md_result = md_result_next;

endmodule
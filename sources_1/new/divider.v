module divider (
    input         clk,
    input         reset,
    input         md_type,          // 1: có lệnh M hợp lệ
    input  [31:0] alu_in1,          // dividend (rs1)
    input  [31:0] alu_in2,          // divisor  (rs2)
    input  [2:0]  md_operation,     // 100:DIV, 101:DIVU, 110:REM, 111:REMU

    output [31:0] md_result,
    output        md_alu_stall,
    output        md_alu_done
);

    localparam BITS_PER_CYCLE = 2;

    // Decode
    wire is_div_op = md_operation[2];
    wire is_div    = is_div_op && (md_operation[1:0] == 2'b00); // 100
    wire is_divu   = is_div_op && (md_operation[1:0] == 2'b01); // 101
    wire is_rem    = is_div_op && (md_operation[1:0] == 2'b10); // 110
    wire is_remu   = is_div_op && (md_operation[1:0] == 2'b11); // 111

    wire signed_op = is_div | is_rem;
    wire div_inst  = is_div | is_divu;  // 1: DIV/DIVU, 0: REM/REMU

    // State
    localparam STATE_IDLE = 2'b00;
    localparam STATE_BUSY = 2'b01;

    reg [1:0] state;

    // Internal registers
    reg [31:0] dividend_orig;

    reg [31:0] dividend_abs;
    reg [31:0] divisor_abs;

    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [31:0] mask;          // start từ 0x8000_0000

    reg        invert_res;    // DIV: đảo dấu thương, REM: đảo dấu phần dư
    reg        div_inst_q;    // 1: DIV*, 0: REM*
    
    // Temporary variables for processing (combinational)
    reg [31:0] rem_tmp;
    reg [31:0] quo_tmp;
    reg [31:0] mask_tmp;

    integer step;

    // Output registers
    reg [31:0] md_result_reg;
    
    // Next-state signals for outputs (combinational)
    reg [31:0] md_result_next;
    reg        md_alu_stall_next;
    reg        md_alu_done_next;

    // Start: chỉ nhận lệnh khi IDLE
    wire start_div = (state == STATE_IDLE) && md_type && is_div_op;

    //  SEQUENTIAL PART: cập nhật state + register nội bộ + output
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= STATE_IDLE;

            md_result_reg <= 32'd0;

            dividend_orig <= 32'd0;
            dividend_abs  <= 32'd0;
            divisor_abs   <= 32'd0;

            quotient      <= 32'd0;
            remainder     <= 32'd0;
            mask          <= 32'd0;

            invert_res    <= 1'b0;
            div_inst_q    <= 1'b0;
        end else begin
            // Update md_result_reg
            md_result_reg <= md_result_next;

            case (state)
                // IDLE: Wait for start_div
                STATE_IDLE: begin
                    if (start_div) begin
                        // save values for processing
                        dividend_orig <= alu_in1;

                        // absolute value nếu là phép chia signed
                        if (signed_op) begin
                            dividend_abs <= alu_in1[31] ? -alu_in1 : alu_in1;
                            divisor_abs  <= alu_in2[31] ? -alu_in2 : alu_in2;
                        end else begin
                            dividend_abs <= alu_in1;
                            divisor_abs  <= alu_in2;
                        end

                        // INIT state for division
                        quotient  <= 32'd0;
                        remainder <= 32'd0;
                        mask      <= 32'h8000_0000;

                        // Flag để invert kết quả sau này
                        invert_res <= (is_div && (alu_in1[31] ^ alu_in2[31]) && (alu_in2 != 32'd0))
                                   || (is_rem && alu_in1[31]);
                        
                        div_inst_q  <= div_inst;

                        state       <= STATE_BUSY;
                    end
                end

                // BUSY: mỗi clock xử lý BITS_PER_CYCLE bit
                STATE_BUSY: begin
                    // commit state cho lần lặp tiếp theo
                    remainder <= rem_tmp;
                    quotient  <= quo_tmp;
                    mask      <= mask_tmp;

                    // kết thúc khi mask == 0 (đã xử lý xong 32 bit)
                    if (mask_tmp == 32'd0) begin
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    //  COMBINATIONAL PART: tính *_next + xử lý thuật toán chia
    always @(*) begin
        // Mặc định: giữ nguyên result, clear done,
        // stall = 0 khi không bận
        md_result_next     = md_result_reg;
        md_alu_stall_next  = 1'b0;
        md_alu_done_next   = 1'b0;

        // copy state tạm cho thuật toán
        rem_tmp  = remainder;
        quo_tmp  = quotient;
        mask_tmp = mask;

        case (state)
            // STATE_IDLE
            STATE_IDLE: begin
                if (start_div) begin
                    // bắt đầu chia -> yêu cầu stall từ cycle sau
                    md_alu_stall_next = 1'b1;
                    md_alu_done_next  = 1'b0;
                    // md_result_next giữ nguyên cho tới khi xong
                end
            end
            // STATE_BUSY
            STATE_BUSY: begin
                // Nếu divisor_abs == 0 thì bỏ qua xử lý vòng for
                // (để tránh lặp vô hạn trong mặt ý tưởng, thực tế vẫn chạy
                // nhưng kết quả sẽ được xử lý riêng ở cuối)
                for (step = 0; step < BITS_PER_CYCLE; step = step + 1) begin
                    if (mask_tmp != 32'd0) begin
                        // shift remainder và nạp bit tiếp theo của dividend
                        if (dividend_abs & mask_tmp)
                            rem_tmp = (rem_tmp << 1) | 1'b1;
                        else
                            rem_tmp = (rem_tmp << 1);

                        // so sánh / trừ
                        if (rem_tmp >= divisor_abs && divisor_abs != 32'd0) begin
                            rem_tmp = rem_tmp - divisor_abs;
                            quo_tmp = quo_tmp | mask_tmp;
                        end

                        mask_tmp = mask_tmp >> 1;
                    end
                end

                // đang bận => stall
                md_alu_stall_next = 1'b1;
                md_alu_done_next  = 1'b0;

                // Khi mask_tmp đã về 0 sau vòng for -> kết thúc phép chia
                if (mask_tmp == 32'd0) begin
                    md_alu_stall_next = 1'b0;
                    md_alu_done_next  = 1'b1;

                    if (divisor_abs == 32'd0) begin
                        // divide by 0
                        if (div_inst_q) begin
                            // DIV/DIVU: x/0 -> -1 (RISC-V spec)
                            md_result_next = 32'hFFFF_FFFF;
                        end else begin
                            // REM/REMU: x%0 -> dividend (RISC-V spec)
                            md_result_next = dividend_orig;
                        end
                    end else begin
                        if (div_inst_q) begin
                            // result là quotient
                            md_result_next = invert_res ? -quo_tmp : quo_tmp;
                        end else begin
                            // result là remainder
                            md_result_next = invert_res ? -rem_tmp : rem_tmp;
                        end
                    end
                end
            end
        endcase
    end
    
    // Assign outputs
    assign md_result = md_result_next;
    assign md_alu_stall = md_alu_stall_next;
    assign md_alu_done = md_alu_done_next;

endmodule

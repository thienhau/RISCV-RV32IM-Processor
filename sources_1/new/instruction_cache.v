module instruction_cache (
    input clk, reset,
    input flush,
    input cpu_read_req,
    input [31:0] cpu_addr,
    input [63:0] mem_read_data,
    input mem_read_valid,
    output reg mem_read_req,
    output reg [31:0] mem_addr,
    output reg [31:0] cpu_read_data,
    output reg icache_hit,
    output reg icache_stall
);

    parameter SIZE = 4096;      
    parameter WAY = 4;          // 4 Ways
    parameter BLOCK_WIDTH = 64; 
    parameter SET = 128;        // Giảm số Set xuống 128 để tổng size là 4KB
    parameter INDEX = 7;        // 2^7 = 128
    parameter TAG = 22;         // 32 - 7 - 3 = 22
    parameter WORD_OFFSET = 1;

    // [1:0]: Byte offset
    // [2]: Word offset
    // [9:3]: Index (7 bit)
    // [31:10]: Tag (22 bit)
    wire [TAG-1:0] tag = cpu_addr[31:10];
    wire [INDEX-1:0] index = cpu_addr[9:3];
    wire [WORD_OFFSET-1:0] word_offset = cpu_addr[2];

    // === KHAI BÁO BỘ NHỚ ===
    // PLRU 3 bit cho mỗi set (Tree-PLRU)
    reg [2:0] plru [0:SET-1]; 

    // Way 0
    reg valid0 [0:SET-1];
    reg [TAG-1:0] tag0 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data0 [0:SET-1];
    
    // Way 1
    reg valid1 [0:SET-1];
    reg [TAG-1:0] tag1 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data1 [0:SET-1];

    // Way 2
    reg valid2 [0:SET-1];
    reg [TAG-1:0] tag2 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data2 [0:SET-1];

    // Way 3
    reg valid3 [0:SET-1];
    reg [TAG-1:0] tag3 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data3 [0:SET-1];

    // Các tín hiệu Hit
    wire hit0, hit1, hit2, hit3;
    assign hit0 = valid0[index] && (tag0[index] == tag);
    assign hit1 = valid1[index] && (tag1[index] == tag);
    assign hit2 = valid2[index] && (tag2[index] == tag);
    assign hit3 = valid3[index] && (tag3[index] == tag);
    
    wire any_hit = hit0 | hit1 | hit2 | hit3;

    // State machine
    parameter IDLE = 1'b0, MEM_READ = 1'b1;
    reg state = IDLE;
    reg next_state = IDLE;

    // Cache update control
    reg cache_update_en;
    reg [1:0] replace_way; // 0, 1, 2, or 3

    always @(posedge clk) begin
        if (reset) state <= IDLE;
        else if (flush) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (cpu_read_req && !flush) begin
                    if (any_hit) next_state = IDLE;
                    else next_state = MEM_READ;
                end else begin
                    next_state = IDLE;
                end
            end
            MEM_READ: begin
                if (mem_read_valid || flush) next_state = IDLE;
                else next_state = MEM_READ;
            end
        endcase
    end

    always @(*) begin
        icache_hit = 1'b0;
        icache_stall = 1'b0;
        mem_read_req = 1'b0;
        cpu_read_data = 32'b0;
        mem_addr = 32'b0;
        cache_update_en = 0;
        replace_way = 2'b00;

        if (flush) begin
            icache_stall = 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_read_req) begin
                        if (any_hit) begin
                            icache_hit = 1'b1;
                            icache_stall = 1'b0;
                            // Multiplexer chọn dữ liệu từ 4 Way
                            if (hit0) cpu_read_data = (word_offset == 0) ? data0[index][31:0] : data0[index][63:32];
                            else if (hit1) cpu_read_data = (word_offset == 0) ? data1[index][31:0] : data1[index][63:32];
                            else if (hit2) cpu_read_data = (word_offset == 0) ? data2[index][31:0] : data2[index][63:32];
                            else           cpu_read_data = (word_offset == 0) ? data3[index][31:0] : data3[index][63:32];
                        end else begin
                            // Miss
                            icache_stall = 1'b1;
                            mem_read_req = 1'b1;
                            mem_addr = {tag, index, 3'b000};
                        end
                    end
                end

                MEM_READ: begin
                    icache_stall = 1'b1;
                    mem_read_req = 1'b1;
                    mem_addr = {tag, index, 3'b000};

                    if (mem_read_valid) begin
                        icache_stall = 1'b0;
                        mem_read_req = 1'b0;
                        cache_update_en = 1'b1;
                        cpu_read_data = (word_offset == 0) ? mem_read_data[31:0] : mem_read_data[63:32];

                        // Ưu tiên điền vào chỗ trống trước
                        if (!valid0[index]) replace_way = 2'd0;
                        else if (!valid1[index]) replace_way = 2'd1;
                        else if (!valid2[index]) replace_way = 2'd2;
                        else if (!valid3[index]) replace_way = 2'd3;
                        else begin
                            // Nếu đầy, dùng Tree-PLRU để tìm nạn nhân
                            // plru[2] là root, plru[1] là nhánh trái, plru[0] là nhánh phải
                            // Bit = 0 nghĩa là "nhánh bên kia mới hơn", mình là nạn nhân
                            case (plru[index])
                                // Root trỏ về phải (nhóm trái 0/1 là nạn nhân)
                                3'b000: replace_way = 2'd0; // Nhánh trái trỏ về 1 -> 0 là nạn nhân
                                3'b001: replace_way = 2'd0; 
                                3'b010: replace_way = 2'd1; // Nhánh trái trỏ về 0 -> 1 là nạn nhân
                                3'b011: replace_way = 2'd1;
                                
                                // Root trỏ về trái (nhóm phải 2/3 là nạn nhân)
                                3'b100: replace_way = 2'd2; // Nhánh phải trỏ về 3 -> 2 là nạn nhân
                                3'b101: replace_way = 2'd3; // Nhánh phải trỏ về 2 -> 3 là nạn nhân
                                3'b110: replace_way = 2'd2;
                                3'b111: replace_way = 2'd3;
                            endcase
                        end
                    end
                end
            endcase
        end
    end

    // === CẬP NHẬT DỮ LIỆU TUẦN TỰ ===
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < SET; i = i + 1) begin
                valid0[i] <= 0; valid1[i] <= 0; valid2[i] <= 0; valid3[i] <= 0;
                plru[i] <= 0;
            end
        end else if (!flush) begin
            // 1. Cập nhật PLRU khi Hit
            if (cpu_read_req && state == IDLE && any_hit) begin
                if (hit0) begin
                    plru[index][2] <= 1'b1; // Trỏ sang phải (nhóm 2,3 là nạn nhân tiềm năng)
                    plru[index][1] <= 1'b1; // Trỏ sang Way 1 (Way 1 là nạn nhân trong nhóm trái)
                end
                if (hit1) begin
                    plru[index][2] <= 1'b1; // Trỏ sang phải
                    plru[index][1] <= 1'b0; // Trỏ sang Way 0
                end
                if (hit2) begin
                    plru[index][2] <= 1'b0; // Trỏ sang trái
                    plru[index][0] <= 1'b1; // Trỏ sang Way 3
                end
                if (hit3) begin
                    plru[index][2] <= 1'b0; // Trỏ sang trái
                    plru[index][0] <= 1'b0; // Trỏ sang Way 2
                end
            end 
            
            // 2. Ghi dữ liệu mới và cập nhật PLRU khi Miss (Refill)
            else if (cache_update_en && mem_read_valid) begin
                case (replace_way)
                    2'd0: begin
                        valid0[index] <= 1'b1; tag0[index] <= tag; data0[index] <= mem_read_data;
                        plru[index][2] <= 1'b1; plru[index][1] <= 1'b1;
                    end
                    2'd1: begin
                        valid1[index] <= 1'b1; tag1[index] <= tag; data1[index] <= mem_read_data;
                        plru[index][2] <= 1'b1; plru[index][1] <= 1'b0;
                    end
                    2'd2: begin
                        valid2[index] <= 1'b1; tag2[index] <= tag; data2[index] <= mem_read_data;
                        plru[index][2] <= 1'b0; plru[index][0] <= 1'b1;
                    end
                    2'd3: begin
                        valid3[index] <= 1'b1; tag3[index] <= tag; data3[index] <= mem_read_data;
                        plru[index][2] <= 1'b0; plru[index][0] <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule
module data_cache (
    input clk, reset,
    input cpu_read_req,
    input cpu_write_req,
    input [11:0] cpu_addr,
    input [31:0] mem_read_data,
    input [31:0] cpu_write_data,
    input mem_unsigned,
    input [1:0] mem_size,
    input mem_read_valid,
    input mem_write_back_valid,
    output reg mem_read_req,
    output reg mem_write_req,
    output reg [11:0] mem_addr,
    output reg [31:0] cpu_read_data,
    output reg [31:0] mem_write_data,
    output reg dcache_hit,
    output reg dcache_stall
);
    parameter SIZE = 256*8;
    parameter WAY = 4;
    parameter BLOCK_WIDTH = 32;
    parameter BLOCK = 64;
    parameter SET = 16;
    parameter INDEX = 4;
    parameter BYTE_OFFSET = 2;
    parameter TAG = 6;
    
    wire [11:0] address = cpu_addr;
    wire [TAG-1:0] tag = address[11:6];
    wire [INDEX-1:0] index = address[5:2];
    wire [BYTE_OFFSET-1:0] byte_offset = address[1:0];

    // PLRU for 4-way (3 bits per set)
    reg [2:0] plru [0:SET-1];

    // Cache memory arrays (4 ways)
    reg valid1 [0:SET-1];
    reg dirty1 [0:SET-1];
    reg [TAG-1:0] tag1 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data1 [0:SET-1];

    reg valid2 [0:SET-1];
    reg dirty2 [0:SET-1];
    reg [TAG-1:0] tag2 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data2 [0:SET-1];

    reg valid3 [0:SET-1];
    reg dirty3 [0:SET-1];
    reg [TAG-1:0] tag3 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data3 [0:SET-1];

    reg valid4 [0:SET-1];
    reg dirty4 [0:SET-1];
    reg [TAG-1:0] tag4 [0:SET-1];
    reg [BLOCK_WIDTH-1:0] data4 [0:SET-1];

    // State machine
    parameter IDLE = 2'b00, MEM_READ = 2'b01, MEM_WRITE_BACK = 2'b10;
    reg [1:0] state = IDLE;
    reg [1:0] next_state = IDLE;

    // Cache update control
    reg cache_update_en = 0;

    // Write-back control
    reg write_back_en = 0;
    
    // Replacement way selection
    reg [1:0] replacement_way = 0;

    // Function to handle read data with byte/halfword/word and signed/unsigned
    function [31:0] read_data_with_size;
        input [31:0] data;
        input [1:0] size;
        input [1:0] offset;
        input unsigned_flag;
        reg [31:0] result;
        begin
            case (size)
                2'b00: begin // Word
                    result = data;
                end
                2'b01: begin // Half-word
                    if (offset[1] == 0) begin
                        result = unsigned_flag ? {16'b0, data[15:0]} : {{16{data[15]}}, data[15:0]};
                    end else begin
                        result = unsigned_flag ? {16'b0, data[31:16]} : {{16{data[31]}}, data[31:16]};
                    end
                end
                2'b10: begin // Byte
                    case (offset)
                        2'b00: result = unsigned_flag ? {24'b0, data[7:0]} : {{24{data[7]}}, data[7:0]};
                        2'b01: result = unsigned_flag ? {24'b0, data[15:8]} : {{24{data[15]}}, data[15:8]};
                        2'b10: result = unsigned_flag ? {24'b0, data[23:16]} : {{24{data[23]}}, data[23:16]};
                        2'b11: result = unsigned_flag ? {24'b0, data[31:24]} : {{24{data[31]}}, data[31:24]};
                    endcase
                end
                default: result = data;
            endcase
            read_data_with_size = result;
        end
    endfunction

    // Function to handle write data with byte/halfword/word
    function [31:0] write_data_with_size;
        input [31:0] original_data;
        input [31:0] write_data;
        input [1:0] size;
        input [1:0] offset;
        reg [31:0] result;
        begin
            result = original_data;
            case (size)
                2'b00: begin // Word
                    result = write_data;
                end
                2'b01: begin // Half-word
                    if (offset[1] == 0) begin
                        result[15:0] = write_data[15:0];
                    end else begin
                        result[31:16] = write_data[15:0];
                    end
                end
                2'b10: begin // Byte
                    case (offset)
                        2'b00: result[7:0] = write_data[7:0];
                        2'b01: result[15:8] = write_data[7:0];
                        2'b10: result[23:16] = write_data[7:0];
                        2'b11: result[31:24] = write_data[7:0];
                    endcase
                end
                // default: keep original data
            endcase
            write_data_with_size = result;
        end
    endfunction

    // Function to select replacement way using PLRU
    function [1:0] select_replacement_way;
        input [2:0] plru_bits;
        begin
            if (plru_bits[2] == 1'b0) begin 
                if (plru_bits[1] == 1'b0)
                    select_replacement_way = 2'b00; // Way 0 (Way 1) là valid1
                else
                    select_replacement_way = 2'b01; // Way 1 (Way 2) là valid2
            end else begin
                // Root trỏ sang Phải -> Tìm trong nhóm Phải 
                if (plru_bits[0] == 1'b0)
                    select_replacement_way = 2'b10; // Way 2 (Way 3) là valid3
                else
                    select_replacement_way = 2'b11; // Way 3 (Way 4) là valid4
            end
        end
    endfunction

    // Function to update PLRU bits
    function [2:0] update_plru;
        input [2:0] old_plru;
        input [1:0] accessed_way;
        begin
            case (accessed_way)
                2'b00: begin 
                    // Truy cập Way 0 (Trái, Trái)
                    // -> Root trỏ sang Phải (1), Nút Trái trỏ sang Way 1 (1)
                    // -> Nút Phải giữ nguyên (old_plru[0])
                    update_plru = {1'b1, 1'b1, old_plru[0]}; 
                end
                2'b01: begin 
                    // Truy cập Way 1 (Trái, Phải)
                    // -> Root trỏ sang Phải (1), Nút Trái trỏ sang Way 0 (0)
                    // -> Nút Phải giữ nguyên (old_plru[0])
                    update_plru = {1'b1, 1'b0, old_plru[0]};
                end
                2'b10: begin 
                    // Truy cập Way 2 (Phải, Trái)
                    // -> Root trỏ sang Trái (0), Nút Phải trỏ sang Way 3 (1)
                    // -> Nút Trái giữ nguyên (old_plru[1])
                    update_plru = {1'b0, old_plru[1], 1'b1};
                end
                2'b11: begin 
                    // Truy cập Way 3 (Phải, Phải)
                    // -> Root trỏ sang Trái (0), Nút Phải trỏ sang Way 2 (0)
                    // -> Nút Trái giữ nguyên (old_plru[1])
                    update_plru = {1'b0, old_plru[1], 1'b0};
                end
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (cpu_read_req) begin
                    // Read operation
                    if (dcache_hit) begin
                        next_state = IDLE;  // Hit
                    end else begin
                        // Miss - check if we need write-back
                        if ((replacement_way == 2'b00 && valid1[index] && dirty1[index]) ||
                           (replacement_way == 2'b01 && valid2[index] && dirty2[index]) ||
                           (replacement_way == 2'b10 && valid3[index] && dirty3[index]) ||
                           (replacement_way == 2'b11 && valid4[index] && dirty4[index])) begin
                            next_state = MEM_WRITE_BACK;
                        end else begin
                            next_state = MEM_READ;
                        end
                    end
                end else if (cpu_write_req) begin
                    // Write operation
                    if (dcache_hit) begin
                        next_state = IDLE;  // Hit
                    end else begin
                        // Write miss - check if we need write-back
                        if ((replacement_way == 2'b00 && valid1[index] && dirty1[index]) ||
                           (replacement_way == 2'b01 && valid2[index] && dirty2[index]) ||
                           (replacement_way == 2'b10 && valid3[index] && dirty3[index]) ||
                           (replacement_way == 2'b11 && valid4[index] && dirty4[index])) begin
                            next_state = MEM_WRITE_BACK;
                        end else begin
                            next_state = IDLE;  // Write miss without write-back
                        end
                    end
                end
            end
            
            MEM_READ: begin
                if (mem_read_valid) begin
                    next_state = IDLE;
                end
            end
            
            MEM_WRITE_BACK: begin
                if (mem_write_back_valid) begin
                    if (cpu_read_req) begin
                        next_state = MEM_READ;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
        endcase
    end

    always @(*) begin
        dcache_hit = 1'b0;
        dcache_stall = 1'b0;
        mem_read_req = 1'b0;
        mem_write_req = 1'b0;
        cpu_read_data = 32'b0;
        mem_write_data = 32'b0;
        mem_addr = 12'b0;
        cache_update_en = 0;
        write_back_en = 0;

        // Determine replacement way
        if (!valid1[index] || !valid2[index] || !valid3[index] || !valid4[index]) begin
            // At least one way is invalid, use it first
            if (!valid1[index]) begin
                replacement_way = 2'b00;
            end else if (!valid2[index]) begin
                replacement_way = 2'b01;
            end else if (!valid3[index]) begin
                replacement_way = 2'b10;
            end else begin
                replacement_way = 2'b11;
            end
        end else begin
            // All ways valid, use PLRU for replacement
            replacement_way = select_replacement_way(plru[index]);
        end

        case (state)
            IDLE: begin
                if (cpu_read_req) begin
                    // Check cache hit for read
                    if (valid1[index] && tag1[index] == tag) begin
                        dcache_hit = 1'b1;
                        cpu_read_data = read_data_with_size(data1[index], mem_size, byte_offset, mem_unsigned);
                        dcache_stall = 1'b0;
                    end else if (valid2[index] && tag2[index] == tag) begin
                        dcache_hit = 1'b1;
                        cpu_read_data = read_data_with_size(data2[index], mem_size, byte_offset, mem_unsigned);
                        dcache_stall = 1'b0;
                    end else if (valid3[index] && tag3[index] == tag) begin
                        dcache_hit = 1'b1;
                        cpu_read_data = read_data_with_size(data3[index], mem_size, byte_offset, mem_unsigned);
                        dcache_stall = 1'b0;
                    end else if (valid4[index] && tag4[index] == tag) begin
                        dcache_hit = 1'b1;
                        cpu_read_data = read_data_with_size(data4[index], mem_size, byte_offset, mem_unsigned);
                        dcache_stall = 1'b0;
                    end else begin
                        // Read miss
                        dcache_hit = 1'b0;
                        dcache_stall = 1'b1;
                    end
                end else if (cpu_write_req) begin
                    // Check cache hit for write
                    if (valid1[index] && tag1[index] == tag) begin
                        dcache_hit = 1'b1;
                        dcache_stall = 1'b0;
                    end else if (valid2[index] && tag2[index] == tag) begin
                        dcache_hit = 1'b1;
                        dcache_stall = 1'b0;
                    end else if (valid3[index] && tag3[index] == tag) begin
                        dcache_hit = 1'b1;
                        dcache_stall = 1'b0;
                    end else if (valid4[index] && tag4[index] == tag) begin
                        dcache_hit = 1'b1;
                        dcache_stall = 1'b0;
                    end else begin
                        // Write miss - check if we can write immediately
                        if (!((replacement_way == 2'b00 && valid1[index] && dirty1[index]) ||
                             (replacement_way == 2'b01 && valid2[index] && dirty2[index]) ||
                             (replacement_way == 2'b10 && valid3[index] && dirty3[index]) ||
                             (replacement_way == 2'b11 && valid4[index] && dirty4[index]))) begin
                            // Write miss without write-back - can write immediately
                            dcache_hit = 1'b0;
                            dcache_stall = 1'b0;
                        end else begin
                            // Write miss with write-back - need to stall
                            dcache_hit = 1'b0;
                            dcache_stall = 1'b1;
                        end
                    end
                end
            end
            
            MEM_READ: begin
                dcache_stall = 1'b1;
                mem_read_req = 1'b1;
                mem_addr = {cpu_addr[11:2], 2'b00};
                
                if (mem_read_valid) begin
                    dcache_stall = 1'b0;
                    mem_read_req = 1'b0;
                    cache_update_en = 1'b1;
                    cpu_read_data = read_data_with_size(mem_read_data, mem_size, byte_offset, mem_unsigned);
                end
            end
            
            MEM_WRITE_BACK: begin
                dcache_stall = 1'b1;
                mem_write_req = 1'b1;

                case (replacement_way)
                    2'b00: begin
                        mem_addr = {tag1[index], index, 2'b00};
                        mem_write_data = data1[index];
                    end
                    2'b01: begin
                        mem_addr = {tag2[index], index, 2'b00};
                        mem_write_data = data2[index];
                    end
                    2'b10: begin
                        mem_addr = {tag3[index], index, 2'b00};
                        mem_write_data = data3[index];
                    end
                    2'b11: begin
                        mem_addr = {tag4[index], index, 2'b00};
                        mem_write_data = data4[index];
                    end
                endcase

                if (mem_write_back_valid) begin
                    mem_write_req = 1'b0;
                    write_back_en = 1'b1;
                    dcache_stall = !cpu_write_data;
                end
            end
        endcase
    end

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < SET; i = i + 1) begin
                valid1[i] <= 0; dirty1[i] <= 0; tag1[i] <= 0; data1[i] <= 0;
                valid2[i] <= 0; dirty2[i] <= 0; tag2[i] <= 0; data2[i] <= 0;
                valid3[i] <= 0; dirty3[i] <= 0; tag3[i] <= 0; data3[i] <= 0;
                valid4[i] <= 0; dirty4[i] <= 0; tag4[i] <= 0; data4[i] <= 0;
                plru[i] <= 3'b000;
            end 
        end else begin
            // PLRU update on read hit
            if (cpu_read_req && state == IDLE) begin
                if (valid1[index] && tag1[index] == tag) begin
                    plru[index] <= update_plru(plru[index], 2'b00);
                end else if (valid2[index] && tag2[index] == tag) begin
                    plru[index] <= update_plru(plru[index], 2'b01);
                end else if (valid3[index] && tag3[index] == tag) begin
                    plru[index] <= update_plru(plru[index], 2'b10);
                end else if (valid4[index] && tag4[index] == tag) begin
                    plru[index] <= update_plru(plru[index], 2'b11);
                end
            end else if (cache_update_en && mem_read_valid) begin
                // Cache update on read miss
                case (replacement_way)
                    2'b00: begin
                        valid1[index] <= 1'b1;
                        tag1[index] <= tag;
                        data1[index] <= mem_read_data;
                        dirty1[index] <= 1'b0;
                        plru[index] <= update_plru(plru[index], 2'b00);
                    end
                    2'b01: begin
                        valid2[index] <= 1'b1;
                        tag2[index] <= tag;
                        data2[index] <= mem_read_data;
                        dirty2[index] <= 1'b0;
                        plru[index] <= update_plru(plru[index], 2'b01);
                    end
                    2'b10: begin
                        valid3[index] <= 1'b1;
                        tag3[index] <= tag;
                        data3[index] <= mem_read_data;
                        dirty3[index] <= 1'b0;
                        plru[index] <= update_plru(plru[index], 2'b10);
                    end
                    2'b11: begin
                        valid4[index] <= 1'b1;
                        tag4[index] <= tag;
                        data4[index] <= mem_read_data;
                        dirty4[index] <= 1'b0;
                        plru[index] <= update_plru(plru[index], 2'b11);
                    end
                endcase
            end

            // Write operations - both hits and misses without write-back
            if (cpu_write_req && state == IDLE) begin
                if (dcache_hit && !dcache_stall) begin
                    // Write hit
                    if (valid1[index] && tag1[index] == tag) begin
                        data1[index] <= write_data_with_size(data1[index], cpu_write_data, mem_size, byte_offset);
                        dirty1[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b00);
                    end else if (valid2[index] && tag2[index] == tag) begin
                        data2[index] <= write_data_with_size(data2[index], cpu_write_data, mem_size, byte_offset);
                        dirty2[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b01); // Đã sửa: Way 2
                    end else if (valid3[index] && tag3[index] == tag) begin
                        data3[index] <= write_data_with_size(data3[index], cpu_write_data, mem_size, byte_offset);
                        dirty3[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b10); // Đã sửa: Way 3
                    end else if (valid4[index] && tag4[index] == tag) begin
                        data4[index] <= write_data_with_size(data4[index], cpu_write_data, mem_size, byte_offset);
                        dirty4[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b11); // Đã sửa: Way 4
                    end
                end else if (!dcache_hit && !dcache_stall) begin
                    // Write miss without write-back - allocate and write immediately
                    case (replacement_way)
                        2'b00: begin
                            valid1[index] <= 1'b1;
                            tag1[index] <= tag;
                            data1[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                            dirty1[index] <= 1'b1;
                            plru[index] <= update_plru(plru[index], 2'b00);
                        end
                        2'b01: begin
                            valid2[index] <= 1'b1;
                            tag2[index] <= tag;
                            data2[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                            dirty2[index] <= 1'b1;
                            plru[index] <= update_plru(plru[index], 2'b01);
                        end
                        2'b10: begin
                            valid3[index] <= 1'b1;
                            tag3[index] <= tag;
                            data3[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                            dirty3[index] <= 1'b1;
                            plru[index] <= update_plru(plru[index], 2'b10);
                        end
                        2'b11: begin
                            valid4[index] <= 1'b1;
                            tag4[index] <= tag;
                            data4[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                            dirty4[index] <= 1'b1;
                            plru[index] <= update_plru(plru[index], 2'b11);
                        end
                    endcase
                end
            end else if (!dcache_stall && state == MEM_WRITE_BACK) begin
                // Write miss with write-back
                case (replacement_way)
                    2'b00: begin
                        valid1[index] <= 1'b1;
                        tag1[index] <= tag;
                        data1[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                        dirty1[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b00);
                    end
                    2'b01: begin
                        valid2[index] <= 1'b1;
                        tag2[index] <= tag;
                        data2[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                        dirty2[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b01);
                    end
                    2'b10: begin
                        valid3[index] <= 1'b1;
                        tag3[index] <= tag;
                        data3[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                        dirty3[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b10);
                    end
                    2'b11: begin
                        valid4[index] <= 1'b1;
                        tag4[index] <= tag;
                        data4[index] <= write_data_with_size(32'b0, cpu_write_data, mem_size, byte_offset);
                        dirty4[index] <= 1'b1;
                        plru[index] <= update_plru(plru[index], 2'b11);
                    end
                endcase    
            end

            // Clear dirty bit after write-back
            if (write_back_en && mem_write_back_valid) begin
                case (replacement_way)
                    2'b00: dirty1[index] <= 1'b0;
                    2'b01: dirty2[index] <= 1'b0;
                    2'b10: dirty3[index] <= 1'b0;
                    2'b11: dirty4[index] <= 1'b0;
                endcase
            end
        end
    end
endmodule
`timescale 1ns / 1ps

module riscv_pipeline_tb;

    //==========================================================================
    // Signal Declarations
    //==========================================================================
    reg clk;
    reg reset;
    reg riscv_start;
    wire riscv_done;
    wire led;
    wire led_riscv_start;
    
    // Test status signals
    integer test_count;
    integer pass_count;
    integer fail_count;
    integer total_tests;
    integer passed_tests;
    integer failed_tests;
    
    // Clock Generation
    parameter CLK_PERIOD = 10; // 100MHz
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT Instantiation
    top DUT (
        .clk(clk),
        .reset(reset),
        .riscv_start(riscv_start),
        .riscv_done(riscv_done),
        .led(led),
        .led_riscv_start(led_riscv_start)
    );
    
    // Test Management Tasks
    
    // Task: Initialize test environment
    task initialize_test;
        begin
            $display("\n");
            $display("================================================================================");
            $display("  RISC-V Pipeline Professional Testbench");
            $display("  Date: %0t", $time);
            $display("================================================================================");
            test_count = 0;
            pass_count = 0;
            fail_count = 0;
            total_tests = 0;
            passed_tests = 0;
            failed_tests = 0;
            clk = 0;
            reset = 1;
            riscv_start = 0;
        end
    endtask
    
    // Task: System reset
    task system_reset;
        input integer reset_cycles;
        begin
            $display("[%0t] Applying system reset for %0d cycles...", $time, reset_cycles);
            reset = 1;
            riscv_start = 0;
            repeat(reset_cycles) @(posedge clk);
            reset = 0;
            $display("[%0t] System reset completed", $time);
        end
    endtask
    
    // Task: Start RISC-V execution
    task start_riscv;
        begin
            $display("[%0t] Starting RISC-V processor...", $time);
            @(posedge clk);
            riscv_start = 1;
            @(posedge clk);
            // Keep riscv_start HIGH during execution
            // riscv_start = 0;
            $display("[%0t] Processor started (riscv_start=%b, riscv_done=%b)", 
                     $time, riscv_start, riscv_done);
        end
    endtask
    
    // Task: Wait for completion
    task wait_for_completion;
        input integer timeout_cycles;
        integer cycle_count;
        integer last_ecall_count;
        begin
            cycle_count = 0;
            last_ecall_count = 0;
            $display("[%0t] Waiting for processor completion (timeout: %0d cycles)...", 
                     $time, timeout_cycles);
            
            while (!riscv_done && cycle_count < timeout_cycles) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
                
                // Debug: Show PC progress every 500 cycles
                if (cycle_count % 500 == 0) begin
                    $display("  [Cycle %0d] PC=0x%03h, a0=%0d, a1=%0d, sp=0x%03h", 
                             cycle_count, DUT.RISCV.pc_in, 
                             DUT.RISCV.RF.regfile[10],
                             DUT.RISCV.RF.regfile[11],
                             DUT.RISCV.RF.regfile[2]);
                end
                
                // Check if we're at ECALL instruction
                if (DUT.RISCV.pc_in == 12'h01C && DUT.RISCV.instr == 32'h00000073) begin
                    if (last_ecall_count == 0) begin
                        $display("  [Cycle %0d] Reached ECALL at PC=0x01C!", cycle_count);
                        last_ecall_count = cycle_count;
                    end
                end
            end
            
            if (riscv_done) begin
                $display("[%0t] Processor completed execution in %0d cycles", 
                         $time, cycle_count);
                riscv_start = 0; // Turn off start signal
            end else begin
                $display("[%0t] WARNING: Timeout after %0d cycles", $time, cycle_count);
                $display("  Final PC=0x%03h, Instruction=0x%08h", 
                         DUT.RISCV.pc_in, DUT.RISCV.instr);
                if (last_ecall_count > 0) begin
                    $display("  NOTE: ECALL was reached at cycle %0d", last_ecall_count);
                end else begin
                    $display("  WARNING: ECALL was never reached!");
                end
                riscv_start = 0; // Turn off start signal
            end
        end
    endtask
    
    // Task: Check test result
    task check_result;
        input [31:0] expected_value;
        input [255:0] test_name;
        reg [31:0] actual_value;
        begin
            test_count = test_count + 1;
            actual_value = DUT.result;
            
            $display("\n--------------------------------------------------------------------------------");
            $display("Test #%0d: %0s", test_count, test_name);
            $display("  Expected: 0x%08h (%0d)", expected_value, expected_value);
            $display("  Actual  : 0x%08h (%0d)", actual_value, actual_value);
            
            if (actual_value === expected_value) begin
                $display("  Status  : PASS ");
                pass_count = pass_count + 1;
            end else begin
                $display("  Status  : FAIL");
                fail_count = fail_count + 1;
            end
            $display("--------------------------------------------------------------------------------");
        end
    endtask
    
    // Task: Display register file state
    task display_registers;
        input [4:0] start_reg;
        input [4:0] end_reg;
        integer i;
        begin
            $display("\n[%0t] Register File State (x%0d to x%0d):", 
                     $time, start_reg, end_reg);
            $display("  +------+------------------+");
            $display("  | Reg  |      Value       |");
            $display("  +------+------------------+");
            for (i = start_reg; i <= end_reg; i = i + 1) begin
                $display("  | x%-2d  | 0x%08h (%0d) |", 
                         i, DUT.RISCV.RF.regfile[i], 
                         DUT.RISCV.RF.regfile[i]);
            end
            $display("  +------+------------------+");
        end
    endtask
    
    // Task: Display memory contents
    task display_memory;
        input [11:0] start_addr;
        input [11:0] end_addr;
        integer i;
        begin
            $display("\n[%0t] Data Memory Contents (0x%03h to 0x%03h):", 
                     $time, start_addr, end_addr);
            $display("  +--------+------------------+");
            $display("  | Addr   |      Value       |");
            $display("  +--------+------------------+");
            for (i = start_addr; i <= end_addr; i = i + 4) begin
                $display("  | 0x%03h | 0x%08h (%0d) |", 
                         i, DUT.DM.dmem[i/4], DUT.DM.dmem[i/4]);
            end
            $display("  +--------+------------------+");
        end
    endtask
    
    // Task: Load instruction memory
    task load_instructions; 
        input [255:0] filename;
        begin
            $display("[%0t] Loading instructions from: %0s", $time, filename);
            $readmemh(filename, DUT.IM.imem);
            $display("[%0t] Instructions loaded successfully", $time);
        end
    endtask
    
    // Task: Load data memory
    task load_data_memory;
        input [255:0] filename;
        begin
            $display("[%0t] Loading data memory from: %0s", $time, filename);
            $readmemh(filename, DUT.DM.dmem);
            $display("[%0t] Data memory loaded successfully", $time);
        end
    endtask
    
    // Task: Monitor pipeline stages
    task monitor_pipeline;
        input integer num_cycles;
        integer i;
        begin
            $display("\n[%0t] Monitoring pipeline for %0d cycles...", $time, num_cycles);
            $display("  Cycle | PC    | IF/ID | ID/EX | EX/MEM | MEM/WB | Stall | Flush");
            $display("  ------|-------|-------|-------|--------|--------|-------|-------");
            
            for (i = 0; i < num_cycles; i = i + 1) begin
                @(posedge clk);
                $display("  %4d  | %04h  | %04h  | %04h  | %04h   | %04h   |  %b    |  %b",
                         i,
                         DUT.RISCV.pc_in[11:0],
                         DUT.RISCV.IF_ID.if_id_pc_in[11:0],
                         DUT.RISCV.ID_EX.id_ex_pc_in[11:0],
                         DUT.RISCV.EX_MEM.ex_mem_pc_in[11:0],
                         DUT.RISCV.MEM_WB.mem_wb_pc_plus_4[11:0],
                         DUT.RISCV.load_use_stall,
                         DUT.RISCV.flush_branch || DUT.RISCV.flush_jal);
            end
            $display("");
        end
    endtask
    
    // Task: Display final statistics
    task display_statistics;
        begin
            $display("\n");
            $display("================================================================================");
            $display("  Test Summary");
            $display("================================================================================");
            $display("  Total Tests : %0d", test_count);
            $display("  Passed      : %0d", pass_count);
            $display("  Failed      : %0d", fail_count);
            $display("  Pass Rate   : %0d%%", (pass_count * 100) / test_count);
            $display("================================================================================");
            
            if (fail_count == 0) begin
                $display("  ALL TESTS PASSED! ");
            end else begin
                $display("  SOME TESTS FAILED!");
            end
            $display("================================================================================\n");
        end
    endtask
    
    //==========================================================================
    // Test Scenarios
    //==========================================================================
    // Test Scrnario 0: All integer instructions
    // Task: Test all instructions (Scenario 0)
    task test_all_instructions;
        integer i;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 0: Comprehensive Instruction Set Test");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading instruction memory with R, I, S, L, B, J, U, and M-extension...", $time);
            
            // ========== R-type ALU Instructions ==========
            DUT.IM.imem[0] = 32'h00600193;  // addi x3, x0, 6   # x3 = 6
            DUT.IM.imem[1] = 32'h00500213;  // addi x4, x0, 5   # x4 = 5
            DUT.IM.imem[2] = 32'h00400293;  // addi x5, x0, 4   # x5 = 4
            
            DUT.IM.imem[3] = 32'h00418333;  // add x6, x3, x4   # x6 = 6 + 5 = 11
            DUT.IM.imem[4] = 32'h404183b3;  // sub x7, x3, x4   # x7 = 6 - 5 = 1
            DUT.IM.imem[5] = 32'h00419433;  // sll x8, x3, x4   # x8 = 6 << 5 = 192
            DUT.IM.imem[6] = 32'h005454b3;  // srl x9, x8, x5   # x9 = 192 >> 4 = 12
            DUT.IM.imem[7] = 32'h40545533;  // sra x10, x8, x5  # x10 = 192 >> 4 = 12
            DUT.IM.imem[8] = 32'h0041e5b3;  // or x11, x3, x4   # x11 = 6 | 5 = 7
            DUT.IM.imem[9] = 32'h0041c633;  // xor x12, x3, x4  # x12 = 6 ^ 5 = 3
            DUT.IM.imem[10] = 32'h0041f6b3; // and x13, x3, x4  # x13 = 6 & 5 = 4
            DUT.IM.imem[11] = 32'h0041a733; // slt x14, x3, x4  # x14 = (6 < 5) ? 0
            DUT.IM.imem[12] = 32'h0041b7b3; // sltu x15, x3, x4 # x15 = 0
            
            // ========== I-type ALU Instructions ==========
            DUT.IM.imem[13] = 32'h00600813; // addi x16, x0, 6
            DUT.IM.imem[14] = 32'h00400893; // addi x17, x0, 4
            DUT.IM.imem[15] = 32'h00284913; // xori x18, x16, 2  # 6 ^ 2 = 4
            DUT.IM.imem[16] = 32'h00185993; // srli x19, x16, 1  # 6 >> 1 = 3
            DUT.IM.imem[17] = 32'h40285a13; // srai x20, x16, 2  # 6 >>> 2 = 1
            DUT.IM.imem[18] = 32'h00486b13; // ori x22, x16, 4   # 6 | 4 = 6
            DUT.IM.imem[19] = 32'h00487b93; // andi x23, x16, 4  # 6 & 4 = 4
            DUT.IM.imem[20] = 32'h00482413; // slti x8, x16, 4   # 6 < 4 = 0
            DUT.IM.imem[21] = 32'h00483493; // sltiu x9, x16, 4  # 6 < 4 = 0
            
            // ========== Load/Store Instructions ==========
            DUT.IM.imem[22] = 32'h00000193; // addi x3, x0, 0
            DUT.IM.imem[23] = 32'h00602023; // sw x6, 0(x0)      # mem[0] = 11
            DUT.IM.imem[24] = 32'h00701223; // sh x7, 4(x0)      # mem[4] = 1 (half)
            DUT.IM.imem[25] = 32'h007001a3; // sb x7, 3(x0)      # mem[3] = 1 (byte)
            
            DUT.IM.imem[26] = 32'h00002303; // lw x6, 0(x0)      # x6 = 11
            DUT.IM.imem[27] = 32'h00401383; // lh x7, 4(x0)
            DUT.IM.imem[28] = 32'h00301403; // lb x8, 3(x0)
            DUT.IM.imem[29] = 32'h00405383; // lhu x7, 4(x0)
            DUT.IM.imem[30] = 32'h00304403; // lbu x8, 3(x0)
            
            // ========== Branch Instructions ==========
            DUT.IM.imem[31] = 32'h00600193; // addi x3, x0, 6
            DUT.IM.imem[32] = 32'h00600213; // addi x4, x0, 6
            DUT.IM.imem[33] = 32'h00500293; // addi x5, x0, 5
            
            DUT.IM.imem[34] = 32'h00320463; // beq x4, x3, +8    # Jump to 36
            DUT.IM.imem[35] = 32'h00100313; // addi x6, x0, 1 (skip)
            DUT.IM.imem[36] = 32'h00200393; // addi x7, x0, 2 (target)
            
            DUT.IM.imem[37] = 32'h00321463; // bne x4, x3, +8 (no jump)
            DUT.IM.imem[38] = 32'h00300413; // addi x8, x0, 3
            DUT.IM.imem[39] = 32'h00400493; // addi x9, x0, 4
            
            DUT.IM.imem[40] = 32'h0032c463; // blt x5, x3, +8 (jump to 42)
            DUT.IM.imem[41] = 32'h00500513; // addi x10, x0, 5 (skip)
            DUT.IM.imem[42] = 32'h00600593; // addi x11, x0, 6 (target)
            
            // ========== Jump Instructions ==========
            DUT.IM.imem[43] = 32'h008000ef; // jal x1, +8 (jump to 45)
            DUT.IM.imem[44] = 32'h00c00113; // addi x2, x0, 12 (skip)
            DUT.IM.imem[45] = 32'h01000193; // addi x3, x0, 16 (target)
            
            // ========== U-type Instructions ==========
            DUT.IM.imem[48] = 32'h123450b7; // lui x1, 0x12345
            DUT.IM.imem[49] = 32'h00008093; // addi x1, x1, 0
            DUT.IM.imem[50] = 32'h12345117; // auipc x2, 0x12345
            
            // ========== Multiplication/Division ==========
            DUT.IM.imem[51] = 32'h00019193; // addi x3, x0, 100 (Sửa lại giá trị nhỏ để dễ debug)
            DUT.IM.imem[52] = 32'h00032213; // addi x4, x0, 50
            
            DUT.IM.imem[53] = 32'h023202b3; // mul x5, x4, x3     # 50 * 100 = 5000
            DUT.IM.imem[54] = 32'h02321333; // mulh x6, x4, x3
            DUT.IM.imem[55] = 32'h023223b3; // mulhsu x7, x4, x3
            DUT.IM.imem[56] = 32'h02323633; // mulhu x12, x4, x3
            
            DUT.IM.imem[57] = 32'h02324433; // div x8, x4, x3     # 50 / 100 = 0
            DUT.IM.imem[58] = 32'h023254b3; // divu x9, x4, x3
            DUT.IM.imem[59] = 32'h02326533; // rem x10, x4, x3    # 50 % 100 = 50
            DUT.IM.imem[60] = 32'h023275b3; // remu x11, x4, x3
            
            // ========== System Call ==========
            DUT.IM.imem[61] = 32'h00000073; // ecall
            
            // Clear rest of memory
            for (i = 62; i < 1024; i = i + 1) DUT.IM.imem[i] = 32'h00000013;

            $display("[%0t] Program loaded. Starting processor...", $time);
            start_riscv();
            
            // Monitor the first part of execution
            monitor_pipeline(100); 
            
            wait_for_completion(2000);
            
            $display("\n[%0t] All Instruction Test Finished. Checking key results...", $time);
            
            // Verify a few key registers
            display_registers(3, 15);
            
            // Check x6 (Result of add 6+5)
            check_result(32'd11, "R-type Add (x6)");
            // Check x11 (Result of OR 6|5)
            check_result(32'd7, "R-type OR (x11)");
            // Check x5 (Result of MUL 50*100)
            check_result(32'd5000, "M-extension MUL (x5)");
            // Check x10 (Result of REM 50%100)
            check_result(32'd50, "M-extension REM (x10)");
            
            $display("\n======== ALL INSTRUCTION TEST END ========\n");
        end
    endtask
    
    // Test Scenario 1: Fibonacci Test (n=10, result=55)
    task test_fibonacci;
        integer i;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 1: Fibonacci Sequence (n=10)");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Fibonacci program (direct assignment)...", $time);
            
            // Fibonacci program - Direct instruction assignment
            DUT.IM.imem[0]  = 32'h00a00513;  // addi x10, x0, 10    (a0 = 10)
            DUT.IM.imem[1]  = 32'h01c000ef;  // jal  x1, 28         (call fib)
            DUT.IM.imem[2]  = 32'h00b02023;  // sw   x11, 0(x0)     (store result)
            DUT.IM.imem[3]  = 32'h00000013;  // nop
            DUT.IM.imem[4]  = 32'h00000013;  // nop
            DUT.IM.imem[5]  = 32'h00000013;  // nop
            DUT.IM.imem[6]  = 32'h00000013;  // nop
            DUT.IM.imem[7]  = 32'h00000073;  // ecall
            
            // Fibonacci function (starts at address 0x020 = word 8)
            DUT.IM.imem[8]  = 32'h00253293;  // slti x5, x10, 2
            DUT.IM.imem[9]  = 32'h00028c63;  // beqz x5, +24
            DUT.IM.imem[10] = 32'h00050663;  // beqz x10, +12
            DUT.IM.imem[11] = 32'h00100593;  // addi x11, x0, 1
            DUT.IM.imem[12] = 32'h00008067;  // ret
            DUT.IM.imem[13] = 32'h00000593;  // addi x11, x0, 0
            DUT.IM.imem[14] = 32'h00008067;  // ret
            DUT.IM.imem[15] = 32'hffc10113;  // addi sp, sp, -4
            DUT.IM.imem[16] = 32'h00112023;  // sw   x1, 0(sp)
            DUT.IM.imem[17] = 32'hffc10113;  // addi sp, sp, -4
            DUT.IM.imem[18] = 32'h00a12023;  // sw   x10, 0(sp)
            DUT.IM.imem[19] = 32'hfff50513;  // addi x10, x10, -1
            DUT.IM.imem[20] = 32'hfd1ff0ef;  // jal  x1, -48        (recursive call)
            DUT.IM.imem[21] = 32'h00012503;  // lw   x10, 0(sp)
            DUT.IM.imem[22] = 32'h00410113;  // addi sp, sp, 4
            DUT.IM.imem[23] = 32'hffc10113;  // addi sp, sp, -4
            DUT.IM.imem[24] = 32'h00b12023;  // sw   x11, 0(sp)
            DUT.IM.imem[25] = 32'hffe50513;  // addi x10, x10, -2
            DUT.IM.imem[26] = 32'hfb9ff0ef;  // jal  x1, -72        (recursive call)
            DUT.IM.imem[27] = 32'h00012603;  // lw   x12, 0(sp)
            DUT.IM.imem[28] = 32'h00410113;  // addi sp, sp, 4
            DUT.IM.imem[29] = 32'h00b605b3;  // add  x11, x12, x11
            DUT.IM.imem[30] = 32'h00012083;  // lw   x1, 0(sp)
            DUT.IM.imem[31] = 32'h00410113;  // addi sp, sp, 4
            DUT.IM.imem[32] = 32'h00008067;  // ret
            
            // Clear remaining instruction memory
            for (i = 11; i < 1024; i = i + 1) begin
                DUT.IM.imem[i] = 32'h00000000;
            end
            
            $display("[%0t] Fibonacci program loaded (33 instructions)", $time);
            
            // Debug: Check if instructions are loaded
            $display("\nDebug - First 12 instructions in memory:");
            $display("  [0x000] = 0x%08h  # Main entry", DUT.IM.imem[0]);
            $display("  [0x004] = 0x%08h  # JAL to fib", DUT.IM.imem[1]);
            $display("  [0x008] = 0x%08h  # Store result", DUT.IM.imem[2]);
            $display("  [0x00C] = 0x%08h  # NOP", DUT.IM.imem[3]);
            $display("  [0x010] = 0x%08h  # NOP", DUT.IM.imem[4]);
            $display("  [0x014] = 0x%08h  # NOP", DUT.IM.imem[5]);
            $display("  [0x018] = 0x%08h  # NOP", DUT.IM.imem[6]);
            $display("  [0x01C] = 0x%08h  # ECALL", DUT.IM.imem[7]);
            $display("  [0x020] = 0x%08h  # fib function", DUT.IM.imem[8]);
            $display("  [0x024] = 0x%08h", DUT.IM.imem[9]);
            $display("  [0x028] = 0x%08h", DUT.IM.imem[10]);
            $display("  [0x02C] = 0x%08h\n", DUT.IM.imem[11]);
            
            $display("Program expects:");
            $display("  - Input n = 10 (in x10/a0)");
            $display("  - Output fib(10) = 55 (in x11/a1)");
            $display("  - Result stored at mem[0]\n");
            
            start_riscv();
            
            // Monitor first few cycles in detail
            $display("\nDetailed monitoring first 20 cycles:");
            $display("  Cycle | PC   | Instr    | icache_stall | dcache_stall | riscv_done");
            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
                $display("  %4d  | %04h | %08h |      %b       |      %b       |     %b", 
                         i, DUT.RISCV.pc_in, DUT.RISCV.instr,
                         DUT.icache_stall, DUT.dcache_stall, riscv_done);
            end
            
            monitor_pipeline(80);
            
            // Fibonacci(10) recursive needs many cycles!
            // Let's monitor return address and result registers
            $display("\n[%0t] Monitoring execution (checking for completion)...", $time);
            wait_for_completion(10000);
            
            $display("\n[%0t] Fibonacci calculation completed", $time);
            $display("\nKey Registers:");
            $display("  x1  (ra)  = 0x%08h (return address)", DUT.RISCV.RF.regfile[1]);
            $display("  x2  (sp)  = 0x%08h (stack pointer)", DUT.RISCV.RF.regfile[2]);
            $display("  x10 (a0)  = 0x%08h (arg/input)", DUT.RISCV.RF.regfile[10]);
            $display("  x11 (a1)  = 0x%08h (result)", DUT.RISCV.RF.regfile[11]);
            $display("  x12 (a2)  = 0x%08h (temp)", DUT.RISCV.RF.regfile[12]);
            
            display_registers(0, 15);
            display_memory(0, 32);
            check_result(32'd55, "Fibonacci(10) Test");
        end
    endtask
    
    // Test Scenario 2: Load/Store operations
    task test_load_store;
        integer i;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 2: Load/Store Operations");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Load/Store test program...", $time);
            
            // Test program for Load/Store operations
            // Initialize data memory with test values
            for (i = 0; i < 10; i = i + 1) begin
                DUT.DM.dmem[i] = i * 10; // 0, 10, 20, 30, ..., 90
            end
            
            // Program:
            // 0x000: addi x1, x0, 0x100  // x1 = base address (0x100)
            // 0x004: lw x2, 0(x1)        // Load word from mem[0x100]
            // 0x008: lw x3, 4(x1)        // Load word from mem[0x104]
            // 0x00C: add x4, x2, x3      // x4 = x2 + x3
            // 0x010: sw x4, 8(x1)        // Store result to mem[0x108]
            // 0x014: lh x5, 0(x1)        // Load halfword
            // 0x018: lb x6, 1(x1)        // Load byte
            // 0x01C: sh x5, 12(x1)       // Store halfword
            // 0x020: sb x6, 14(x1)       // Store byte
            // 0x024: addi x10, x4, 0     // Move result to x10
            // 0x028: ecall               // End
            
            DUT.IM.imem[0] = 32'h10000093; // addi x1, x0, 0x100
            DUT.IM.imem[1] = 32'h0000A103; // lw x2, 0(x1)
            DUT.IM.imem[2] = 32'h0040A183; // lw x3, 4(x1)
            DUT.IM.imem[3] = 32'h003100B3; // add x4, x2, x3
            DUT.IM.imem[4] = 32'h0040A423; // sw x4, 8(x1)
            DUT.IM.imem[5] = 32'h00009283; // lh x5, 0(x1)
            DUT.IM.imem[6] = 32'h0010C303; // lb x6, 1(x1)
            DUT.IM.imem[7] = 32'h00509623; // sh x5, 12(x1)
            DUT.IM.imem[8] = 32'h00608723; // sb x6, 14(x1)
            DUT.IM.imem[9] = 32'h00020513; // addi x10, x4, 0
            DUT.IM.imem[10] = 32'h00000073; // ecall
            
            // Set expected result register for done signal
            DUT.IM.imem[7] = 32'h01C00893; // addi x17, x0, 28 (ecall at PC 0x028)
            
            $display("[%0t] Program loaded. Testing various load/store instructions", $time);
            
            start_riscv();
            wait_for_completion(1000);
            
            display_registers(1, 6);
            display_memory(12'h100, 12'h110);
            
            // Expected: x2=0, x3=10, x4=10
            check_result(32'd10, "Load/Store Operations Test");
        end
    endtask
    
    // Test Scenario 3: Branch and jump instructions
    task test_branch_jump;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 3: Branch and Jump Instructions");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Branch/Jump test program...", $time);
            
            // Test program for Branch and Jump
            // Tests BEQ, BNE, BLT, BGE, JAL, JALR
            // 0x000: addi x1, x0, 5      // x1 = 5
            // 0x004: addi x2, x0, 10     // x2 = 10
            // 0x008: addi x3, x0, 0      // x3 = 0 (counter)
            // 0x00C: beq x1, x2, 0x020   // Skip if equal (won't branch)
            // 0x010: addi x3, x3, 1      // x3++
            // 0x014: bne x1, x2, 0x008   // Branch if not equal (will branch to 0x01C)
            // 0x018: addi x3, x3, 100    // Should be skipped
            // 0x01C: blt x1, x2, 0x008   // Branch if less (will branch to 0x024)
            // 0x020: addi x3, x3, 200    // Should be skipped
            // 0x024: bge x2, x1, 0x008   // Branch if greater or equal (will branch to 0x02C)
            // 0x028: addi x3, x3, 300    // Should be skipped
            // 0x02C: jal x4, 0x010       // Jump to 0x03C, save return address
            // 0x030: addi x3, x3, 400    // Should be skipped
            // 0x034: addi x3, x3, 500    // Should be skipped
            // 0x038: addi x3, x3, 600    // Should be skipped
            // 0x03C: addi x3, x3, 2      // x3 += 2
            // 0x040: jalr x5, x4, 0      // Return (jump to address in x4)
            // 0x044: addi x10, x3, 0     // Move result to x10
            // 0x048: ecall               // End
            
            DUT.IM.imem[0] = 32'h00500093;  // addi x1, x0, 5
            DUT.IM.imem[1] = 32'h00A00113;  // addi x2, x0, 10
            DUT.IM.imem[2] = 32'h00000193;  // addi x3, x0, 0
            DUT.IM.imem[3] = 32'h00208863;  // beq x1, x2, 16 (to 0x014)
            DUT.IM.imem[4] = 32'h00118193;  // addi x3, x3, 1
            DUT.IM.imem[5] = 32'h00209463;  // bne x1, x2, 8 (to 0x01C)
            DUT.IM.imem[6] = 32'h06418193;  // addi x3, x3, 100
            DUT.IM.imem[7] = 32'h0020C463;  // blt x1, x2, 8 (to 0x024)
            DUT.IM.imem[8] = 32'h0C818193;  // addi x3, x3, 200
            DUT.IM.imem[9] = 32'h0010D463;  // bge x2, x1, 8 (to 0x02C)
            DUT.IM.imem[10] = 32'h12C18193; // addi x3, x3, 300
            DUT.IM.imem[11] = 32'h010002EF; // jal x4, 16 (to 0x03C)
            DUT.IM.imem[12] = 32'h19018193; // addi x3, x3, 400
            DUT.IM.imem[13] = 32'h1F418193; // addi x3, x3, 500
            DUT.IM.imem[14] = 32'h25818193; // addi x3, x3, 600
            DUT.IM.imem[15] = 32'h00218193; // addi x3, x3, 2
            DUT.IM.imem[16] = 32'h000202E7; // jalr x5, x4, 0
            DUT.IM.imem[17] = 32'h00018513; // addi x10, x3, 0
            DUT.IM.imem[18] = 32'h00000073; // ecall
            
            $display("[%0t] Program loaded. Testing BEQ, BNE, BLT, BGE, JAL, JALR", $time);
            
            start_riscv();
            wait_for_completion(1000);
            
            display_registers(1, 10);
            
            // Expected: x3 should be 3 (1 + 2 from the execution path)
            check_result(32'd3, "Branch/Jump Test");
        end
    endtask
    
    // Test Scenario 4: Pipeline hazard handling
    task test_hazards;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 4: Pipeline Hazard Handling");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Hazard test program...", $time);
            $display("This test includes:");
            $display("  - RAW (Read After Write) data hazards");
            $display("  - Load-use hazards requiring stalls");
            $display("  - Control hazards from branches");
            $display("  - Forwarding validation");
            
            // Test program for pipeline hazards
            // 0x000: addi x1, x0, 10     // x1 = 10
            // 0x004: addi x2, x1, 5      // RAW hazard: x2 = x1 + 5 = 15 (forwarding)
            // 0x008: add x3, x2, x1      // RAW hazard: x3 = x2 + x1 = 25 (forwarding)
            // 0x00C: addi x4, x0, 0x100  // x4 = memory base address
            // 0x010: sw x3, 0(x4)        // Store x3 to memory
            // 0x014: lw x5, 0(x4)        // Load-use hazard: needs stall
            // 0x018: addi x6, x5, 1      // Use loaded value: x6 = x5 + 1 = 26
            // 0x01C: add x7, x6, x3      // x7 = x6 + x3 = 51
            // 0x020: beq x0, x0, 0x008   // Branch (to 0x028)
            // 0x024: addi x7, x7, 100    // Should be flushed
            // 0x028: addi x8, x7, 10     // x8 = x7 + 10 = 61
            // 0x02C: sub x9, x8, x1      // x9 = x8 - x1 = 51
            // 0x030: lw x10, 0(x4)       // Another load-use
            // 0x034: add x11, x10, x9    // x11 = x10 + x9 = 76
            // 0x038: addi x10, x11, 0    // Move to result register
            // 0x03C: ecall               // End
            
            DUT.IM.imem[0] = 32'h00A00093;  // addi x1, x0, 10
            DUT.IM.imem[1] = 32'h00508113;  // addi x2, x1, 5
            DUT.IM.imem[2] = 32'h001101B3;  // add x3, x2, x1
            DUT.IM.imem[3] = 32'h10000213;  // addi x4, x0, 0x100
            DUT.IM.imem[4] = 32'h00322023;  // sw x3, 0(x4)
            DUT.IM.imem[5] = 32'h00022283;  // lw x5, 0(x4)
            DUT.IM.imem[6] = 32'h00128313;  // addi x6, x5, 1
            DUT.IM.imem[7] = 32'h003303B3;  // add x7, x6, x3
            DUT.IM.imem[8] = 32'h00000463;  // beq x0, x0, 8
            DUT.IM.imem[9] = 32'h06438393;  // addi x7, x7, 100
            DUT.IM.imem[10] = 32'h00A38413; // addi x8, x7, 10
            DUT.IM.imem[11] = 32'h401404B3; // sub x9, x8, x1
            DUT.IM.imem[12] = 32'h00022503; // lw x10, 0(x4)
            DUT.IM.imem[13] = 32'h009505B3; // add x11, x10, x9
            DUT.IM.imem[14] = 32'h00058513; // addi x10, x11, 0
            DUT.IM.imem[15] = 32'h00000073; // ecall
            
            $display("[%0t] Program loaded. Monitoring pipeline behavior...", $time);
            
            start_riscv();
            
            $display("\n[%0t] Monitoring first 50 cycles of pipeline:", $time);
            monitor_pipeline(50);
            
            wait_for_completion(1000);
            
            display_registers(1, 11);
            
            // Expected result: x11 = 76
            check_result(32'd76, "Hazard Handling Test");
        end
    endtask
    
    // Test Scenario 5: Cache behavior
    task test_cache;
        integer i;
        integer icache_hits, icache_misses;
        integer dcache_hits, dcache_misses;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 5: Cache Behavior");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Cache test program...", $time);
            $display("This test validates:");
            $display("  - Instruction cache hits on loop iterations");
            $display("  - Data cache behavior with repeated memory access");
            $display("  - Cache miss penalties");
            
            // Initialize data memory with pattern
            for (i = 0; i < 64; i = i + 1) begin
                DUT.DM.dmem[i] = i;
            end
            
            // Test program: Loop that accesses memory repeatedly
            // 0x000: addi x1, x0, 0x100  // x1 = base address
            // 0x004: addi x2, x0, 10     // x2 = loop counter
            // 0x008: addi x3, x0, 0      // x3 = accumulator
            // 0x00C: lw x4, 0(x1)        // Load from mem[x1] - first miss, then hits
            // 0x010: add x3, x3, x4      // Accumulate
            // 0x014: addi x1, x1, 4      // Increment address
            // 0x018: addi x2, x2, -1     // Decrement counter
            // 0x01C: bne x2, x0, -16     // Loop back to 0x00C if not zero
            // 0x020: lw x5, -40(x1)      // Load from earlier address (cache hit)
            // 0x024: add x3, x3, x5      // Add to accumulator
            // 0x028: lw x6, -36(x1)      // Another cache hit
            // 0x02C: add x3, x3, x6      // Add to accumulator
            // 0x030: addi x10, x3, 0     // Move result to x10
            // 0x034: ecall               // End
            
            DUT.IM.imem[0] = 32'h10000093;  // addi x1, x0, 0x100
            DUT.IM.imem[1] = 32'h00A00113;  // addi x2, x0, 10
            DUT.IM.imem[2] = 32'h00000193;  // addi x3, x0, 0
            DUT.IM.imem[3] = 32'h0000A203;  // lw x4, 0(x1)
            DUT.IM.imem[4] = 32'h004181B3;  // add x3, x3, x4
            DUT.IM.imem[5] = 32'h00408093;  // addi x1, x1, 4
            DUT.IM.imem[6] = 32'hFFF10113;  // addi x2, x2, -1
            DUT.IM.imem[7] = 32'hFE0214E3;  // bne x2, x0, -16
            DUT.IM.imem[8] = 32'hFD80A283;  // lw x5, -40(x1)
            DUT.IM.imem[9] = 32'h005181B3;  // add x3, x3, x5
            DUT.IM.imem[10] = 32'hFDC0A303; // lw x6, -36(x1)
            DUT.IM.imem[11] = 32'h006181B3; // add x3, x3, x6
            DUT.IM.imem[12] = 32'h00018513; // addi x10, x3, 0
            DUT.IM.imem[13] = 32'h00000073; // ecall
            
            $display("[%0t] Program loaded. Monitoring cache behavior...", $time);
            
            // Initialize cache counters
            icache_hits = 0;
            icache_misses = 0;
            dcache_hits = 0;
            dcache_misses = 0;
            
            start_riscv();
            
            // Monitor cache behavior during execution
            fork
                begin
                    while (!riscv_done) begin
                        @(posedge clk);
                        // Track instruction cache behavior
                        if (DUT.RISCV.icache_read_req) begin
                            if (DUT.icache_hit) begin
                                icache_hits = icache_hits + 1;
                            end else if (DUT.icache_stall) begin
                                // Nếu stall và không hit thì tính là miss
                                // Lưu ý: Miss sẽ stall nhiều chu kỳ, logic đếm này chỉ mang tính ước lượng tương đối
                                // Muốn chính xác tuyệt đối cần bắt cạnh lên của stall
                                icache_misses = icache_misses + 1;
                            end
                        end
                        if (DUT.RISCV.dcache_read_req || DUT.RISCV.dcache_write_req) begin
                            if (DUT.dcache_hit) begin
                                dcache_hits = dcache_hits + 1;
                            end else if (DUT.dcache_stall) begin
                                dcache_misses = dcache_misses + 1;
                            end
                        end
                    end
                end
                begin
                    wait_for_completion(2000);
                end
            join
            
            display_registers(1, 6);
            
            $display("\n[%0t] Cache Statistics:", $time);
            $display("  +------------------------+--------+");
            $display("  | Metric                 | Count  |");
            $display("  +------------------------+--------+");
            $display("  | Instruction Cache Hits | %6d |", icache_hits);
            $display("  | Instruction Cache Miss | %6d |", icache_misses);
            $display("  | Data Cache Hits        | %6d |", dcache_hits);
            $display("  | Data Cache Misses      | %6d |", dcache_misses);
            $display("  +------------------------+--------+");
            if (icache_hits + icache_misses > 0)
                $display("  | I-Cache Hit Rate       | %5d%% |", (icache_hits * 100) / (icache_hits + icache_misses));
            if (dcache_hits + dcache_misses > 0)
                $display("  | D-Cache Hit Rate       | %5d%% |", (dcache_hits * 100) / (dcache_hits + dcache_misses));
            $display("  +------------------------+--------+");
            
            // Expected: sum of 0+1+2+...+9 = 45, plus two more values
            check_result(32'd45, "Cache Test");
        end
    endtask
    
    // Test Scenario 0: Simple Debug Test
    task test_simple_debug;
        integer i;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO 0: Simple Debug Test");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading simple test program...", $time);
            
            // Very simple program
            // addi x1, x0, 5       # x1 = 5
            DUT.IM.imem[0] = 32'h00500093;
            // addi x2, x0, 10      # x2 = 10
            DUT.IM.imem[1] = 32'h00A00113;
            // add x3, x1, x2       # x3 = 15
            DUT.IM.imem[2] = 32'h002081B3;
            // sw x3, 0(x0)         # Store to addr 0
            DUT.IM.imem[3] = 32'h00302023;
            // ECALL
            DUT.IM.imem[4] = 32'h00000073;
            
            for (i = 5; i < 1024; i = i + 1) begin
                DUT.IM.imem[i] = 32'h00000013;
            end
            
            $display("[%0t] Program loaded. Starting execution...", $time);
            $display("\nProgram:");
            $display("  0x000: addi x1, x0, 5    # x1 = 5");
            $display("  0x004: addi x2, x0, 10   # x2 = 10");
            $display("  0x008: add  x3, x1, x2   # x3 = 15");
            $display("  0x00C: sw   x3, 0(x0)    # mem[0] = 15");
            $display("  0x010: ecall             # exit\n");
            
            start_riscv();
            monitor_pipeline(40);
            wait_for_completion(1000);
            
            $display("\n[%0t] Execution completed", $time);
            display_registers(0, 5);
            display_memory(0, 16);
            check_result(32'd15, "Simple Debug Test");
        end
    endtask
    
    // Test Scenario: Factorial 10! Calculation
    task test_factorial;
        integer i;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO: Factorial 10! Calculation");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Factorial 10! program...", $time);
            
            // Factorial program: compute 10!
            // result = 1
            // for (i = 1; i <= 10; i++)
            //     result = result * i
            
            // x10 = n (10)
            // x11 = result (accumulator)
            // x12 = counter (i)
            
            DUT.IM.imem[0]  = 32'h00b00513;  // addi x10, x0, 11       # n = 11 (để tính đến 10)
            DUT.IM.imem[1]  = 32'h00100593;  // addi x11, x0, 1        # result = 1
            DUT.IM.imem[2]  = 32'h00100613;  // addi x12, x0, 1        # i = 1
            
            // loop: (address 0x00C)
            DUT.IM.imem[3]  = 32'h02c586B3;  // mul x13, x11, x12      # temp = result * i
            DUT.IM.imem[4]  = 32'h00068593;  // addi x11, x13, 0       # result = temp
            DUT.IM.imem[5]  = 32'h00160613;  // addi x12, x12, 1       # i++
            DUT.IM.imem[6]  = 32'h00a65463;  // bge x12, x10, exit     # if i >= 11, goto exit (offset=+8)
            DUT.IM.imem[7]  = 32'hFF1FF06F;  // jal x0, loop           # goto loop (-16 → 0x01C-16=0x00C)
            
            // exit: (address 0x020)
            DUT.IM.imem[8]  = 32'h00b02023;  // sw x11, 0(x0)          # store result at mem[0]
            DUT.IM.imem[9]  = 32'h00000013;  // nop
            DUT.IM.imem[10] = 32'h00000073;  // ecall                  # exit
            
            // Clear remaining instruction memory
            for (i = 11; i < 1024; i = i + 1) begin
                DUT.IM.imem[i] = 32'h00000000;
            end
            
            $display("[%0t] Program loaded (11 instructions)", $time);
            
            $display("\nProgram Logic:");
            $display("  Calculate 10! using iterative multiplication");
            $display("  Loop: i=1 to 10, result *= i");
            $display("  10! = 1 × 2 × 3 × ... × 10 = 3,628,800");
            $display("  Expected result: 3,628,800 (0x00375f00)\n");
            
            $display("Debug - Instructions:");
            $display("  [0x000] = 0x%08h  # addi x10, x0, 11 (limit=11)", DUT.IM.imem[0]);
            $display("  [0x004] = 0x%08h  # addi x11, x0, 1 (result=1)", DUT.IM.imem[1]);
            $display("  [0x008] = 0x%08h  # addi x12, x0, 1 (i=1)", DUT.IM.imem[2]);
            $display("  [0x00C] = 0x%08h  # mul x13, x11, x12 (loop)", DUT.IM.imem[3]);
            $display("  [0x010] = 0x%08h  # addi x11, x13, 0 (result=temp)", DUT.IM.imem[4]);
            $display("  [0x014] = 0x%08h  # addi x12, x12, 1 (i++)", DUT.IM.imem[5]);
            $display("  [0x018] = 0x%08h  # bge x12, x10, exit (if i>=11)", DUT.IM.imem[6]);
            $display("  [0x01C] = 0x%08h  # jal x0, loop (goto 0x00C)", DUT.IM.imem[7]);
            $display("  [0x020] = 0x%08h  # sw x11, 0(x0) (exit)", DUT.IM.imem[8]);
            $display("  [0x024] = 0x%08h  # nop", DUT.IM.imem[9]);
            $display("  [0x028] = 0x%08h  # ecall", DUT.IM.imem[10]);
            $display("  [0x028] = 0x%08h  # sw x11, 0(x0) (exit)", DUT.IM.imem[10]);
            $display("  [0x02C] = 0x%08h  # ecall\n", DUT.IM.imem[11]);
            
            start_riscv();
            
            // Monitor first 50 cycles to see multiple iterations
            $display("\nDetailed monitoring first 50 cycles:");
            $display("  Cycle | PC   | IF_Instr | ID_Instr | x11(res) | x12(i) | x13(tmp) | md_stall | mul_done");
            for (i = 0; i < 50; i = i + 1) begin
                @(posedge clk);
                $display("  %4d  | %04h | %08h | %08h | %8d | %6d | %8d | %d | %d", 
                         i, DUT.RISCV.pc_in, DUT.RISCV.instr, DUT.RISCV.if_id_instr,
                         DUT.RISCV.RF.regfile[11],
                         DUT.RISCV.RF.regfile[12],
                         DUT.RISCV.RF.regfile[13],
                         DUT.RISCV.md_alu_stall,
                         DUT.RISCV.EX.mul_alu_done);
            end
            
            $display("\n[%0t] Continuing execution (factorial needs ~150 cycles)...", $time);
            wait_for_completion(500);
            
            $display("\n[%0t] Factorial calculation completed", $time);
            
            // Check factorial result
            $display("\n=== Factorial 10! Result ===");
            $display("10! = 3,628,800");
            $display("Result: %0d (0x%08h)", DUT.RISCV.RF.regfile[11], DUT.RISCV.RF.regfile[11]);
            $display("Expected: 3,628,800 (0x00375f00)");
            
            // Verify result
            if (DUT.RISCV.RF.regfile[11] == 32'h00375f00) begin
                $display("\n*** FACTORIAL 10! TEST PASSED ***");
                passed_tests = passed_tests + 1;
            end else begin
                $display("\n*** FACTORIAL 10! TEST FAILED ***");
                $display("Expected: 3628800 (0x00375f00)");
                $display("Got:      %0d (0x%08h)", DUT.RISCV.RF.regfile[11], DUT.RISCV.RF.regfile[11]);
                failed_tests = failed_tests + 1;
            end
            total_tests = total_tests + 1;
            
            // Display all registers
            $display("\nFinal Registers:");
            display_registers(0, 15);
            
            // Wait for cache write-back
            #100;
            
            // Display memory
            $display("\nData Memory (result stored at mem[0]):");
            display_memory(0, 4);
            
            $display("\n=== Loop Iteration Summary ===");
            $display("Final counter (i): %0d", DUT.RISCV.RF.regfile[12]);
            $display("Loop executed %0d iterations", DUT.RISCV.RF.regfile[12] - 1);
            
            $display("\n======== FACTORIAL 10! TEST END ========\n");
        end
    endtask
    
    // Test Scenario: Division operations (DIV, DIVU, REM, REMU)
    task test_division;
        integer i;
        integer cycle_count;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO: Division Instructions (DIV, DIVU, REM, REMU)");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading Division test program...", $time);
            
            // Division test program
            // Test cases:
            //   1. 100 / 7 = 14, 100 % 7 = 2  (DIV/REM signed)
            //   2. 200 / 8 = 25, 200 % 8 = 0  (DIVU/REMU unsigned)
            //   3. -100 / 7 = -14, -100 % 7 = -2 (DIV/REM signed negative)
            //   4. 50 / 0 = -1, 50 % 0 = 50   (divide by zero)
            
            DUT.IM.imem[0]  = 32'h06400513;  // addi x10, x0, 100       (a0 = 100)
            DUT.IM.imem[1]  = 32'h00700593;  // addi x11, x0, 7         (a1 = 7)
            DUT.IM.imem[2]  = 32'h02b54633;  // div  x12, x10, x11      (a2 = 100/7 = 14)
            DUT.IM.imem[3]  = 32'h02b566b3;  // rem  x13, x10, x11      (a3 = 100%7 = 2)
            DUT.IM.imem[4]  = 32'h00c02023;  // sw   x12, 0(x0)         (store quotient)
            DUT.IM.imem[5]  = 32'h00d02223;  // sw   x13, 4(x0)         (store remainder)
            
            DUT.IM.imem[6] = 32'h0c800713;  // addi x14, x0, 200       (a4 = 200)
            DUT.IM.imem[7] = 32'h00800793;  // addi x15, x0, 8         (a5 = 8)
            DUT.IM.imem[8] = 32'h02f75833;  // divu x16, x14, x15      (a6 = 200/8 = 25)
            DUT.IM.imem[9] = 32'h02f778b3;  // remu x17, x14, x15      (a7 = 200%8 = 0)
            DUT.IM.imem[10] = 32'h01002423;  // sw   x16, 8(x0)         (store quotient)
            DUT.IM.imem[11] = 32'h01102623;  // sw   x17, 12(x0)        (store remainder)
            
            DUT.IM.imem[12] = 32'hf9c00913;  // addi x18, x0, -100      (s2 = -100)
            DUT.IM.imem[13] = 32'h00700993;  // addi x19, x0, 7         (s3 = 7)
            DUT.IM.imem[14] = 32'h03394a33;  // div  x20, x18, x19      (s4 = -100/7 = -14)
            DUT.IM.imem[15] = 32'h03396ab3;  // rem  x21, x18, x19      (s5 = -100%7 = -2)
            DUT.IM.imem[16] = 32'h01402823;  // sw   x20, 16(x0)        (store quotient)
            DUT.IM.imem[17] = 32'h01502a23;  // sw   x21, 20(x0)        (store remainder)
            
            DUT.IM.imem[18] = 32'h03200b13;  // addi x22, x0, 50        (s6 = 50)
            DUT.IM.imem[19] = 32'h00000b93;  // addi x23, x0, 0         (s7 = 0)
            DUT.IM.imem[20] = 32'h037b4c33;  // div  x24, x22, x23      (s8 = 50/0 = -1)
            DUT.IM.imem[21] = 32'h037b6cb3;  // rem  x25, x22, x23      (s9 = 50%0 = 50)
            DUT.IM.imem[22] = 32'h01802c23;  // sw   x24, 24(x0)        (store quotient)
            DUT.IM.imem[23] = 32'h01902e23;  // sw   x25, 28(x0)        (store remainder)
            
            DUT.IM.imem[24] = 32'h00000013;  // nop
            DUT.IM.imem[25] = 32'h00000013;  // nop
            DUT.IM.imem[42] = 32'h00000073;  // ecall
            
            // Clear remaining instruction memory
            for (i = 43; i < 1024; i = i + 1) begin
                DUT.IM.imem[i] = 32'h00000000;
            end
            
            $display("[%0t] Division test program loaded (43 instructions)", $time);
            
            $display("\nProgram Logic:");
            $display("  Test 1: 100 / 7 = 14, 100 %% 7 = 2    (signed)");
            $display("  Test 2: 200 / 8 = 25, 200 %% 8 = 0    (unsigned)");
            $display("  Test 3: -100 / 7 = -14, -100 %% 7 = -2 (signed negative)");
            $display("  Test 4: 50 / 0 = -1, 50 %% 0 = 50     (divide by zero)");
            
            $display("\nDebug - Instructions:");
            for (i = 0; i < 12; i = i + 1) begin
                $display("  [0x%03h] = 0x%08h", i*4, DUT.IM.imem[i]);
            end
            
            start_riscv();
            
            // Monitor first 50 cycles
            $display("\nDetailed monitoring first 50 cycles:");
            $display("  Cycle | PC   | Instr    | x10(a0) | x11(a1) | x12(a2) | x13(a3) | div_done");
            for (i = 0; i < 50; i = i + 1) begin
                @(posedge clk);
                $display("  %4d  | %04h | %08h | %7d | %7d | %7d | %7d | %b", 
                         i, DUT.RISCV.pc_in, DUT.RISCV.instr,
                         DUT.RISCV.RF.regfile[10], DUT.RISCV.RF.regfile[11],
                         DUT.RISCV.RF.regfile[12], DUT.RISCV.RF.regfile[13],
                         DUT.RISCV.EX.DIV.md_alu_done);
            end
            
            $display("\n[%0t] Continuing execution...", $time);
            wait_for_completion(500);
            
            $display("\n[%0t] Division tests completed", $time);
            
            $display("\n=== Division Test Results ===");
            
            // Test 1: 100/7 and 100%7
            $display("\nTest 1 (Signed): 100 / 7 and 100 %% 7");
            $display("  x12 (quotient)  = %0d (expected: 14)", $signed(DUT.RISCV.RF.regfile[12]));
            $display("  x13 (remainder) = %0d (expected: 2)", $signed(DUT.RISCV.RF.regfile[13]));
            $display("  mem[0]  = 0x%08h (%0d)", DUT.DM.dmem[0], $signed(DUT.DM.dmem[0]));
            $display("  mem[4]  = 0x%08h (%0d)", DUT.DM.dmem[1], $signed(DUT.DM.dmem[1]));
            
            // Test 2: 200/8 and 200%8
            $display("\nTest 2 (Unsigned): 200 / 8 and 200 %% 8");
            $display("  x16 (quotient)  = %0d (expected: 25)", DUT.RISCV.RF.regfile[16]);
            $display("  x17 (remainder) = %0d (expected: 0)", DUT.RISCV.RF.regfile[17]);
            $display("  mem[8]  = 0x%08h (%0d)", DUT.DM.dmem[2], DUT.DM.dmem[2]);
            $display("  mem[12] = 0x%08h (%0d)", DUT.DM.dmem[3], DUT.DM.dmem[3]);
            
            // Test 3: -100/7 and -100%7
            $display("\nTest 3 (Signed Negative): -100 / 7 and -100 %% 7");
            $display("  x20 (quotient)  = %0d (expected: -14)", $signed(DUT.RISCV.RF.regfile[20]));
            $display("  x21 (remainder) = %0d (expected: -2)", $signed(DUT.RISCV.RF.regfile[21]));
            $display("  mem[16] = 0x%08h (%0d)", DUT.DM.dmem[4], $signed(DUT.DM.dmem[4]));
            $display("  mem[20] = 0x%08h (%0d)", DUT.DM.dmem[5], $signed(DUT.DM.dmem[5]));
            
            // Test 4: 50/0 and 50%0
            $display("\nTest 4 (Divide by Zero): 50 / 0 and 50 %% 0");
            $display("  x24 (quotient)  = 0x%08h (expected: 0xFFFFFFFF)", DUT.RISCV.RF.regfile[24]);
            $display("  x25 (remainder) = %0d (expected: 50)", DUT.RISCV.RF.regfile[25]);
            $display("  mem[24] = 0x%08h", DUT.DM.dmem[6]);
            $display("  mem[28] = 0x%08h (%0d)", DUT.DM.dmem[7], DUT.DM.dmem[7]);
            
            display_registers(10, 25);
            display_memory(0, 28);
            
            // Verify results
            if (DUT.RISCV.RF.regfile[12] == 14 && 
                DUT.RISCV.RF.regfile[13] == 2 &&
                DUT.RISCV.RF.regfile[16] == 25 &&
                DUT.RISCV.RF.regfile[17] == 0 &&
                $signed(DUT.RISCV.RF.regfile[20]) == -14 &&
                $signed(DUT.RISCV.RF.regfile[21]) == -2 &&
                DUT.RISCV.RF.regfile[24] == 32'hFFFFFFFF &&
                DUT.RISCV.RF.regfile[25] == 50) begin
                $display("\n*** ALL DIVISION TESTS PASSED ***");
                pass_count = pass_count + 1;
            end else begin
                $display("\n*** DIVISION TESTS FAILED ***");
                fail_count = fail_count + 1;
            end
            test_count = test_count + 1;
            
            $display("\n======== DIVISION TEST END ========\n");
        end
    endtask
    
    // Test Scenario: GCD (Greatest Common Divisor) using Euclidean algorithm
    task test_gcd;
        integer i;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO: GCD Calculation (40, 50)");
            $display("################################################################################");
            
            system_reset(5);
            
            $display("[%0t] Loading GCD program...", $time);
            
            // GCD algorithm using division (Euclidean algorithm):
            // gcd(a, b):
            //   while (b != 0):
            //     temp = b
            //     b = a % b
            //     a = temp
            //   return a
            //
            // For a=40, b=50:
            //   Step 1: 40, 50 → b=40%50=40, a=50
            //   Step 2: 50, 40 → b=50%40=10, a=40
            //   Step 3: 40, 10 → b=40%10=0, a=10
            //   Result: GCD(40, 50) = 10
            
            // x10 = a (initially 40)
            // x11 = b (initially 50)
            // x12 = temp
            
            DUT.IM.imem[0]  = 32'h02800513;  // addi x10, x0, 40       # a = 40
            DUT.IM.imem[1]  = 32'h03200593;  // addi x11, x0, 50       # b = 50
            
            // loop: (address 0x008)
            DUT.IM.imem[2]  = 32'h01458063;  // beqz x11, exit         # if b == 0, goto exit (offset=+20 → 0x01C)
            DUT.IM.imem[3]  = 32'h00058613;  // addi x12, x11, 0       # temp = b
            DUT.IM.imem[4]  = 32'h02b565b3;  // rem x11, x10, x11      # b = a % b
            DUT.IM.imem[5]  = 32'h00060513;  // addi x10, x12, 0       # a = temp
            DUT.IM.imem[6]  = 32'hFF1FF06F;  // jal x0, loop           # goto loop (-16 → PC+(-16)=0x018-16=0x008)
            
            // exit: (address 0x01C)
            DUT.IM.imem[7]  = 32'h00a02023;  // sw x10, 0(x0)          # store result at mem[0]
            DUT.IM.imem[8]  = 32'h00000013;  // nop
            DUT.IM.imem[9]  = 32'h00000073;  // ecall
            
            // Clear remaining instruction memory
            for (i = 10; i < 1024; i = i + 1) begin
                DUT.IM.imem[i] = 32'h00000000;
            end
            
            $display("[%0t] GCD program loaded (10 instructions)", $time);
            
            $display("\nProgram Logic:");
            $display("  Calculate GCD(40, 50) using Euclidean algorithm");
            $display("  Algorithm: while (b != 0) { temp=b; b=a%%b; a=temp; }");
            $display("  Expected steps:");
            $display("    Step 1: a=40, b=50 → temp=50, b=40%%50=40, a=50");
            $display("    Step 2: a=50, b=40 → temp=40, b=50%%40=10, a=40");
            $display("    Step 3: a=40, b=10 → temp=10, b=40%%10=0, a=10");
            $display("    Step 4: b=0 → exit, result=10");
            $display("  Expected result: GCD(40, 50) = 10\n");
            
            $display("Debug - Instructions:");
            $display("  [0x000] = 0x%08h  # addi x10, x0, 40 (a=40)", DUT.IM.imem[0]);
            $display("  [0x004] = 0x%08h  # addi x11, x0, 50 (b=50)", DUT.IM.imem[1]);
            $display("  [0x008] = 0x%08h  # beqz x11, exit (loop, offset=+20)", DUT.IM.imem[2]);
            $display("  [0x00C] = 0x%08h  # addi x12, x11, 0 (temp=b)", DUT.IM.imem[3]);
            $display("  [0x010] = 0x%08h  # rem x11, x10, x11 (b=a%%b)", DUT.IM.imem[4]);
            $display("  [0x014] = 0x%08h  # addi x10, x12, 0 (a=temp)", DUT.IM.imem[5]);
            $display("  [0x018] = 0x%08h  # jal x0, loop (offset=-16)", DUT.IM.imem[6]);
            $display("  [0x01C] = 0x%08h  # sw x10, 0(x0) (exit)", DUT.IM.imem[7]);
            $display("  [0x020] = 0x%08h  # nop", DUT.IM.imem[8]);
            $display("  [0x024] = 0x%08h  # ecall\n", DUT.IM.imem[9]);
            
            start_riscv();
            
            // Monitor first 50 cycles to see loop iterations
            $display("\nDetailed monitoring first 50 cycles:");
            $display("  Cycle | PC   | Instr    | x10(a) | x11(b) | x12(tmp) | rem_done | beqz");
            for (i = 0; i < 50; i = i + 1) begin
                @(posedge clk);
                $display("  %4d  | %04h | %08h | %6d | %6d | %7d | %b | %b", 
                         i, DUT.RISCV.pc_in, DUT.RISCV.instr,
                         DUT.RISCV.RF.regfile[10],
                         DUT.RISCV.RF.regfile[11],
                         DUT.RISCV.RF.regfile[12],
                         DUT.RISCV.EX.DIV.md_alu_done,
                         (DUT.RISCV.instr[6:0] == 7'b1100011)); // branch instruction
            end
            
            $display("\n[%0t] Continuing execution...", $time);
            wait_for_completion(500);
            
            $display("\n[%0t] GCD calculation completed", $time);
            
            $display("\n=== GCD Calculation Result ===");
            $display("GCD(40, 50) = %0d", DUT.RISCV.RF.regfile[10]);
            $display("Expected: 10");
            
            // Display final registers
            $display("\nFinal Registers:");
            $display("  x10 (a/result) = %0d", DUT.RISCV.RF.regfile[10]);
            $display("  x11 (b)        = %0d", DUT.RISCV.RF.regfile[11]);
            $display("  x12 (temp)     = %0d", DUT.RISCV.RF.regfile[12]);
            
            display_registers(10, 15);
            display_memory(0, 4);
            
            // Verify result
            if (DUT.RISCV.RF.regfile[10] == 10) begin
                $display("\n*** GCD TEST PASSED ***");
                $display("Correctly calculated GCD(40, 50) = 10");
                pass_count = pass_count + 1;
            end else begin
                $display("\n*** GCD TEST FAILED ***");
                $display("Expected: 10");
                $display("Got:      %0d", DUT.RISCV.RF.regfile[10]);
                fail_count = fail_count + 1;
            end
            test_count = test_count + 1;
            
            $display("\n======== GCD TEST END ========\n");
        end
    endtask
    // Test Scenario: Cache Write-back Verification
    task test_cache_writeback;
        integer i;
        reg [31:0] check_val;
        integer evictions_found;
        begin
            $display("\n\n");
            $display("################################################################################");
            $display("#  TEST SCENARIO: Cache Write-Back (Eviction Test)");
            $display("################################################################################");
            
            system_reset(5);
            
            // 1. Xóa sạch Data Memory để đảm bảo dữ liệu chúng ta thấy là do Cache ghi xuống
            for (i = 0; i < 256; i = i + 1) begin
                DUT.DM.dmem[i] = 0;
            end
            $display("[%0t] Cleared Data Memory.", $time);

            $display("[%0t] Loading Write-back test program...", $time);
            
            // --- KỊCH BẢN ---
            // Cache cấu hình: 4-Way, Set=16 (Index 4 bit), Block=32bit (4 byte).
            // Địa chỉ: Tag[11:6] | Index[5:2] | Offset[1:0]
            // Chúng ta chọn Index = 0 (Set 0).
            // Các địa chỉ sẽ có Index=0 nhưng Tag khác nhau:
            // 1. Addr 0x000 (0)   -> Tag 0, Val = 11
            // 2. Addr 0x040 (64)  -> Tag 1, Val = 22
            // 3. Addr 0x080 (128) -> Tag 2, Val = 33
            // 4. Addr 0x0C0 (192) -> Tag 3, Val = 44
            // ---> Set 0 ĐẦY và DIRTY (vì dùng lệnh SW)
            // 5. Addr 0x100 (256) -> Tag 4, Val = 55
            // ---> Gây ra MISS. Cache phải chọn 1 Victim để đẩy xuống RAM.
            
            // Code Assembly:
            // addi x1, x0, 11
            // sw   x1, 0(x0)    (Store 11 to 0x000)
            // addi x1, x0, 22
            // sw   x1, 64(x0)   (Store 22 to 0x040)
            // addi x1, x0, 33
            // sw   x1, 128(x0)  (Store 33 to 0x080)
            // addi x1, x0, 44
            // sw   x1, 192(x0)  (Store 44 to 0x0C0)
            // addi x1, x0, 55
            // sw   x1, 256(x0)  (Store 55 to 0x100) -> Kích hoạt Write-back
            // ecall

            DUT.IM.imem[0] = 32'h00B00093; // addi x1, x0, 11
            DUT.IM.imem[1] = 32'h00102023; // sw   x1, 0(x0)
            
            DUT.IM.imem[2] = 32'h01600093; // addi x1, x0, 22
            DUT.IM.imem[3] = 32'h04102023; // sw   x1, 64(x0)
            
            DUT.IM.imem[4] = 32'h02100093; // addi x1, x0, 33
            DUT.IM.imem[5] = 32'h08102023; // sw   x1, 128(x0)
            
            DUT.IM.imem[6] = 32'h02C00093; // addi x1, x0, 44
            DUT.IM.imem[7] = 32'h0C102023; // sw   x1, 192(x0)
            
            DUT.IM.imem[8] = 32'h03700093; // addi x1, x0, 55
            DUT.IM.imem[9] = 32'h10102023; // sw   x1, 256(x0) -- EVICTION TRIGGER
            
            DUT.IM.imem[10] = 32'h00000073; // ecall
            
            // Xóa phần còn lại
            for (i = 11; i < 1024; i = i + 1) DUT.IM.imem[i] = 32'h00000000;

            start_riscv();
            
            // Chờ cho pipeline xử lý xong
            wait_for_completion(100);
            
            // Chờ thêm một chút cho Cache Write-Back cycle hoàn tất (state machine)
            #100; 

            $display("\n[%0t] Checking Data Memory for write-backs...", $time);
            
            // Kiểm tra các ô nhớ tương ứng trong RAM.
            // Lưu ý: dmem được khai báo là reg [31:0] dmem [0:1023];
            // Địa chỉ byte 0 -> index 0
            // Địa chỉ byte 64 -> index 16 (64/4)
            // Địa chỉ byte 128 -> index 32
            // Địa chỉ byte 192 -> index 48
            // Địa chỉ byte 256 -> index 64
            
            evictions_found = 0;
            
            $display("  Mem[0x000] (Idx 0)  = %0d (Expected 11 if evicted)", DUT.DM.dmem[0]);
            $display("  Mem[0x040] (Idx 16) = %0d (Expected 22 if evicted)", DUT.DM.dmem[16]);
            $display("  Mem[0x080] (Idx 32) = %0d (Expected 33 if evicted)", DUT.DM.dmem[32]);
            $display("  Mem[0x0C0] (Idx 48) = %0d (Expected 44 if evicted)", DUT.DM.dmem[48]);
            
            // Nếu thuật toán LRU hoạt động đúng, nó sẽ xóa thằng đầu tiên (Addr 0, Val 11)
            // Nhưng để test tổng quát, chỉ cần ít nhất 1 thằng được ghi xuống là Write-back hoạt động.
            if (DUT.DM.dmem[0] == 11 || DUT.DM.dmem[16] == 22 || DUT.DM.dmem[32] == 33 || DUT.DM.dmem[48] == 44) begin
                $display("\nSUCCESS: Found data written back to memory!");
                if (DUT.DM.dmem[0] == 11) $display(" Address 0x000 was the victim (Correct behavior for LRU if addr 0 was accessed first).");
                pass_count = pass_count + 1;
            end else begin
                $display("\nFAILURE: No data written back to memory. Write-back policy might be broken.");
                $display("  (Memory should contain non-zero values for evicted lines)");
                fail_count = fail_count + 1;
            end
            
            test_count = test_count + 1;
        end
    endtask
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        // Initialize test environment
        initialize_test();
        
        // Run test scenarios
        // Start with simple debug test first
        
        //test_simple_debug();

        // test_all_integer();
        
        test_fibonacci();
        
        //test_factorial();
        
        // test_division();
        
        // test_cache_writeback();

        //test_gcd();
        
        // test_load_store();
        
        // test_branch_jump();
        
        // test_hazards();
        
        // test_cache();
        
        // Display final statistics
        #100;
        display_statistics();
        
        // Finish simulation
        $display("\n[%0t] Simulation completed", $time);
        $finish;
    end

    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #1000000; // 1ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $display("Forcing simulation to stop...");
        $finish;
    end

endmodule

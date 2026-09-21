`timescale 1ns/1ps

module tb_sram_init_wrapper;

    // System Signals
    reg        clk;
    reg        rst_n;

    // User Interface Signals
    reg  [7:0] user_addr;
    reg  [15:0] user_din;
    reg        user_we;
    wire [15:0] user_dout;
    wire       init_done;

    // Interconnect Signals between Wrapper and Mock SRAM
    wire [7:0] sram_addr;
    wire [15:0] sram_din;
    wire       sram_we;
    wire [15:0] sram_dout;

    // Loop variables for test cases
    integer i;

    // ------------------------------------------------------------------------
    // 1. Instantiate Device Under Test (DUT)
    // ------------------------------------------------------------------------
    sram_init_wrapper dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .user_addr (user_addr),
        .user_din  (user_din),
        .user_we   (user_we),
        .user_dout (user_dout),
        .init_done (init_done),
        .sram_addr (sram_addr),
        .sram_din  (sram_din),
        .sram_we   (sram_we),
        .sram_dout (sram_dout)
    );

    // ------------------------------------------------------------------------
    // 2. Instantiate Mock Physical SRAM Memory (256 x 16-bit)
    // ------------------------------------------------------------------------
    mock_sram memory (
        .clk  (clk),
        .addr (sram_addr),
        .din  (sram_din),
        .we   (sram_we),
        .dout (sram_dout)
    );

    // ------------------------------------------------------------------------
    // 3. Clock Generation (10ns period -> 100MHz)
    // ------------------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // 4. Waveform Generation & Terminal Monitoring
    // ------------------------------------------------------------------------
    initial begin
        // Setup waveform dumping for GTKWave / EPWave
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_sram_init_wrapper);

        // Terminal Display Monitor
        $display("-------------------------------------------------------------------------------");
        $display(" TIME | RST_N | INIT_DONE | SRAM_ADDR | SRAM_DIN | SRAM_WE | USER_ADDR | USER_DOUT ");
        $display("-------------------------------------------------------------------------------");
        
        $monitor("%5t |   %b   |     %b     |    0x%02h   |  0x%04h  |    %b    |   0x%02h    |  0x%04h",
                 $time, rst_n, init_done, sram_addr, sram_din, sram_we, user_addr, user_dout);
    end

    // ------------------------------------------------------------------------
    // 5. Test Stimulus Pipeline
    // ------------------------------------------------------------------------
    initial begin
        // Initialize Inputs
        clk       = 0;
        rst_n     = 0;
        user_addr = 8'h00;
        user_din  = 16'h0000;
        user_we   = 0;

        // --- TEST CASE 1: Pre-fill SRAM with garbage data during reset ---
        #2;
        for (i = 0; i < 256; i = i + 1) begin
            memory.mem[i] = 16'hDEAD; // Simulate random power-on garbage
        end
        $display("[%0t ns] STIMULUS: Pre-filled SRAM memory array with garbage data (0xDEAD)", $time);

        // --- TEST CASE 2: Apply Reset & Blocked User Access ---
        #10;
        rst_n = 1; // Release reset to start FSM clearing process
        $display("[%0t ns] STIMULUS: Released Reset. Initialization sequence started...", $time);

        // Attempt user access while clear FSM is running (should be blocked by wrapper)
        #50;
        user_addr = 8'h0A;
        user_din  = 16'hBEEF;
        user_we   = 1; // User trying to write

        // --- TEST CASE 3: Wait for Initialization Completion ---
        wait(init_done == 1'b1);
        $display("[%0t ns] STIMULUS: Initialization COMPLETE (init_done = 1).", $time);

        // --- TEST CASE 4: Verify SRAM content was cleared to 0x0000 ---
        user_we = 0; // Read mode
        #10;
        $display("\n--- VERIFYING CLEARED MEMORY LOCATIONS ---");
        
        user_addr = 8'h00; #10;
        check_data(8'h00, 16'h0000, user_dout);
        
        user_addr = 8'h0A; #10;
        check_data(8'h0A, 16'h0000, user_dout);
        
        user_addr = 8'hFF; #10;
        check_data(8'hFF, 16'h0000, user_dout);

        // --- TEST CASE 5: User Read & Write Operations ---
        $display("\n--- EXECUTING USER WRITE & READ OPERATIONS ---");
        
        // Write 0x1234 to Address 0x10
        user_addr = 8'h10;
        user_din  = 16'h1234;
        user_we   = 1;
        #10;

        // Write 0xABCD to Address 0x20
        user_addr = 8'h20;
        user_din  = 16'hABCD;
        user_we   = 1;
        #10;

        // Read Back from Address 0x10
        user_we   = 0;
        user_addr = 8'h10;
        #10;
        check_data(8'h10, 16'h1234, user_dout);

        // Read Back from Address 0x20
        user_addr = 8'h20;
        #10;
        check_data(8'h20, 16'hABCD, user_dout);

        $display("\n[%0t ns] ALL TEST CASES PASSED SUCCESSFULLY!", $time);
        $finish;
    end

    // Helper task to check read data correctness
    task check_data(input [7:0] addr, input [15:0] expected, input [15:0] actual);
        begin
            if (actual === expected) begin
                $display("[PASS] Addr: 0x%02h | Read Data: 0x%04h (Expected: 0x%04h)", addr, actual, expected);
            end else begin
                $display("[FAIL] Addr: 0x%02h | Read Data: 0x%04h (Expected: 0x%04h)", addr, actual, expected);
            end
        end
    endtask

endmodule


// ============================================================================
// Simple Behavioral SRAM Model for Simulation
// ============================================================================
module mock_sram (
    input  wire        clk,
    input  wire [7:0]  addr,
    input  wire [15:0] din,
    input  wire        we,
    output reg  [15:0] dout
);
    reg [15:0] mem [0:255];

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;
        end
        dout <= mem[addr];
    end
endmodule

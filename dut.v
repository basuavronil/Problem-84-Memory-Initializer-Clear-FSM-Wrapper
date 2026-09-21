// ============================================================================
// Module Name:  sram_init_wrapper
// Description:  Wrapper around an SRAM that blocks user access during reset,
//               iterates through all addresses writing 0x00, and asserts
//               init_done to transfer control back to the user system.
// Standard:     Verilog IEEE 1364-2001
// ============================================================================

module sram_init_wrapper (
    // Clock and Reset Signals
    input  wire        clk,        // System Clock
    input  wire        rst_n,      // Active-Low Asynchronous Reset

    // User / System Side Interface (8-bit address = 256 locations, 16-bit data)
    input  wire [7:0]  user_addr,  // User target address
    input  wire [15:0] user_din,   // User write data
    input  wire        user_we,    // User write enable (1 = write, 0 = read)
    output wire [15:0] user_dout,  // User read data output
    output wire        init_done,  // Status flag (1 = ready, 0 = clearing)

    // SRAM Physical Hardware Interface
    output wire [7:0]  sram_addr,  // Multiplexed SRAM address
    output wire [15:0] sram_din,   // Multiplexed SRAM write data
    output wire        sram_we,    // Multiplexed SRAM write enable
    input  wire [15:0] sram_dout   // SRAM read data input
);

    // ------------------------------------------------------------------------
    // Registers and State Variables (0 = CLEAR, 1 = DONE)
    // ------------------------------------------------------------------------
    reg       state;
    reg [7:0] clear_addr;

    // ------------------------------------------------------------------------
    // Sequential Logic: FSM State Transition and Address Counter
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= 1'b0;     // Enter CLEAR state on reset
            clear_addr <= 8'h00;    // Start counter at address 0
        end else begin
            case (state)
                1'b0: begin // CLEAR state
                    if (clear_addr == 8'hFF) begin // Max address (255)
                        state <= 1'b1;              // Move to DONE state
                    end else begin
                        clear_addr <= clear_addr + 1'b1;
                    end
                end

                1'b1: begin // DONE state
                    state <= 1'b1;  // Hold DONE state until next system reset
                end

                default: state <= 1'b0;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Combinational Logic: Control Flag & Input Multiplexers (Gatekeepers)
    // ------------------------------------------------------------------------
    assign init_done = (state == 1'b1);

    // MUX Logic: Route counter during reset, route user during normal operation
    assign sram_addr = (init_done) ? user_addr : clear_addr;
    assign sram_din  = (init_done) ? user_din  : 16'h0000;
    assign sram_we   = (init_done) ? user_we   : 1'b1;

    // Direct Read Data Pass-Through
    assign user_dout = sram_dout;

endmodule

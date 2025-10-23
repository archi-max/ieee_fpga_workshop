// -----------------------------------------------------------------------------
// Sequence Game Top Module with Integrated UART
// -----------------------------------------------------------------------------
// This is the main top-level module that integrates the flattened UART 
// implementation with the sequence game, using the control_with_uart module.
// -----------------------------------------------------------------------------

module sequence_game_top(
    input logic clk,
    input logic reset,
    input logic enter,
    input logic [15:0] sw,  // Changed to 16 bits to use sw[15]
    
    // UART pins (from constraints file)
    input  logic UART_rxd,  // PACKAGE_PIN V12
    output logic UART_txd,  // PACKAGE_PIN U11
    
    // Display outputs
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB,
    output logic [15:0] led
);

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter CLK_FREQ = 100_000_000;  // 100 MHz clock (adjust to your board)
    parameter BAUD = 115_200;          // UART baud rate
    
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // UART interface signals
    logic [7:0] uart_rx_byte;
    logic uart_rx_valid;
    logic uart_rx_ack;
    logic [7:0] uart_tx_byte;
    logic uart_tx_send;
    logic uart_tx_ready;
    
    // Game signals
    logic [7:0] computer_sequence;
    logic sequence_check;
    logic [4:0] state;
    logic reset_db;
    logic enter_db;
    logic [7:0] user_sequence_db;
    
    logic [7:0] score;
    logic [7:0] score_next;
    logic score_ld;
    assign score_next = score + 8'b1;
    
    logic [1:0] mistakes;
    logic [1:0] mistakes_next;
    logic mistakes_ld;
    assign mistakes_next = mistakes + 2'b1;
    
    logic [2:0] index;
    logic [2:0] index_next;
    logic sequence_ld;
    assign index_next = index + 3'b1;
    
    assign led = {sw[15],7'b0,computer_sequence};
    
    // Mode selection (can be controlled by a switch or fixed)
    logic uart_mode;
    assign uart_mode = sw[15];  // Use SW15 to select UART mode
    
    // =========================================================================
    // UART TX Implementation (Flattened)
    // =========================================================================
    typedef enum logic [2:0] {
        TX_IDLE,
        TX_START_BIT,
        TX_DATA_BITS,
        TX_STOP_BIT,
        TX_CLEANUP
    } tx_state_t;
    
    tx_state_t tx_state;
    logic [15:0] tx_clk_cnt;
    logic [2:0] tx_bit_idx;
    logic [7:0] tx_data_latch;
    
    assign uart_tx_ready = (tx_state == TX_IDLE);
    
    always_ff @(posedge clk) begin
        if (reset) begin
            tx_state <= TX_IDLE;
            tx_clk_cnt <= '0;
            tx_bit_idx <= 3'd0;
            tx_data_latch <= 8'h00;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    if (uart_tx_send) begin
                        tx_data_latch <= uart_tx_byte;
                        tx_state <= TX_START_BIT;
                        tx_clk_cnt <= CLKS_PER_BIT - 1;
                        tx_bit_idx <= 3'd0;
                    end
                end
                
                TX_START_BIT: begin
                    if (tx_clk_cnt == 0) begin
                        tx_state <= TX_DATA_BITS;
                        tx_clk_cnt <= CLKS_PER_BIT - 1;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt - 1;
                    end
                end
                
                TX_DATA_BITS: begin
                    if (tx_clk_cnt == 0) begin
                        if (tx_bit_idx == 7) begin
                            tx_state <= TX_STOP_BIT;
                            tx_clk_cnt <= CLKS_PER_BIT - 1;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 3'd1;
                            tx_clk_cnt <= CLKS_PER_BIT - 1;
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt - 1;
                    end
                end
                
                TX_STOP_BIT: begin
                    if (tx_clk_cnt == 0) begin
                        tx_state <= TX_CLEANUP;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt - 1;
                    end
                end
                
                TX_CLEANUP: begin
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end
    
    // TX Output
    always_comb begin
        case (tx_state)
            TX_START_BIT: UART_txd = 1'b0;
            TX_DATA_BITS: UART_txd = tx_data_latch[tx_bit_idx];
            default:      UART_txd = 1'b1;
        endcase
    end
    
    // =========================================================================
    // UART RX Implementation 
    // =========================================================================
    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START_HALF,
        RX_SAMPLE_BITS,
        RX_STOP_BIT,
        RX_DONE
    } rx_state_t;
    
    rx_state_t rx_state;
    logic [15:0] rx_clk_cnt;
    logic [2:0] rx_bit_idx;
    logic [7:0] rx_shift_reg;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_state <= RX_IDLE;
            rx_clk_cnt <= '0;
            rx_bit_idx <= 3'd0;
            rx_shift_reg <= 8'h00;
            uart_rx_byte <= 8'h00;
            uart_rx_valid <= 1'b0;
        end else begin
            // Clear valid flag if acknowledged
            if (uart_rx_ack) begin
                uart_rx_valid <= 1'b0;
            end
            
            case (rx_state)
                RX_IDLE: begin
                    if (UART_rxd == 1'b0) begin
                        rx_state <= RX_START_HALF;
                        rx_clk_cnt <= HALF_BIT_CLKS;
                    end
                end
                
                RX_START_HALF: begin
                    if (rx_clk_cnt == 0) begin
                        rx_state <= RX_SAMPLE_BITS;
                        rx_clk_cnt <= CLKS_PER_BIT - 1;
                        rx_bit_idx <= 3'd0;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt - 1;
                    end
                end
                
                RX_SAMPLE_BITS: begin
                    if (rx_clk_cnt == 0) begin
                        rx_shift_reg <= {UART_rxd, rx_shift_reg[7:1]};
                        
                        if (rx_bit_idx == 3'd7) begin
                            rx_state <= RX_STOP_BIT;
                            rx_clk_cnt <= CLKS_PER_BIT - 1;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 3'd1;
                            rx_clk_cnt <= CLKS_PER_BIT - 1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt - 1;
                    end
                end
                
                RX_STOP_BIT: begin
                    if (rx_clk_cnt == 0) begin
                        rx_state <= RX_DONE;
                        uart_rx_byte <= rx_shift_reg;
                        uart_rx_valid <= 1'b1;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt - 1;
                    end
                end
                
                RX_DONE: begin
                    rx_state <= RX_IDLE;
                end
            endcase
        end
    end
    
    // =========================================================================
    // User Sequence Handling
    // =========================================================================
    logic [7:0] uart_user_sequence;
    
    // Process UART bytes for user sequence
    always_ff @(posedge clk) begin
        if (reset) begin
            uart_user_sequence <= 8'h00;
        end else begin
            // If we receive a byte that's not a command, use it as sequence
            if (uart_rx_valid && uart_mode) begin
                // Check if it's a digit '0'-'7' to toggle bits
                if (uart_rx_byte >= 8'h30 && uart_rx_byte <= 8'h37) begin
                    logic [2:0] bit_num;
                    bit_num = uart_rx_byte[2:0];
                    uart_user_sequence[bit_num] <= ~uart_user_sequence[bit_num];
                end
                // Or accept direct byte value for sequence
                else if (uart_rx_byte != 8'h65 && uart_rx_byte != 8'h45 &&  // not 'e'/'E'
                         uart_rx_byte != 8'h72 && uart_rx_byte != 8'h52) begin  // not 'r'/'R'
                    uart_user_sequence <= uart_rx_byte;
                end
            end
        end
    end
    
    // =========================================================================
    // Input Debouncing (CRITICAL - THIS WAS MISSING!)
    // =========================================================================
    sync_debounce reset_debounce(
        .clk(clk),
        .d(reset),
        .q(reset_db)
    );
    
    sync_debounce enter_debounce(
        .clk(clk),
        .d(enter),
        .q(enter_db)
    );
    
    // Debounce switches SW0-SW7 for user sequence
    generate
        genvar i;
        for (i = 0; i < 8; i++) begin : user_seq_debounce
            sync_debounce switch_debounce(
                .clk(clk),
                .d(sw[i]),
                .q(user_sequence_db[i])
            );
        end
    endgenerate
    
    // =========================================================================
    // User Sequence Handling - HYBRID MODE
    // =========================================================================
    // In UART mode (SW15=ON):
    // - Use physical switches SW0-SW7 to set the sequence
    // - Use UART only for control: 'e' to enter, 'r' to reset
    
    // Select user sequence - always use physical switches for sequence input
    logic [7:0] final_user_sequence;
    assign final_user_sequence = user_sequence_db;  // Always use switches for sequence
    
    // =========================================================================
    // Game Control with UART
    // =========================================================================
    control_with_uart control_unit(
        .clk(clk),
        .reset(reset_db),
        .enter(enter_db),
        .sequence_check(sequence_check),
        .mistakes(mistakes),
        .score_ld(score_ld),
        .mistakes_ld(mistakes_ld),
        .sequence_ld(sequence_ld),
        .state_out(state),
        
        // UART interface
        .uart_mode_enable(uart_mode),
        .uart_rx_valid(uart_rx_valid),
        .uart_rx_byte(uart_rx_byte),
        .uart_rx_ack(uart_rx_ack),
        .uart_tx_send(uart_tx_send),
        .uart_tx_byte(uart_tx_byte),
        .uart_tx_ready(uart_tx_ready)
    );
    
    // =========================================================================
    // Game Logic Modules
    // =========================================================================
    sequence_generator seq_gen(
        .index(index),
        .seq_out(computer_sequence)
    );
    
    sequence_checker check(
        .generated(computer_sequence),
        .input_sequence(final_user_sequence),
        .correct(sequence_check)
    );
    
    // Registers
    load_reg #(.WIDTH(8)) score_reg(
        .clk(clk),
        .reset(reset_db),
        .data_in(score_next),
        .ld(score_ld),
        .data(score)
    );
    
    load_reg #(.WIDTH(2)) mistakes_reg(
        .clk(clk),
        .reset(reset_db),
        .data_in(mistakes_next),
        .ld(mistakes_ld),
        .data(mistakes)
    );
    
    load_reg #(.WIDTH(3)) index_reg(
        .clk(clk),
        .reset(reset_db),
        .data_in(index_next),
        .ld(sequence_ld),
        .data(index)
    );
    
    // =========================================================================
    // Display Controllers
    // =========================================================================
    HexDriver hexA(
        .clk(clk),
        .reset(reset_db),
        .in({4'h0, 4'h0, score[7:4], score[3:0]}),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    HexDriver hexB(
        .clk(clk),
        .reset(reset_db),
        .in({4'h0, 4'h0, 4'h0, state[3:0]}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );

endmodule

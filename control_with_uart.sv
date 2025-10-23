module control_with_uart (
    input logic clk,
    input logic reset,
    input logic enter,
    input logic sequence_check,
    input logic [1:0] mistakes,
    output logic score_ld,
    output logic mistakes_ld,
    output logic sequence_ld,
    output logic [4:0] state_out,
    
    // =========================================================================
    // UART INTERFACE SECTION - Added for UART communication
    // =========================================================================
    // Add these ports to enable UART communication from control module
    input logic uart_mode_enable,       // Set to 1 to use UART instead of buttons
    
    // UART receive interface
    input logic uart_rx_valid,          // New byte received from UART
    input logic [7:0] uart_rx_byte,     // The received byte
    output logic uart_rx_ack,           // Acknowledge the received byte
    
    // UART transmit interface  
    output logic uart_tx_send,          // Request to send a byte
    output logic [7:0] uart_tx_byte,    // Byte to send
    input logic uart_tx_ready           // UART is ready to send
    // =========================================================================
);

    logic enter_prev;
    logic enter_edge;
    
    // Original state definitions - UNCHANGED
    enum logic [4:0] {
		halted = 5'h0,
        generate_sequence = 5'h1,
        pause = 5'h2,
        check_sequence = 5'h3,
        update_score = 5'h4,
        done = 5'h5
    } state, state_nxt;   // internal state logic

    assign state_out = state;
    
    // Original edge detection for enter button - UNCHANGED
    always_ff @(posedge clk) begin
        if (reset)
            enter_prev <= 1'b0;
        else
            enter_prev <= enter;
    end
    
    assign enter_edge = enter & ~enter_prev;  // Rising edge detection
    
    // =========================================================================
    // UART HELPER SECTION - Functions to send/receive via UART
    // =========================================================================
    
    // Variables for UART message handling
    logic uart_enter_received;     // Flag when 'e' or 'E' received via UART
    logic [7:0] uart_user_input;   // Store received user input
    logic sending_message;          // Flag indicating we're sending a message
    logic [3:0] msg_char_index;     // Index of current character being sent
    
    // Simple message buffers for common messages
    logic [7:0] prompt_msg [0:7];  // "Enter: " message
    logic [7:0] correct_msg [0:7]; // "OK!" message
    logic [7:0] wrong_msg [0:7];   // "NO!" message
    
    // Initialize messages
    initial begin
        // "Enter: "
        prompt_msg[0] = 8'h45; // 'E'
        prompt_msg[1] = 8'h6E; // 'n'
        prompt_msg[2] = 8'h74; // 't'
        prompt_msg[3] = 8'h65; // 'e'
        prompt_msg[4] = 8'h72; // 'r'
        prompt_msg[5] = 8'h3A; // ':'
        prompt_msg[6] = 8'h20; // ' '
        prompt_msg[7] = 8'h0A; // '\n'
        
        // "OK!\n"
        correct_msg[0] = 8'h4F; // 'O'
        correct_msg[1] = 8'h4B; // 'K'
        correct_msg[2] = 8'h21; // '!'
        correct_msg[3] = 8'h0A; // '\n'
        correct_msg[4] = 8'h00; // null
        
        // "NO!\n"
        wrong_msg[0] = 8'h4E; // 'N'
        wrong_msg[1] = 8'h4F; // 'O'
        wrong_msg[2] = 8'h21; // '!'
        wrong_msg[3] = 8'h0A; // '\n'
        wrong_msg[4] = 8'h00; // null
    end
    
    // Process received UART bytes
    always_ff @(posedge clk) begin
        if (reset) begin
            uart_enter_received <= 1'b0;
            uart_user_input <= 8'h00;
            uart_rx_ack <= 1'b0;
        end else begin
            uart_enter_received <= 1'b0;  // Clear flag each cycle
            uart_rx_ack <= 1'b0;
            
            // Check for new UART input
            if (uart_rx_valid && !uart_rx_ack) begin
                uart_rx_ack <= 1'b1;  // Acknowledge receipt
                
                // Check what was received
                if (uart_rx_byte == 8'h65 || uart_rx_byte == 8'h45) begin  // 'e' or 'E'
                    uart_enter_received <= 1'b1;
                end else begin
                    uart_user_input <= uart_rx_byte;  // Store as user sequence input
                end
            end
        end
    end
    
    // Signals to trigger message sending
    logic start_prompt_msg;
    logic start_correct_msg; 
    logic start_wrong_msg;
    
    // Track which message we're sending
    typedef enum logic [1:0] {
        MSG_NONE = 2'b00,
        MSG_PROMPT = 2'b01,
        MSG_CORRECT = 2'b10,
        MSG_WRONG = 2'b11
    } msg_type_t;
    
    msg_type_t current_msg_type;
    
    // Send message state machine (runs in parallel)
    always_ff @(posedge clk) begin
        if (reset) begin
            sending_message <= 1'b0;
            msg_char_index <= 4'd0;
            uart_tx_send <= 1'b0;
            uart_tx_byte <= 8'h00;
            current_msg_type <= MSG_NONE;
        end else begin
            uart_tx_send <= 1'b0;
            
            // Check if we should start a new message (edge detection on triggers)
            if (!sending_message) begin
                if (start_prompt_msg) begin
                    sending_message <= 1'b1;
                    msg_char_index <= 4'd0;
                    current_msg_type <= MSG_PROMPT;
                end else if (start_correct_msg) begin
                    sending_message <= 1'b1;
                    msg_char_index <= 4'd0;
                    current_msg_type <= MSG_CORRECT;
                end else if (start_wrong_msg) begin
                    sending_message <= 1'b1;
                    msg_char_index <= 4'd0;
                    current_msg_type <= MSG_WRONG;
                end
            end
            
            // Send characters of the current message
            if (sending_message && uart_tx_ready && !uart_tx_send) begin
                case (current_msg_type)
                    MSG_PROMPT: begin
                        if (msg_char_index < 8) begin
                            uart_tx_byte <= prompt_msg[msg_char_index];
                            uart_tx_send <= 1'b1;
                            msg_char_index <= msg_char_index + 4'd1;
                        end else begin
                            sending_message <= 1'b0;
                            current_msg_type <= MSG_NONE;
                        end
                    end
                    
                    MSG_CORRECT: begin
                        if (msg_char_index < 4 && correct_msg[msg_char_index] != 8'h00) begin
                            uart_tx_byte <= correct_msg[msg_char_index];
                            uart_tx_send <= 1'b1;
                            msg_char_index <= msg_char_index + 4'd1;
                        end else begin
                            sending_message <= 1'b0;
                            current_msg_type <= MSG_NONE;
                        end
                    end
                    
                    MSG_WRONG: begin
                        if (msg_char_index < 4 && wrong_msg[msg_char_index] != 8'h00) begin
                            uart_tx_byte <= wrong_msg[msg_char_index];
                            uart_tx_send <= 1'b1;
                            msg_char_index <= msg_char_index + 4'd1;
                        end else begin
                            sending_message <= 1'b0;
                            current_msg_type <= MSG_NONE;
                        end
                    end
                    
                    default: begin
                        sending_message <= 1'b0;
                        current_msg_type <= MSG_NONE;
                    end
                endcase
            end
        end
    end
    
    // =========================================================================
    // END OF UART HELPER SECTION
    // =========================================================================
    
    // Original control outputs logic - UNCHANGED
    always_comb
    begin
        score_ld = 1'b0;
        mistakes_ld = 1'b0;
        sequence_ld = 1'b0;

        case (state)
            halted: ;

            generate_sequence:
                sequence_ld = 1'b1;
            pause:;
                // enter_pressed = 1'b0;
            check_sequence: ;

            update_score: 
                if(sequence_check == 1'b1)
                    score_ld = 1'b1;
                else
                    mistakes_ld = 1'b1;
       endcase

    end

    // Original state register - UNCHANGED
    always_ff @ (posedge clk) // set next state
	begin
		if (reset) 
			state <= halted;
		else 
			state <= state_nxt;
	end

    // Modified state transition logic - Original structure preserved
    always_comb // determine next state
    begin
        if (reset)
            state_nxt = halted;
        
        state_nxt = state;
        
        // Default: no message triggers
        start_prompt_msg = 1'b0;
        start_correct_msg = 1'b0;
        start_wrong_msg = 1'b0;
        
        case(state)
            halted: 
                state_nxt = generate_sequence;

            generate_sequence: begin
                state_nxt = pause;
                // UART ADDITION: Trigger prompt message when entering pause
                if (uart_mode_enable && uart_tx_ready && !sending_message) begin
                    start_prompt_msg = 1'b1;
                end
            end
                
            pause: begin
                // MODIFIED: Check both physical enter and UART enter
                if (uart_mode_enable) begin
                    // In UART mode, wait for UART enter command
                    if (uart_enter_received) begin
                        state_nxt = check_sequence;
                    end else begin
                        state_nxt = pause;
                    end
                end else begin
                    // Original physical button logic
                    if (enter_edge) begin
                        state_nxt = check_sequence;
                    end else begin
                        state_nxt = pause;
                    end
                end
            end
                
            check_sequence:
                state_nxt = update_score;
                
            update_score: begin
                // UART ADDITION: Trigger result message
                if (uart_mode_enable && uart_tx_ready && !sending_message) begin
                    if (sequence_check)
                        start_correct_msg = 1'b1;
                    else
                        start_wrong_msg = 1'b1;
                end
                
                // Original transition logic
                if(mistakes == 2'h3)
                    state_nxt = done;
                else
                    state_nxt = generate_sequence;
            end
                
            done: begin
                // MODIFIED: Check both physical enter and UART restart
                if (uart_mode_enable) begin
                    // In UART mode, could wait for 'r' to restart
                    if (uart_rx_valid && (uart_rx_byte == 8'h72 || uart_rx_byte == 8'h52)) // 'r' or 'R'
                        state_nxt = halted;
                    else
                        state_nxt = done;
                end else begin
                    // Original physical button logic
                    if (enter_edge)
                        state_nxt = halted;
                    else
                        state_nxt = done;
                end
            end
                
            default: ;
        endcase
    end

endmodule

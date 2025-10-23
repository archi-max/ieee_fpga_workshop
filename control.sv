module control (
    input logic clk,
    input logic reset,
    input logic enter,
    input logic sequence_check,
    input logic [1:0] mistakes,
    output logic score_ld,
    output logic mistakes_ld,
    output logic sequence_ld,
    output logic [4:0] state_out
);

    logic enter_prev;
    logic enter_edge;
    
    enum logic [4:0] {
		halted = 5'h0,
        generate_sequence = 5'h1,
        pause = 5'h2,
        check_sequence = 5'h3,
        update_score = 5'h4,
        done = 5'h5
    } state, state_nxt;   // internal state logic

    assign state_out = state;
    
    // Edge detection for enter button
    always_ff @(posedge clk) begin
        if (reset)
            enter_prev <= 1'b0;
        else
            enter_prev <= enter;
    end
    
    assign enter_edge = enter & ~enter_prev;  // Rising edge detection
    
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



    always_ff @ (posedge clk) // set next state
	begin
		if (reset) 
			state <= halted;
		else 
			state <= state_nxt;
	end

    always_comb // deermine next state
    begin
        if (reset)
            state_nxt = halted;
        
        state_nxt = state;
        case(state)
            halted: 
                state_nxt = generate_sequence;

            generate_sequence:
                state_nxt = pause;
            pause:
                if(enter_edge) begin
                    state_nxt = check_sequence;
                end
                else   
                    state_nxt = pause;
            check_sequence:
                state_nxt = update_score;
            update_score:
                if(mistakes == 2'h3)
                    state_nxt = done;
                else
                    state_nxt = generate_sequence;
            done:
                if(enter_edge)
                    state_nxt = halted;
                else
                    state_nxt = done;
            default: ;
        endcase
    end

endmodule

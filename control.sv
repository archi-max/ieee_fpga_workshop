module control (
    input logic clk,
    input logic [1:0] mistakes,
    output logic [7:0] score
);

    always_comb
    begin
        score_ld = 1'b0;
        mistakes_ld = 1'b0;
        sequence_ld = 1'b0;

        case (state)
            halted: ;

            generate_sequence:
                sequence_ld = 1'b1;

            pause: 

            check_sequence:

            update_score:
                if(sequence_check == 1'b1)
                    score_ld = 1'b1;
                else
                    mistakes_ld = 1'b1;

    end

	enum logic [4:0] {
		halted,
        generate_sequence,
        pause,
        check_sequence,
        update_score
	} state, state_nxt;   // internal state logic

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
            halted: ;

            generate_sequence:
                state_nxt = pause;
            pause:
                if(enter)
                    state_nxt = check_sequence;
                else   
                    state_nxt = pause;
            check_sequence:
                state_nxt = update_score;
            update_score:
                if(mistakes == 2'h3)
                    state_nxt = done;
                else
                    state_nxt = generate_sequence;
            default: ;
        endcase
    end

endmodule
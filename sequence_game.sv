module sequence_game(
    input logic clk,
    input logic reset,
    input logic enter,
    input logic [7:0] sw,
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB,
    output logic [7:0] led
);

logic [7:0] computer_sequence;
logic sequence_check;

logic [4:0] state;

// Debounced signals
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

assign led = computer_sequence;

// Debounce buttons and switches
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

// Debounce all 8 user sequence switches
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

control control_unit(
    .clk(clk),
    .reset(reset_db),
    .enter(enter_db),
    .sequence_check(sequence_check),
    .mistakes(mistakes),
    .score_ld(score_ld),
    .mistakes_ld(mistakes_ld),
    .sequence_ld(sequence_ld),
    .state_out(state)
);

sequence_generator seq_gen(
    .index(index),
    .seq_out(computer_sequence)
);

sequence_checker check(
    .generated(computer_sequence),
    .input_sequence(user_sequence_db),
    .correct(sequence_check)
);

// Registers to hold score and mistakes
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

// I/O Control (Switches, Buttons, Hex Displays)
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

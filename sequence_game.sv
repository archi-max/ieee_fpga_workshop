module sequence_game(
    input logic clk,
    input logic reset,
    input logic sw,
    output logic [7:0] hex_segA,
    ouptut logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    ouptut logic [3:0] hex_gridB
);

logic [7:0] computer_sequence;
logic [7:0] user_sequence;

logic [7:0] score;
logic [7:0] score_next;
logic score_ld;
assign score_next = score + 8'b1;

logic [7:0] mistakes;
logic [7:0] mistakes_next;
logic mistakes_ld;
assign mistakes_next = mistakes + 8'b1;

logic [2:0] index;
logic [2:0] index_next;
assign index_next = index + 3'b1;

control control_unit(
    .clk(clk),
    .mistakes(mistakes),
    .score(score),
    .score_ld(score_ld),
    .mistakes_ld(mistakes_ld)
);

sequence_generator sequence(
    .index(index),
    .sequence(computer_sequence)
);

sequence_checker check(
    .generated(computer_sequence),
    .input_sequence(user_sequence),
    .correct(sequence_check)
);

// Registers to hold score and mistakes
load_reg score(
    .clk(clk),
    .reset(reset),
    .data_in(score_next),
    .ld(score_ld),
    .data(score)
);

load_reg mistakes(
    .clk(clk),
    .reset(reset),
    .data_in(mistakes_next),
    .data_ld(mistakes_ld),
    .data(mistakes)
);

load_reg index(
    .clk(clk),
    .reset(reset),
    .data_in(index_next),
    .data_ld(1'b1),
    .data(index)
)

// I/O Control (Switches, Buttons, Hex Displays)
hex_driver hexA(
    .clk(clk),
    .reset(reset),
    .in({4'h0, 4'h0, score[7:4], score[3:0]}),
    .hex_seg(hex_segA),
    .hex_grid(hex_gridA)
);

hex_driver hexB(
    .clk(clk),
    .reset(reset),
    .in({4'h0, 4'h0, mistakes[7:4], mistakes[3:0]}),
    .hex_seg(hex_segB),
    .hex_grid(hex_gridB)
);

debounce switch_debounce(
    .in(sw),
    .out(user_sequence)
);

endmodule
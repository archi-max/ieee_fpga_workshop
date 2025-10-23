module sequence_generator(
    input logic [2:0] index,
    output logic [8:0] sequence
);

logic [7:0] sequences[0:7];

assign sequences[0] = 8'b11110111;
assign sequences[1] = 8'b00000001;
assign sequences[2] = 8'b10010101;
assign sequences[3] = 8'b01010101;
assign sequences[4] = 8'b10101011;
assign sequences[5] = 8'b10111000;
assign sequences[6] = 8'b10111011;
assign sequences[7] = 8'b10111110;

assign sequence = sequences[index];

endmodule;
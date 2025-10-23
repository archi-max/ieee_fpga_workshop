module sequence_checker(
    input logic [7:0] generated,
    input logic [7:0] input_sequence,
    output logic correct
);

assign correct = (input_sequence == generated);

endmodule
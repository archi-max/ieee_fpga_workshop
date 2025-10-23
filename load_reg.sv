module load_reg #(
    parameter WIDTH = 8
)(
    input logic clk,
    input logic reset,
    input logic [WIDTH-1:0] data_in,
    input logic ld,
    output logic [WIDTH-1:0] data
);

    always_ff @ (posedge clk)
    begin
        if(reset == 1'b1)
        begin
            data <= {WIDTH{1'b0}};
        end
        else if(ld == 1'b1)
        begin
            data <= data_in;
        end
    end

endmodule

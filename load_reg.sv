module load_reg(
    input logic clk,
    input logic reset,
    input logic [7:0] data_in,
    input logic ld,
    output logic [7:0] data
);

    always_ff @ (posedge clk)
    begin
        if(reset == 1'b1)
        begin
            data <= 8'h00;
        end
        else if(ld == 1'b1)
        begin
            data <= data_in
        end
    end

endmodule
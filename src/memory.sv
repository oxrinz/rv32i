module memory(
    input wire clk,
    input wire [31:0] addr,
    input wire [31:0] data,
    input wire read,
    input wire write,
    output reg [31:0] data_out
);
    reg [31:0] memory[0:1023];

    always @(*) begin
        if (read == 1) begin
            data_out = memory[addr];
        end

        if (write == 1) begin 
            memory[addr] = data;
        end
    end

endmodule 
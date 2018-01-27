module ram(
    input clk,
    input [12:0] address,
    input w_en,
    input [7:0] din,
    output reg [7:0] dout
    );

    parameter RAM_FILENAME = "../roms/ram.hex";

    reg [7:0] ram[0:8191];

    initial
        $readmemh(RAM_FILENAME, ram, 0, 8191);

    always @(posedge clk)
    begin
        dout <= ram[address];
        if (w_en) ram[address] <= din;
    end

endmodule
     

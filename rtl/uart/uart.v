`include "./async_tx_rx.v"

module uart(
    input clk,

    input enable,
    input [1:0] address,
    input w_en,
    input [7:0] din,
    output reg [7:0] dout,

    input uart_rx,
    output uart_tx,
    output uart_cts,
    output reg [7:0] led
    );

    parameter ClkFrequency = 25000000;	// 25MHz
    parameter Baud = 115200;
    parameter Oversampling = 8;

    reg uart_tx_stb;
    reg [7:0] uart_tx_byte;
    wire uart_tx_status;

    async_transmitter #(ClkFrequency, Baud) my_tx (
        .clk(clk),
        .TxD_start(uart_tx_stb),
        .TxD_data(uart_tx_byte),
        .TxD(uart_tx),
        .TxD_busy(uart_tx_status)
        );

    wire uart_rx_stb, rx_idle, rx_end;
    wire [7:0] rx_data;
    reg uart_rx_status, uart_rx_ack;
    reg [7:0] uart_rx_byte;

    async_receiver #(ClkFrequency, Baud, Oversampling) my_rx(
        .clk(clk),
        .RxD(uart_rx),
        .RxD_data_ready(uart_rx_stb),
        .RxD_data(rx_data),
        .RxD_idle(rx_idle),
        .RxD_endofpacket(rx_end)
        );

    always @(posedge clk)
    begin
        // new byte from RX, check register is clear and CPU has seen 
        // previous byte, otherwise we ignore the new data
        if (uart_rx_stb && ~uart_rx_status)
        begin
            uart_rx_status <= 'b1;
            uart_rx_byte <= rx_data;
        end

        // clear the rx status flag on ack from CPU
        if (uart_rx_ack)
            uart_rx_status <= 'b0;
    end

    assign uart_cts = ~rx_idle || uart_rx_status;

    localparam UART_RX   = 2'b00;
    localparam UART_RXCR = 2'b01;
    localparam UART_TX   = 2'b10;

    // Handle Register
    always @(posedge clk)
    begin
        uart_tx_stb <= 0;
        uart_rx_ack <= 0; 

        led[7] <= uart_rx_status;

        if (enable)
        begin
            case (address)

            UART_TX:
            begin
                // UART TX - 0xD012
                if (w_en)
                begin
                    // Apple 1 terminal only uses 7 bits, MSB indicates
                    // terminal has ack'd RX
                    if (~uart_tx_status)
                    begin
                        uart_tx_byte <= {1'b0, din[6:0]};
                        uart_tx_stb <= 1;
                    end
                end
                else
                    dout <= {uart_tx_status, 7'd0};
            end

            UART_RXCR:
            begin
                // UART RX CR - 0xD011
                if (~w_en)
                    dout <= {uart_rx_status, 7'b0};
            end

            UART_RX:
            begin
                // UART RX - 0xD010
                if (~w_en)
                begin
                    dout <= {uart_rx_status, uart_rx_byte[6:0]};
                    uart_rx_ack <= 1'b1;
                    led[6:0] <= uart_rx_byte[6:0];
                end
            end
            endcase
        end
    end
endmodule

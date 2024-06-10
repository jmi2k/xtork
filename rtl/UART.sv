module UART #(
	parameter
		WORD_BITS
) (
	input wire                clock,
	output wire               tx,
	output wire               rx,

	input wire[1:0]           addr,
	input wire[WORD_BITS-1:0] in,
	output bit[WORD_BITS-1:0] out,
	input wire                select,
	input wire                write,
	input wire                strobe,
	output bit                ack = 0,
	output bit                retry = 0
);

	bit[WORD_BITS-1:0] divisor = 0;
	wire[7:0] data;
	wire busy, full;

	always @(posedge clock) begin

		// MMIO responds in 1 cycle
		ack <= strobe;

		out <=
			(addr == 0 ?    data      : 0) |
			(addr == 1 ?    divisor   : 0) |
			(addr == 2 ?    busy      : 0) |
			(addr == 3 ?    full      : 0);

	end

`define reading(a)   (addr == a && strobe && select && !write)
`define writing(a)   (addr == a && strobe && select &&  write)

	always @(posedge clock) if (`writing(1))
		divisor <= in;

	UART_TX #(
		.WORD_BITS(WORD_BITS)
	) tx_side(
		.clock,
		.fire(`writing(0)),
		.tx,
		.busy,
		.data(in),
		.divisor
	);

	UART_RX #(
		.WORD_BITS(WORD_BITS)
	) rx_side(
		.clock,
		.clear(`reading(0)),
		.rx,
		.full,
		.data,
		.divisor
	);

`undef writing
`undef reading

endmodule

module UART_TX #(
	parameter
		WORD_BITS
) (
	input wire                clock,
	input wire                fire,
	output bit                tx = 1,
	output wire               busy,
	input wire[7:0]           data,
	input wire[WORD_BITS-1:0] divisor
);

	bit[WORD_BITS-1:0] counter;
	bit[3:0] position = 0;
	bit[8:0] bits = 0;

	assign busy = |position;

	always @(posedge clock) begin
		tx <= !bits[0];

		if (!busy) begin
			counter <= divisor-1;

			if (fire) begin
				bits <= ~(data << 1);
				position <= 1+8+1;
			end

		end else if (!counter) begin
			position <= position-1;
			bits <= bits >> 1;
			counter <= divisor-1;

		end else
			counter <= counter-1;

	end

endmodule

module UART_RX #(
	parameter
		WORD_BITS,

		WINDOW_BITS = 3
) (
	input wire                clock,
	input wire                clear,
	input wire                rx,
	output bit                full = 0,
	output bit[7:0]           data = 0,
	input wire[WORD_BITS-1:0] divisor
);

	bit[WORD_BITS-1:0]
		counter = 0,
		ones    = 0,
		zeros   = 0;

	bit[WINDOW_BITS-1:0] window_ = 0;
	bit[3:0] position = 0;
	bit[8:0] bits = 0;

	wire
		busy      = |position,
		keep_full = full && !clear;

	wire[31:0]
		next_ones  = ones  + !window_,
		next_zeros = zeros + &window_;

	wire[3:0] next_position = position-1;
	wire[8:0] next_bits = { next_ones > next_zeros, bits[8:1] };

	always @(posedge clock) begin
		window_ <= { window_, !rx };

		if (!busy) begin
			full <= keep_full;

			if (&window_)
				position <= 1+8+1;

			counter <= divisor-1 - WINDOW_BITS;
			bits <= 0;
			ones <= 0;
			zeros <= 0;

		end else if (!counter) begin
			full <= keep_full || !next_position;

			position <= next_position;
			counter <= divisor-1;
			bits <= next_bits;
			ones <= 0;
			zeros <= 0;

			if (!next_position)
				data <= next_bits;

		end else begin
			full <= keep_full;

			counter <= counter-1;
			ones <= next_ones;
			zeros <= next_zeros;

		end

	end

endmodule

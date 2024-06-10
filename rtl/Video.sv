module Video #(
	parameter
		BYTE_BITS,
		BYTES_PER_WORD,

        DIVISOR = 4,
		W       = 640,
		H       = 480,
		H_FP    = 16,
		H_SYNC  = 96,
		H_BP    = 48,
		V_FP    = 10,
		V_SYNC  = 2,
		V_BP    = 33,

	localparam
        NUM_WORDS = W/DIVISOR * H/DIVISOR,
		WORD_BITS = BYTE_BITS * BYTES_PER_WORD,
        ADDR_BITS = $clog2(NUM_WORDS),
		W_FULL    = W + H_BP + H_SYNC + H_FP,
		H_FULL    = H + V_BP + V_SYNC + V_FP,
		X_BITS    = $clog2(W_FULL),
		Y_BITS    = $clog2(H_FULL)
) (
	input wire                     pixel_clock,
	output wire RGB_444            pixel,
	output bit[1:0]                blank,
	output bit[1:0]                sync,

	input wire                     bus_clock,
	input wire[ADDR_BITS-1:0]      addr,
	input wire[WORD_BITS-1:0]      in,
	output wire[WORD_BITS-1:0]     out,
	input wire[BYTES_PER_WORD-1:0] select,
	input wire                     write,
	input wire                     strobe,
	output wire                    ack,
    output wire                    retry
);

    wire[WORD_BITS-1:0] color;
	wire[X_BITS-1:0] x;
	wire[Y_BITS-1:0] y;

	wire[1:0]
        blank_0,
        sync_0;

	assign pixel = blank ? 'h000 : color;

	always @(posedge pixel_clock) begin
		blank <= blank_0;
		sync <= sync_0;

	end

	BRAM #(
		.NUM_WORDS(W/DIVISOR * H/DIVISOR),
		.BYTE_BITS(BYTE_BITS),
		.BYTES_PER_WORD(BYTES_PER_WORD)
    ) frame(
		.clock_1(pixel_clock),
		.addr_1(W/DIVISOR * (y/DIVISOR) + x/DIVISOR),
		.out_1(color),
		.write_1(0),
		.select_1(-1),
		.strobe_1(1),

		.clock_2(bus_clock),
		.addr_2(addr),
		.in_2(in),
		.out_2(out),
		.write_2(write),
		.select_2(select),
		.strobe_2(strobe),
		.ack_2(ack),
        .retry_2(retry)
	);

	Video_Timing #(
		.W(W),
		.H(H),
		.H_FP(H_FP),
		.H_SYNC(H_SYNC),
		.H_BP(H_BP),
		.V_FP(V_FP),
		.V_SYNC(V_SYNC),
		.V_BP(V_BP)
	) timing(
		.clock(pixel_clock),
		.blank(blank_0),
		.sync(sync_0),
		.x,
		.y
	);

endmodule

module Video_Timing #(
	parameter
		W,
		H,
		H_FP,
		H_SYNC,
		H_BP,
		V_FP,
		V_SYNC,
		V_BP,

	localparam
		W_FULL = W + H_BP + H_SYNC + H_FP,
		H_FULL = H + V_BP + V_SYNC + V_FP,

		X_BITS = $clog2(W_FULL),
		Y_BITS = $clog2(H_FULL)
) (
	input wire             clock,
	output wire[1:0]       blank,
	output wire[1:0]       sync,
	output bit[X_BITS-1:0] x,
	output bit[Y_BITS-1:0] y
);

	wire
		x_maxed = x == W_FULL-1,
		y_maxed = y == H_FULL-1;

	assign
		blank[0] = x >= W,
		blank[1] = y >= H,
		sync[0]  = x >= W+H_FP && x < W_FULL-H_BP,
		sync[1]  = y >= H+V_FP && y < H_FULL-V_BP;

	always @(posedge clock)

		if (x_maxed) begin
			x <= 0;
			y <= y_maxed ? 0 : y+1;

		end else
			x <= x+1;

endmodule

module Video #(
	parameter
		BYTE_BITS,
		BYTES_PER_WORD,

		ATLAS_W = 32,
		ATLAS_H = 32,
		FRAME_W = 640,
		FRAME_H = 400,
		H_PAD   = 0,
		V_PAD   = 40,
		H_FP    = 16,
		H_SYNC  = 96,
		H_BP    = 48,
		V_FP    = 10,
		V_SYNC  = 2,
		V_BP    = 33,

		DIVISOR = 16,

	localparam
		NUM_ATLAS_WORDS = ATLAS_W * ATLAS_H,
		ATLAS_ADDR_BITS = $clog2(NUM_ATLAS_WORDS),
		ATLAS_X_BITS    = $clog2(ATLAS_W),
		ATLAS_Y_BITS    = $clog2(ATLAS_H),

		NUM_FRAME_WORDS = FRAME_W/DIVISOR * FRAME_H/DIVISOR,
		FRAME_ADDR_BITS = $clog2(NUM_FRAME_WORDS),
		FRAME_W_FULL    = FRAME_W + H_BP + H_SYNC + H_FP,
		FRAME_H_FULL    = FRAME_H + V_BP + V_SYNC + V_FP,
		FRAME_X_BITS    = $clog2(FRAME_W_FULL),
		FRAME_Y_BITS    = $clog2(FRAME_H_FULL),

		WORD_BITS       = BYTE_BITS * BYTES_PER_WORD,
		ADDR_BITS       = $clog2(NUM_ATLAS_WORDS | NUM_FRAME_WORDS) + 2
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
	output bit                     ack = 0,
	output bit                     retry = 0
);

	//
	// Memory interface
	//

	wire
		to_frame   = addr[ADDR_BITS-2],
		to_atlas   = addr[ADDR_BITS-1],
		to_v_blank = addr == 0,
		to_busy    = addr == 1,
		to_fire    = addr == 2,
		to_a_x     = addr == 3,
		to_a_y     = addr == 4,
		to_a_z     = addr == 5,
		to_a_u     = addr == 6,
		to_a_v     = addr == 7,
		to_b_x     = addr == 8,
		to_b_y     = addr == 9,
		to_b_z     = addr == 10,
		to_b_u     = addr == 11,
		to_b_v     = addr == 12,
		to_c_x     = addr == 13,
		to_c_y     = addr == 14,
		to_c_z     = addr == 15,
		to_c_u     = addr == 16,
		to_c_v     = addr == 17;

	bit
		from_frame,
		from_atlas,
		from_v_blank,
		from_busy;

	Vertex a, b, c;

	always @(posedge clock) begin
		from_frame <= to_frame;
		from_atlas <= to_atlas;
		from_v_blank <= to_v_blank;
		from_busy <= to_busy;

		if (to_a_x) a.x <= in;
		if (to_a_y) a.y <= in;
		if (to_a_z) a.z <= in;
		if (to_b_x) b.x <= in;
		if (to_b_y) b.y <= in;
		if (to_b_z) b.z <= in;
		if (to_c_x) c.x <= in;
		if (to_c_y) c.y <= in;
		if (to_c_z) c.z <= in;

	end

	//
	// Beam
	//

	wire[FRAME_X_BITS-1:0] beam_x;
	wire[FRAME_Y_BITS-1:0] beam_y;

	wire[1:0]
		blank_0,
		sync_0;

	wire[1:0]
		blank,
		sync;

	wire RGB_444 color;
	assign pixel = blank ? 0 : color;

	always @(posedge clock) begin
		blank <= blank_0;
		sync <= sync_0;

	end

	Video_Timing #(
		.W(FRAME_W),
		.H(FRAME_H),
		.H_PAD(H_PAD),
		.V_PAD(V_PAD),
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
		.x(beam_x),
		.y(beam_y)
	);

	wire rasterizing;

	wire[FRAME_ADDR_BITS-1:0] draw_addr;
	wire[11:0] draw_out;
	wire draw_select, draw_ack, draw_retry;

	Video_Rasterizer #(
	) rasterizer(
		.clock(bus_clock),

		.fire(to_fire && strobe && select && write),
		.a,
		.b,
		.c,
		.busy(rasterizing),

		.draw_addr,
		.draw_out,
		.draw_select,
		.draw_ack,
		.draw_retry,
	);

	BRAM #(
		.NUM_WORDS(W/DIVISOR * H/DIVISOR),
		.BYTE_BITS(12),
		.BYTES_PER_WORD(1)
	) frame(
		// Internal port.
		.clock_1(pixel_clock),
		.addr_1(FRAME_W/DIVISOR * (beam_y/DIVISOR) + beam_x/DIVISOR),
		// This port is read-only.
		// .in_1(),
		.out_1(color),
		.select_1(-1),
		// This port is read-only.
		.write_1(0),
		.strobe_1(1),
		// The bramebuffer must always answer in one cycle.
		// .ack_1(),
		// .retry_(),

		// External port, shared with the rasterizer.
		.clock_2(bus_clock),
		.addr_2(rasterizing ? draw_addr : addr[ADDR_BITS-3:0]),
		.in_2(rasterizing ? draw_out : in),
		.out_2(frame_out),
		.write_2(rasterizing ? 1 : write),
		.select_2(rasterizing ? -1 : |select),
		.strobe_2(rasterizing ? draw_strobe : strobe && to_frame),
		.ack_2(frame_ack),
		.retry_2(frame_retry)
	);

	BRAM #(
		.NUM_WORDS(ATLAS_W * ATLAS_H),
		.BYTE_BITS(12),
		.BYTES_PER_WORD(1)
	) atlas(
		// Internal port.
		.clock_1(bus_clock),
		.addr_1(atlas_addr),
		// This port is read-only.
		// .in_1(),
		.out_1(in),
		.select_1(-1),
		// This port is read-only.
		.write_1(0),
		.strobe_1(atlas_strobe),
		// The atlas must always answer in one cycle.
		// .ack_1(),
		// .retry_1().

		// External port.
		.clock_2(bus_clock),
		.addr_2(addr[ADDR_BITS-3:0]),
		.out_2(atlas_out),
		.write_2(write),
		.select_2(|select),
		.strobe_2(strobe && to_atlas),
		.ack_2(atlas_ack),
		.retry_2(atlas_retry)
	);

endmodule

module Video_Rasterizer #(
) (
	input wire        clock,

	// Triangle input.
	input wire        fire,
	input wire Vertex a,
	input wire Vertex b,
	input wire Vertex c,
	output wire       busy,

	// Draw memory port.
	output wire[31:0] draw_addr,
	// This port is write-only.
	// input wire draw_in,
	output wire[31:0] draw_out,
	output bit        draw_write = 1,
	output bit        draw_select = 1,
	output wire       draw_strobe,
	input wire        draw_ack,
	input wire        draw_retry,

	// Atlas memory port.
	output wire[31:0] atlas_addr,
	input wire[11:0]  atlas_in,
	// This port is read-only.
	// output wire atlas_out,
	output bit        atlas_write = 1,
	output wire       atlas_select = 1,
	output wire       atlas_strobe,
	input wire        atlas_ack,
	input wire        atlas_retry
);

endmodule

module Video_Timing #(
	parameter
		W,
		H,
		H_PAD,
		V_PAD,
		H_FP,
		H_SYNC,
		H_BP,
		V_FP,
		V_SYNC,
		V_BP,

	localparam
		W_FULL = W + H_PAD + H_FP + H_SYNC + H_BP + H_PAD,
		H_FULL = H + V_PAD + V_FP + V_SYNC + V_BP + V_PAD,

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
		sync[0]  = x >= W+H_FP+H_PAD && x < W+H_FP+H_PAD+H_SYNC,
		sync[1]  = y >= H+V_FP+V_PAD && y < H+V_FP+V_PAD+V_SYNC;

	always @(posedge clock)

		if (x_maxed) begin
			x <= 0;
			y <= y_maxed ? 0 : y+1;

		end else
			x <= x+1;

endmodule

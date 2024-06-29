module Video #(
	parameter
		BYTE_BITS,
		BYTES_PER_WORD,

		W       = 640,
		H       = 400,
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
		NUM_WORDS = W/DIVISOR * H/DIVISOR,
		WORD_BITS = BYTE_BITS * BYTES_PER_WORD,
		ADDR_BITS = $clog2(NUM_WORDS) + 1,
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
	output bit                     ack = 0,
	output bit                     retry = 0
);

	wire[WORD_BITS-1:0] color;
	wire[X_BITS-1:0] x;
	wire[Y_BITS-1:0] y;

	wire
		to_frame      = addr[ADDR_BITS-1],
		to_v_blank    = addr == 0,
		to_start      = addr == 1,
		to_busy       = addr == 2,
		to_x_min      = addr == 3,
		to_x_max      = addr == 4,
		to_y_min      = addr == 5,
		to_y_max      = addr == 6,
		to_reciprocal = addr == 7,
		to_iw_0       = addr == 8,
		to_iw_1       = addr == 9,
		to_iw_2       = addr == 10,
		to_dc_0       = addr == 11,
		to_dc_1       = addr == 12,
		to_dc_2       = addr == 13,
		to_dr_0       = addr == 14,
		to_dr_1       = addr == 15,
		to_dr_2       = addr == 16;

	bit
		from_frame,
		from_v_blank,
		from_busy;

	bit signed[31:0]
		x_min,
		x_max,
		y_min,
		y_max,
		reciprocal,
		iw_0,
		iw_1,
		iw_2,
		dc_0,
		dc_1,
		dc_2,
		dr_0,
		dr_1,
		dr_2;

	bit signed[31:0]
		rx,
		ry,
		wr_0,
		wr_1,
		wr_2,
		w_0,
		w_1,
		w_2;

	always @(posedge bus_clock) begin
		ack <= strobe;
		from_frame <= to_frame;
		from_v_blank <= to_v_blank;
		from_busy <= to_busy;

	end

	always @(posedge bus_clock) if (strobe && write) begin
		if (to_x_min)      x_min      <= in;
		if (to_x_max)      x_max      <= in;
		if (to_y_min)      y_min      <= in;
		if (to_y_max)      y_max      <= in;
		if (to_reciprocal) reciprocal <= in;
		if (to_iw_0)       iw_0       <= in;
		if (to_iw_1)       iw_1       <= in;
		if (to_iw_2)       iw_2       <= in;
		if (to_dc_0)       dc_0       <= in;
		if (to_dc_1)       dc_1       <= in;
		if (to_dc_2)       dc_2       <= in;
		if (to_dr_0)       dr_0       <= in;
		if (to_dr_1)       dr_1       <= in;
		if (to_dr_2)       dr_2       <= in;

	end

	bit rasterizing = 0;
	wire is_inside = !w_0[31] && !w_1[31] && !w_2[31];
	wire[ADDR_BITS-2:0] raster_pos = W/DIVISOR * ry + rx;

	// Reciprocal is downsampled to save on multiplier blocks.
	wire[15:0]
		alpha = w_0[31:16] * reciprocal[31:16],
		beta  = -alpha - gamma,
		gamma = w_2[31:16] * reciprocal[31:16];

	wire RGB_444
		raster_color = { alpha[15:12], beta[15:12], gamma[15:12] };

	always @(posedge bus_clock)

		if (rasterizing) begin
			if (rx >= x_max) begin
				rx <= x_min;
				ry <= ry+1;

				w_0 <= wr_0 + dr_0;
				w_1 <= wr_1 + dr_1;
				w_2 <= wr_2 + dr_2;

				wr_0 <= wr_0 + dr_0;
				wr_1 <= wr_1 + dr_1;
				wr_2 <= wr_2 + dr_2;

			end else begin
				rx <= rx+1;

				w_0 <= w_0 + dc_0;
				w_1 <= w_1 + dc_1;
				w_2 <= w_2 + dc_2;

			end

			// End rasterizing when last pixel is processed.
			rasterizing <= rx < x_max || ry < y_max;

		end else begin
			rx <= x_min;
			ry <= y_min;
			wr_0 <= iw_0;
			wr_1 <= iw_1;
			wr_2 <= iw_2;
			w_0 <= iw_0;
			w_1 <= iw_1;
			w_2 <= iw_2;

			// Start rasterizing when signal received.
			rasterizing <= strobe && write && to_start;

		end

	wire[1:0]
		blank_0,
		sync_0;

	wire[WORD_BITS-1:0] frame_out;

	assign pixel = blank ? 'h000 : color;

	assign out =
		  (from_frame ?     frame_out     : 0)
		| (from_v_blank ?   blank[1]      : 0)
		| (from_busy ?      rasterizing   : 0);

	always @(posedge pixel_clock) begin
		blank <= blank_0;
		sync <= sync_0;

	end

	BRAM #(
		.NUM_WORDS(W/DIVISOR * H/DIVISOR),
		.BYTE_BITS(12),
		.BYTES_PER_WORD(1)
	) frame(
		.clock_1(pixel_clock),
		.addr_1(W/DIVISOR * (y/DIVISOR) + x/DIVISOR),
		.out_1(color),
		.write_1(0),
		.select_1(-1),
		.strobe_1(1),

		.clock_2(bus_clock),
		.addr_2(rasterizing ? raster_pos : addr[ADDR_BITS-2:0]),
		.in_2(rasterizing ? raster_color : in),
		.out_2(frame_out),
		.write_2(rasterizing ? is_inside : write),
		.select_2(rasterizing ? -1 : select),
		.strobe_2(rasterizing ? is_inside : strobe && to_frame)
		// Acknowledgement handled together with MMIO.
		// BRAM does not retry, neither does MMIO.
	);

	Video_Timing #(
		.W(W),
		.H(H),
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
		.x,
		.y
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

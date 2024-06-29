module Video #(
	parameter
		BYTE_BITS,
		BYTES_PER_WORD,

		SCALE   = 4,
		ATLAS   = 'x,
		ATLAS_W = 128,
		ATLAS_H = 128,
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

	localparam
		F_X_BITS    = $clog2(FRAME_W),
		F_Y_BITS    = $clog2(FRAME_H),
		F_NUM_WORDS = FRAME_W/SCALE * FRAME_H/SCALE,
		F_ADDR_BITS = $clog2(F_NUM_WORDS),

		A_X_BITS    = $clog2(ATLAS_W),
		A_Y_BITS    = $clog2(ATLAS_H),
		A_NUM_WORDS = ATLAS_W * ATLAS_H,
		A_ADDR_BITS = $clog2(A_NUM_WORDS),

		WORD_BITS   = BYTE_BITS * BYTES_PER_WORD,
		ADDR_BITS   = $clog2(F_NUM_WORDS | A_NUM_WORDS) + 2
) (
	input wire                     beam_clock,
	output wire RGB_666            color,
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

	//
	// Beam
	//

	// Only visible positions are interesting.
	wire[F_X_BITS-1:0] beam_x;
	wire[F_Y_BITS-1:0] beam_y;

	wire[1:0]
		blank_0,
		sync_0;

	bit inside_border;
	wire RGB_666 beam_color;

	assign color =
		blank ?           0                      :
		inside_border ?   'b011111_011111_011111 :
		/* else ? */      beam_color;

	always @(posedge beam_clock) begin
		blank <= blank_0;
		sync <= sync_0;

		inside_border <=
			   beam_x == 0
			|| beam_y == 0
			|| beam_x == FRAME_W - 1
			|| beam_y == FRAME_H - 1;

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
		.clock(beam_clock),
		.blank(blank_0),
		.sync(sync_0),
		.x(beam_x),
		.y(beam_y)
	);

	//
	// Rasterizer
	//

	wire rasterizing;

	wire[F_ADDR_BITS-1:0] pixel_addr;
	wire[2:0] pixel_select;
	wire RGB_666 pixel;

	wire
		pixel_write,
		pixel_strobe;

	wire[A_ADDR_BITS-1:0] texel_addr;
	wire[2:0] texel_select;
	wire RGB_666 texel;

	wire
		texel_write,
		texel_strobe,
		texel_ack,
		texel_retry;

	Video_Rasterizer #(
		.SCALE(SCALE),
		.FRAME_W(FRAME_W),
		.FRAME_H(FRAME_H),
		.ATLAS_W(ATLAS_W),
		.ATLAS_H(ATLAS_H)
	) rasterizer(
		.clock(bus_clock),

		.fire(to_fire && strobe && select && write),
		.a_in(a),
		.b_in(b),
		.c_in(c),
		.matrix_in(matrix),
		.busy(rasterizing),

		.pixel_addr,
		.pixel_out(pixel),
		.pixel_write,
		.pixel_select,
		.pixel_strobe,
		.pixel_ack(frame_ack),
		.pixel_retry(frame_retry),

		.texel_addr,
		.texel_in(texel),
		.texel_write,
		.texel_select,
		.texel_strobe,
		.texel_ack,
		.texel_retry
	);

	//
	// Memory interface
	//

	wire
		to_frame   = addr[ADDR_BITS-2],
		to_atlas   = addr[ADDR_BITS-1],
		to_mmio    = !to_frame && !to_atlas,

		to_i_x     = addr == 0,
		to_i_y     = addr == 1,
		to_i_z     = addr == 2,
		to_i_w     = addr == 3,

		to_j_x     = addr == 4,
		to_j_y     = addr == 5,
		to_j_z     = addr == 6,
		to_j_w     = addr == 7,

		to_k_x     = addr == 8,
		to_k_y     = addr == 9,
		to_k_z     = addr == 10,
		to_k_w     = addr == 11,

		to_l_x     = addr == 12,
		to_l_y     = addr == 13,
		to_l_z     = addr == 14,
		to_l_w     = addr == 15,

		to_v_blank = addr == 16,
		to_fire    = addr == 17,
		to_busy    = addr == 18,

		to_a_x     = addr == 19,
		to_a_y     = addr == 20,
		to_a_z     = addr == 21,
		to_a_u     = addr == 22,
		to_a_v     = addr == 23,

		to_b_x     = addr == 24,
		to_b_y     = addr == 25,
		to_b_z     = addr == 26,
		to_b_u     = addr == 27,
		to_b_v     = addr == 28,

		to_c_x     = addr == 29,
		to_c_y     = addr == 30,
		to_c_z     = addr == 31,
		to_c_u     = addr == 32,
		to_c_v     = addr == 33;

	bit
		from_frame,
		from_atlas,
		from_v_blank,
		from_busy;

	assign out =
		  (from_frame ?     `rgb666_unpack(frame_out)   : 0)
		| (from_atlas ?     `rgb666_unpack(atlas_out)   : 0)
		| (from_v_blank ?   blank[1]                    : 0)
		| (from_busy ?      rasterizing                 : 0);

	Mat4 matrix;
	Vertex a, b, c;
	bit mmio_ack;

	wire
		frame_ack,
		atlas_ack;

	wire
		frame_retry,
		atlas_retry;

	wire RGB_666
		atlas_out,
		frame_out;

	assign ack =
		   frame_ack && !rasterizing
		|| atlas_ack
		|| mmio_ack;

	assign retry =
		   frame_retry && !rasterizing
		|| from_frame && rasterizing
		|| atlas_retry;

	always @(posedge bus_clock) if (strobe) begin
		from_frame <= to_frame;
		from_atlas <= to_atlas;
		from_v_blank <= to_v_blank;
		from_busy <= to_busy;

		mmio_ack <= to_mmio;

		if (to_i_x) matrix.i.x <= in;
		if (to_i_y) matrix.i.y <= in;
		if (to_i_z) matrix.i.z <= in;
		if (to_i_w) matrix.i.w <= in;

		if (to_j_x) matrix.j.x <= in;
		if (to_j_y) matrix.j.y <= in;
		if (to_j_z) matrix.j.z <= in;
		if (to_j_w) matrix.j.w <= in;

		if (to_k_x) matrix.k.x <= in;
		if (to_k_y) matrix.k.y <= in;
		if (to_k_z) matrix.k.z <= in;
		if (to_k_w) matrix.k.w <= in;

		if (to_l_x) matrix.l.x <= in;
		if (to_l_y) matrix.l.y <= in;
		if (to_l_z) matrix.l.z <= in;
		if (to_l_w) matrix.l.w <= in;

		if (to_a_x) a.pos.x <= in;
		if (to_a_y) a.pos.y <= in;
		if (to_a_z) a.pos.z <= in;
		if (to_a_u) a.tex.x <= in;
		if (to_a_v) a.tex.y <= in;

		if (to_b_x) b.pos.x <= in;
		if (to_b_y) b.pos.y <= in;
		if (to_b_z) b.pos.z <= in;
		if (to_b_u) b.tex.x <= in;
		if (to_b_v) b.tex.y <= in;

		if (to_c_x) c.pos.x <= in;
		if (to_c_y) c.pos.y <= in;
		if (to_c_z) c.pos.z <= in;
		if (to_c_u) c.tex.x <= in;
		if (to_c_v) c.tex.y <= in;

	end

	BRAM #(
		.NUM_WORDS(F_NUM_WORDS),
		.BYTE_BITS(6),
		.BYTES_PER_WORD(3)
	) frame(
		// Internal port.
		.clock_1(beam_clock),
		.addr_1(FRAME_W/SCALE * (beam_y/SCALE) + beam_x/SCALE),
		.out_1(beam_color),
		.select_1('b111),
		.write_1(0),
		.strobe_1(1),

		// External port shared with the rasterizer.
		.clock_2(bus_clock),
		.addr_2(rasterizing ? pixel_addr : addr[F_ADDR_BITS-1:0]),
		.in_2(rasterizing ? pixel : `rgb666_pack(in)),
		.out_2(frame_out),
		.write_2(rasterizing ? pixel_write : write),
		.select_2(rasterizing ? pixel_select : select),
		.strobe_2(rasterizing ? pixel_strobe : strobe && to_frame),
		.ack_2(frame_ack),
		.retry_2(frame_retry)
	);

	BRAM #(
		.FILE(ATLAS),
		.NUM_WORDS(A_NUM_WORDS),
		.BYTE_BITS(6),
		.BYTES_PER_WORD(3)
	) atlas(
		// Internal port.
		.clock_1(bus_clock),
		.addr_1(texel_addr),
		.out_1(texel),
		.select_1(texel_select),
		.write_1(texel_write),
		.strobe_1(texel_strobe),
		.ack_1(texel_ack),
		.retry_1(texel_retry),

		// External port.
		.clock_2(bus_clock),
		.addr_2(addr[A_ADDR_BITS-1:0]),
		.in_2(`rgb666_pack(in)),
		.out_2(atlas_out),
		.write_2(write),
		.select_2(select),
		.strobe_2(strobe && to_atlas),
		.ack_2(atlas_ack),
		.retry_2(atlas_retry)
	);

`ifdef DUMP
	wire[31:0]
		matrix_i_x = matrix.i.x,
		matrix_i_y = matrix.i.y,
		matrix_i_z = matrix.i.z,
		matrix_i_w = matrix.i.w,
		matrix_j_x = matrix.j.x,
		matrix_j_y = matrix.j.y,
		matrix_j_z = matrix.j.z,
		matrix_j_w = matrix.j.w,
		matrix_k_x = matrix.k.x,
		matrix_k_y = matrix.k.y,
		matrix_k_z = matrix.k.z,
		matrix_k_w = matrix.k.w,
		matrix_l_x = matrix.l.x,
		matrix_l_y = matrix.l.y,
		matrix_l_z = matrix.l.z,
		matrix_l_w = matrix.l.w;

	wire[31:0]
		a_x = a.pos.x,
		a_y = a.pos.y,
		a_z = a.pos.z,
		a_u = a.tex.x,
		a_v = a.tex.y,
		b_x = b.pos.x,
		b_y = b.pos.y,
		b_z = b.pos.z,
		b_u = b.tex.x,
		b_v = b.tex.y,
		c_x = c.pos.x,
		c_y = c.pos.y,
		c_z = c.pos.z,
		c_u = c.tex.x,
		c_v = c.tex.y;
`endif

endmodule

module Video_Rasterizer #(
	parameter
		SCALE,
		ATLAS_W,
		ATLAS_H,
		FRAME_W,
		FRAME_H,

	localparam
		F_ADDR_BITS = $clog2(FRAME_W/SCALE * FRAME_H/SCALE),
		A_ADDR_BITS = $clog2(ATLAS_W * ATLAS_H)
) (
	input wire                 clock,

	// Triangle input.
	input wire                 fire,
	input wire Vertex          a_in,
	input wire Vertex          b_in,
	input wire Vertex          c_in,
	input wire Mat4            matrix_in,
	output wire                busy,

	// Draw memory port.
	output bit[F_ADDR_BITS:0]  pixel_addr,
	// input wire RGB_666         pixel_in,
	output RGB_666             pixel_out,
	output bit                 pixel_write = 1,
	output bit[2:0]            pixel_select = 'b111,
	output bit                 pixel_strobe = 0,
	input wire                 pixel_ack,
	input wire                 pixel_retry,

	// Atlas memory port.
	output bit[A_ADDR_BITS:0]  texel_addr,
	input wire RGB_666         texel_in,
	// output wire RGB_666        texel_out,
	output bit                 texel_write = 0,
	output bit[2:0]            texel_select = 'b111,
	output bit                 texel_strobe = 0,
	input wire                 texel_ack,
	input wire                 texel_retry
);

	typedef enum bit[4:0] {
		S_IDLE,
		// Transform vertex `a`.
		S_XFORM_A_1,
		S_XFORM_A_2,
		S_XFORM_A_3,
		S_XFORM_A_4,
		// Transform vertex `b`.
		S_XFORM_B_1,
		S_XFORM_B_2,
		S_XFORM_B_3,
		S_XFORM_B_4,
		// Transform vertex `c`.
		S_XFORM_C_1,
		S_XFORM_C_2,
		S_XFORM_C_3,
		S_XFORM_C_4,
		// Prepare intermediate values to be used by subsequent states.
		S_DECODE_1,
		S_DECODE_2,
		S_DECODE_3,
		// Calculate triangle area and `iw_X` values.
		S_PRODUCTS_1,
		S_PRODUCTS_2,
		S_GATHER,
		// Calculate all reciprocals to be used later in parallel.
		S_RECIPROCALS,
		// Rasterize triangle pixels.
		S_RASTERIZE,
		// Wait for the last pixel to be stored in the frame.
		S_END
	} State;

	State state = S_IDLE;
	assign busy = state != S_IDLE;

	Mat4 matrix;

	Vertex
		a,
		b,
		c;

	Vec4
		homo_a,
		homo_b,
		homo_c;

	bit signed[15:0]
		min_x,
		max_x,
		min_y,
		max_y;

	wire Vec2 origin = { min_x, 16'h8000, min_y, 16'h8000 };
	// wire Vec2 origin = { min_x, 16'h0000, min_y, 16'h0000 };

	wire Vec2
		a_to_b = `vec2_sub(homo_b, homo_a),
		a_to_c = `vec2_sub(homo_c, homo_a),
		b_to_c = `vec2_sub(homo_c, homo_b),
		c_to_a = `vec2_sub(homo_a, homo_c),
		a_to_o = `vec2_sub(origin, homo_a),
		b_to_o = `vec2_sub(origin, homo_b),
		c_to_o = `vec2_sub(origin, homo_c);

	bit signed[15:0]
		x,
		y;

	bit signed[31:0]
		l_1,
		l_2,
		l_3,
		l_4,
		r_1,
		r_2,
		r_3,
		r_4;

	bit signed[63:0]
		product_1,
		product_2,
		product_3,
		product_4;

	bit signed[63:0]
		partial_area_1,
		partial_area_2,
		partial_iw_0_1,
		partial_iw_0_2,
		partial_iw_1_1,
		partial_iw_1_2,
		partial_iw_2_1,
		partial_iw_2_2;

	bit signed[31:0]
		area,
		iw_0,
		iw_1,
		iw_2,
		w_0,
		w_1,
		w_2,
		w_0_dx,
		w_1_dx,
		w_2_dx,
		w_0_dy,
		w_1_dy,
		w_2_dy;

	wire is_inside = !w_0[31] && !w_1[31] && !w_2[31];

	wire
		x_maxed = x >= max_x,
		y_maxed = y >= max_y;

	bit[15:0]
		raster_x,
		raster_y;

	bit[33:0]
		dividend_1,
		dividend_2,
		dividend_3,
		dividend_4;

	bit[64:0]
		divisor_1,
		divisor_2,
		divisor_3,
		divisor_4;

	bit[33:0]
		quotient_1,
		quotient_2,
		quotient_3,
		quotient_4,
		quotient_mask;

	wire step_division_next_4 = divisor_4 <= dividend_4;

	wire[33:0] next_dividend_4 = step_division_next_4 ? dividend_4 - divisor_4[33:0] : dividend_4;
	wire[33:0] next_quotient_4 = step_division_next_4 ? quotient_4 | quotient_mask   : quotient_4;

	wire step_division_final_4 = (divisor_4 >> 1) <= next_dividend_4;

	wire[33:0] final_dividend_4 = step_division_final_4 ? next_dividend_4 - divisor_4[34:1]     : next_dividend_4;
	wire[33:0] final_quotient_4 = step_division_final_4 ? next_quotient_4 | quotient_mask[33:1] : next_quotient_4;

	// bit div_sign;

	always @(posedge clock) begin
		product_1 <= l_1 * r_1;
		product_2 <= l_2 * r_2;
		product_3 <= l_3 * r_3;
		product_4 <= l_4 * r_4;

	end

	always @(posedge clock) case (state)

		S_IDLE: if (fire) begin
			is_inside <= 0;

			a <= a_in;
			b <= b_in;
			c <= c_in;
			matrix <= matrix_in;

			l_1 <= matrix_in.i.x;
			l_2 <= matrix_in.i.y;
			l_3 <= matrix_in.i.z;
			l_4 <= matrix_in.i.w;

			r_1 <= a_in.pos.x;
			r_2 <= a_in.pos.y;
			r_3 <= a_in.pos.z;
			r_4 <= 'h1_0000;

			state <= S_XFORM_A_1;

		end

		S_XFORM_A_1: begin
			l_1 <= matrix.j.x;
			l_2 <= matrix.j.y;
			l_3 <= matrix.j.z;
			l_4 <= matrix.j.w;

			state <= S_XFORM_A_2;

		end

		S_XFORM_A_2: begin
			homo_a.x <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.k.x;
			l_2 <= matrix.k.y;
			l_3 <= matrix.k.z;
			l_4 <= matrix.k.w;

			state <= S_XFORM_A_3;

		end

		S_XFORM_A_3: begin
			homo_a.y <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.l.x;
			l_2 <= matrix.l.y;
			l_3 <= matrix.l.z;
			l_4 <= matrix.l.w;

			state <= S_XFORM_A_4;

		end

		S_XFORM_A_4: begin
			homo_a.z <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.i.x;
			l_2 <= matrix.i.y;
			l_3 <= matrix.i.z;
			l_4 <= matrix.i.w;

			r_1 <= b.pos.x;
			r_2 <= b.pos.y;
			r_3 <= b.pos.z;
			r_4 <= 'h1_0000;

			state <= S_XFORM_B_1;

		end

		S_XFORM_B_1: begin
			homo_a.w <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.j.x;
			l_2 <= matrix.j.y;
			l_3 <= matrix.j.z;
			l_4 <= matrix.j.w;

			state <= S_XFORM_B_2;

		end

		S_XFORM_B_2: begin
			homo_b.x <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.k.x;
			l_2 <= matrix.k.y;
			l_3 <= matrix.k.z;
			l_4 <= matrix.k.w;

			state <= S_XFORM_B_3;

		end

		S_XFORM_B_3: begin
			homo_b.y <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.l.x;
			l_2 <= matrix.l.y;
			l_3 <= matrix.l.z;
			l_4 <= matrix.l.w;

			state <= S_XFORM_B_4;

		end

		S_XFORM_B_4: begin
			homo_b.z <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.i.x;
			l_2 <= matrix.i.y;
			l_3 <= matrix.i.z;
			l_4 <= matrix.i.w;

			r_1 <= c.pos.x;
			r_2 <= c.pos.y;
			r_3 <= c.pos.z;
			r_4 <= 'h1_0000;

			state <= S_XFORM_C_1;

		end

		S_XFORM_C_1: begin
			homo_b.w <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.j.x;
			l_2 <= matrix.j.y;
			l_3 <= matrix.j.z;
			l_4 <= matrix.j.w;

			state <= S_XFORM_C_2;

		end

		S_XFORM_C_2: begin
			homo_c.x <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.k.x;
			l_2 <= matrix.k.y;
			l_3 <= matrix.k.z;
			l_4 <= matrix.k.w;

			state <= S_XFORM_C_3;

		end

		S_XFORM_C_3: begin
			homo_c.y <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			l_1 <= matrix.l.x;
			l_2 <= matrix.l.y;
			l_3 <= matrix.l.z;
			l_4 <= matrix.l.w;

			state <= S_XFORM_C_4;

		end

		S_XFORM_C_4: begin
			homo_c.z <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			state <= S_DECODE_1;

		end

		S_DECODE_1: begin
			homo_c.w <= (product_1 + product_2 + product_3 + product_4) >>> 16;

			min_x <= `min(`min(homo_a.x, homo_b.x), homo_c.x) >>> 16;
			max_x <= `max(`max(homo_a.x, homo_b.x), homo_c.x) >>> 16;
			min_y <= `min(`min(homo_a.y, homo_b.y), homo_c.y) >>> 16;
			max_y <= `max(`max(homo_a.y, homo_b.y), homo_c.y) >>> 16;

			x <= `min(`min(homo_a.x, homo_b.x), homo_c.x) >>> 16;
			y <= `min(`min(homo_a.y, homo_b.y), homo_c.y) >>> 16;

			state <= S_DECODE_2;

		end

		S_DECODE_2: begin
			// TODO: WIP.
			// min_x <= `max(min_x, 0);
			// max_x <= `min(max_x, FRAME_W/SCALE);
			// min_y <= `max(min_y, 0);
			// max_y <= `min(max_y, FRAME_H/SCALE);

			// x <= `min(`min(homo_a.x, homo_b.x), homo_c.x) >>> 16;
			// y <= `min(`min(homo_a.y, homo_b.y), homo_c.y) >>> 16;

			state <= S_DECODE_3;

		end

		S_DECODE_3: begin
			l_1 <= a_to_b.x;
			r_1 <= a_to_c.y;

			l_2 <= a_to_b.y;
			r_2 <= a_to_c.x;

			l_3 <= b_to_c.x;
			r_3 <= b_to_o.y;

			l_4 <= b_to_c.y;
			r_4 <= b_to_o.x;

			state <= S_PRODUCTS_1;

		end

		S_PRODUCTS_1: begin
			partial_area_1 <= l_1 * r_1;
			partial_area_2 <= l_2 * r_2;

			partial_iw_0_1  <= l_3 * r_3;
			partial_iw_0_2  <= l_4 * r_4;

			l_1 <= c_to_a.x;
			r_1 <= c_to_o.y;

			l_2 <= c_to_a.y;
			r_2 <= c_to_o.x;

			l_3 <= a_to_b.x;
			r_3 <= a_to_o.y;

			l_4 <= a_to_b.y;
			r_4 <= a_to_o.x;

			state <= S_PRODUCTS_2;
		end

		S_PRODUCTS_2: begin
			partial_iw_1_1  <= l_1 * r_1;
			partial_iw_1_2  <= l_2 * r_2;

			partial_iw_2_1  <= l_3 * r_3;
			partial_iw_2_2  <= l_4 * r_4;

			state <= S_GATHER;

		end

		S_GATHER: begin
			area <= (partial_area_1 - partial_area_2) >>> 16;

			iw_0 <= (partial_iw_0_1 - partial_iw_0_2) >>> 16;
			iw_1 <= (partial_iw_1_1 - partial_iw_1_2) >>> 16;
			iw_2 <= (partial_iw_2_1 - partial_iw_2_2) >>> 16;

			w_0 <= (partial_iw_0_1 - partial_iw_0_2) >>> 16;
			w_1 <= (partial_iw_1_1 - partial_iw_1_2) >>> 16;
			w_2 <= (partial_iw_2_1 - partial_iw_2_2) >>> 16;

			w_0_dx <= homo_b.y - homo_c.y;
			w_1_dx <= homo_c.y - homo_a.y;
			w_2_dx <= homo_a.y - homo_b.y;

			w_0_dy <= homo_c.x - homo_b.x;
			w_1_dy <= homo_a.x - homo_c.x;
			w_2_dy <= homo_b.x - homo_a.x;

			dividend_1 <= 'h1_0000_0000;
			dividend_2 <= 'h1_0000_0000;
			dividend_3 <= 'h1_0000_0000;
			dividend_4 <= 'h1_0000_0000;

			// divisor <= (sright[32] ? -uright : uright) << 32;

			divisor_1 <= homo_a.w << 33;
			divisor_2 <= homo_b.w << 33;
			divisor_3 <= homo_c.w << 33;


			// This exploits the fact that:
			//
			//     1.0 / X.0 = 0.Y <=> 1.0 / 0.X = Y.0
			//
			// Example:
			//
			//     1.0 / 2.0 = 0.5 <=> 1.0 / 0.2 = 5.0
			//
			// The advantage of doing this is a more precise reciprocal value.
			//
			divisor_4 <= ((partial_area_1 - partial_area_2) >>> 32) <<< 33; // area is always positive.
			// divisor_4 <= (partial_area_1 - partial_area_2) <<< 15; // area is always positive.

			// div_sign <= sleft[32] ^ sright[32];

			quotient_1 <= 0;
			quotient_2 <= 0;
			quotient_3 <= 0;
			quotient_4 <= 0;

			quotient_mask <= 1<<33;

			// Discard back-facing triangles.
			state <= partial_area_1 < partial_area_2 ? S_IDLE : S_RECIPROCALS;

		end

		S_RECIPROCALS: begin
			// dividend_1 <= final_dividend_1;
			// dividend_2 <= final_dividend_2;
			// dividend_3 <= final_dividend_3;
			dividend_4 <= final_dividend_4;

			// quotient_1 <= final_quotient_1;
			// quotient_2 <= final_quotient_2;
			// quotient_3 <= final_quotient_3;
			quotient_4 <= final_quotient_4;

			divisor_1 <= divisor_1 >> 2;
			divisor_2 <= divisor_2 >> 2;
			divisor_3 <= divisor_3 >> 2;
			divisor_4 <= divisor_4 >> 2;

			quotient_mask <= quotient_mask >> 2;

			// Loop until divisions are over.
			state <= quotient_mask[33:2] ? S_RECIPROCALS : S_RASTERIZE;

		end

		S_RASTERIZE: begin
			paint <= is_inside;

			raster_x <= x;
			raster_y <= y;

			l_1 <= w_0;
			r_1 <= quotient_4;

			l_2 <= w_1;
			r_2 <= quotient_4;

			l_3 <= w_2;
			r_3 <= quotient_4;

			if (x_maxed && y_maxed) begin
				state <= S_END;

			end else if (x_maxed) begin
				x <= min_x;
				y <= y+1;

				w_0 <= iw_0 + w_0_dy;
				w_1 <= iw_1 + w_1_dy;
				w_2 <= iw_2 + w_2_dy;

				iw_0 <= iw_0 + w_0_dy;
				iw_1 <= iw_1 + w_1_dy;
				iw_2 <= iw_2 + w_2_dy;

			end else begin
				x <= x+1;

				w_0 <= w_0 + w_0_dx;
				w_1 <= w_1 + w_1_dx;
				w_2 <= w_2 + w_2_dx;

			end

		end

		S_END: begin
			paint <= 0;
			state <= S_IDLE;

		end

	endcase

	bit paint = 0, painting = 0;
	bit[15:0] other_x, other_y;
	bit[15:0] another_x, another_y;

	wire[15:0]
		alpha =  product_1[47:32],
		beta  =  product_2[47:32],
		gamma = -product_1[47:32] - product_2[47:32];

	wire[31:0]
		raw_u = alpha * a.tex.x[24:8] + beta * b.tex.x[24:8] + gamma * c.tex.x[24:8],
		raw_v = alpha * a.tex.y[24:8] + beta * b.tex.y[24:8] + gamma * c.tex.y[24:8];

	wire[15:0]
		u = raw_u[31:24],
		v = raw_v[31:24];

	always @(posedge clock) begin
		painting <= paint;
	end

	always @(posedge clock) begin
		texel_addr <= ATLAS_W * v + u;
		texel_strobe <= painting;
		other_x <= raster_x;
		other_y <= raster_y;

	end


	always @(posedge clock) begin
		another_x <= other_x;
		another_y <= other_y;

		if (texel_ack) begin
			pixel_addr <= FRAME_W/SCALE * another_y + another_x;
			pixel_out <= texel_in;

			pixel_strobe <= 1;

		end else
			pixel_strobe <= 0;

	end



`ifdef DUMP
	wire[31:0]
		matrix_i_x = matrix.i.x,
		matrix_i_y = matrix.i.y,
		matrix_i_z = matrix.i.z,
		matrix_i_w = matrix.i.w,
		matrix_j_x = matrix.j.x,
		matrix_j_y = matrix.j.y,
		matrix_j_z = matrix.j.z,
		matrix_j_w = matrix.j.w,
		matrix_k_x = matrix.k.x,
		matrix_k_y = matrix.k.y,
		matrix_k_z = matrix.k.z,
		matrix_k_w = matrix.k.w,
		matrix_l_x = matrix.l.x,
		matrix_l_y = matrix.l.y,
		matrix_l_z = matrix.l.z,
		matrix_l_w = matrix.l.w;

	wire[31:0]
		a_x = a.pos.x,
		a_y = a.pos.y,
		a_z = a.pos.z,
		a_u = a.tex.x,
		a_v = a.tex.y,
		b_x = b.pos.x,
		b_y = b.pos.y,
		b_z = b.pos.z,
		b_u = b.tex.x,
		b_v = b.tex.y,
		c_x = c.pos.x,
		c_y = c.pos.y,
		c_z = c.pos.z,
		c_u = c.tex.x,
		c_v = c.tex.y;

	wire[23:0] pixel_out_unpacked = `rgb666_unpack(pixel_out);
`endif



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
		x_maxed = x >= W_FULL-1,
		y_maxed = y >= H_FULL-1;

	assign
		blank[0] = x >= W,
		blank[1] = y >= H,
		sync[0]  = x >= W+H_FP+H_PAD && x < W+H_FP+H_PAD+H_SYNC,
		sync[1]  = y >= H+V_FP+V_PAD && y < H+V_FP+V_PAD+V_SYNC;

	always @(posedge clock)
		if (x_maxed && y_maxed) begin
			x <= 0;
			y <= 0;

		end else if (x_maxed) begin
			x <= 0;
			y <= y+1;

		end else
			x <= x+1;

endmodule

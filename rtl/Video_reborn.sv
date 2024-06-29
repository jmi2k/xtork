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

	typedef enum bit[5:0] {
		S_IDLE,

		S_XFORM_A_W,
		S_XFORM_B_W,
		S_XFORM_C_W,

		S_XFORM_A_X,
		S_XFORM_B_X,
		S_XFORM_C_X,

		S_XFORM_A_Y,
		S_XFORM_B_Y,
		S_XFORM_C_Y,

		S_XFORM_A_Z,
		S_XFORM_B_Z,
		S_XFORM_C_Z,

		S_XFORM_TAIL,

		S_NORMALIZE_X,
		S_NORMALIZE_Y,
		S_NORMALIZE_Z,

		S_INVERT_U,
		S_INVERT_V,

		S_AREA,

		S_WEIGHT_0,
		S_WEIGHT_1,
		S_WEIGHT_2,

		S_SETUP_RASTERIZER_1,
		S_SETUP_RASTERIZER_2,
		S_SETUP_RASTERIZER_3,

		S_RASTERIZING
	} State;

	State state = S_IDLE;
	assign busy = state != S_IDLE || pixels_in_flight;





	Mat4 matrix;

	Vertex
		a,
		b,
		c;

	// Transformed homogeneous coordinates.
	Vec4
		homo_a,
		homo_b,
		homo_c;

	// Normalized device coordinates.
	Vec4
		ndc_a,
		ndc_b,
		ndc_c;

	// Precomputed division results.
	bit[15:-16]
		one_over_w_a,
		one_over_w_b,
		one_over_w_c,
		u_a_over_w_a,
		u_b_over_w_b,
		u_c_over_w_c,
		v_a_over_w_a,
		v_b_over_w_b,
		v_c_over_w_c;

	// Screen-space rectangle for the triangle to be rasterized.
	bit signed[15:0]
		min_x,
		max_x,
		min_y,
		max_y;

	bit signed[15:0]
		x,
		y;

	// Top left pixel point of the rasterizer rect in screen space.
	wire Vec2 origin = { min_x, 16'h8000, min_y, 16'h8000 };

	// Screen-space vectors between vertices.
	wire Vec2
		a_to_b = `vec2_sub(ndc_b,  ndc_a),
		a_to_c = `vec2_sub(ndc_c,  ndc_a),
		b_to_c = `vec2_sub(ndc_c,  ndc_b),
		c_to_a = `vec2_sub(ndc_a,  ndc_c),
		a_to_o = `vec2_sub(origin, ndc_a),
		b_to_o = `vec2_sub(origin, ndc_b),
		c_to_o = `vec2_sub(origin, ndc_c);





	//   ███████   ███████    ██████   ███████   ██    ██   ██████  ████████
	//   ██    ██  ██    ██  ██    ██  ██    ██  ██    ██  ██          ██
	//   ███████   ███████   ██    ██  ██    ██  ██    ██  ██          ██
	//   ██        ██    ██  ██    ██  ██    ██  ██    ██  ██          ██
	//   ██        ██    ██   ██████   ███████    ██████    ██████     ██



	bit signed[31:0]
		l_1, r_1,
		l_2, r_2,
		l_3, r_3,
		l_4;   // `r_4` is hardwired to `1.0`

	bit signed[63:0]
		product_1,
		product_2,
		product_3,
		product_4;

	wire signed[65:0] product_sum =
		  product_1
		+ product_2
		+ product_3
		+ product_4;

	// TODO: rounding, saturation.
	wire signed[15:-16] matrix_row_result = product_sum >>> 16;



	always @(posedge clock) begin
		product_1 <= l_1  *  r_1;
		product_2 <= l_2  *  r_2;
		product_3 <= l_3  *  r_3;
		product_4 <= l_4 <<< 16;

	end





	//   ███████    ██████    ███████  ████████  ████████  ███████ 
	//   ██    ██  ██    ██  ██           ██     ██        ██    ██
	//   ███████   ████████   ██████      ██     ██████    ███████ 
	//   ██    ██  ██    ██        ██     ██     ██        ██    ██
	//   ██    ██  ██    ██  ███████      ██     ████████  ██    ██



	bit signed[15:-16]
		area_reciprocal,
		k_0_row,
		k_1_row,
		k_2_row,
		k_0,
		k_1,
		k_2,
		k_0_dx,
		k_1_dx,
		k_2_dx,
		k_0_dy,
		k_1_dy,
		k_2_dy;

	wire
		bias_0 = !b_to_c.y && !b_to_c.x[15] || !b_to_c.y[15],
		bias_1 = !c_to_a.y && !c_to_a.x[15] || !c_to_a.y[15],
		bias_2 = !a_to_b.y && !a_to_b.x[15] || !a_to_b.y[15];

	wire
		x_maxed = x >= max_x,
		y_maxed = y >= max_y;





	//   ████████   ███████  ██    ██
	//   ██        ██        ███  ███
	//   ███████    ██████   ██ ██ ██
	//   ██              ██  ██    ██
	//   ██        ███████   ██    ██


	bit[32:0] quotient_mask = 0;
	wire dividing = |quotient_mask[32:1];

	bit[32:0] next_quotient_mask = 0;

	bit[32:0]
		next_dividend_1,
		next_dividend_2,
		next_dividend_3;

	bit[32:0]
		dividend_1,
		dividend_2,
		dividend_3;

	bit[63:0]
		next_divisor_1,
		next_divisor_2,
		next_divisor_3;

	bit[63:0]
		divisor_1,
		divisor_2,
		divisor_3;

	bit[32:0]
		quotient_1,
		quotient_2,
		quotient_3;

	bit[11:0] color = 'hFFF;



	always @(posedge clock) begin

		if (dividing) begin
			quotient_mask <= quotient_mask >> 1;

			divisor_1 <= divisor_1 >> 1;
			divisor_2 <= divisor_2 >> 1;
			divisor_3 <= divisor_3 >> 1;

			if (dividend_1 >= divisor_1) begin
				dividend_1 <= dividend_1 - divisor_1[32:0];
				quotient_1 <= quotient_1 | quotient_mask;
			end

			if (dividend_2 >= divisor_2) begin
				dividend_2 <= dividend_2 - divisor_2[32:0];
				quotient_2 <= quotient_2 | quotient_mask;
			end

			if (dividend_3 >= divisor_3) begin
				dividend_3 <= dividend_3 - divisor_3[32:0];
				quotient_3 <= quotient_3 | quotient_mask;
			end

		end else begin
			dividend_1 <= next_dividend_1;
			dividend_2 <= next_dividend_1;
			dividend_3 <= next_dividend_1;

			divisor_1 <= next_divisor_1;
			divisor_2 <= next_divisor_2;
			divisor_3 <= next_divisor_3;

			quotient_1 <= 0;
			quotient_2 <= 0;
			quotient_3 <= 0;

			quotient_mask <= next_quotient_mask;

		end

	end



	always @(posedge clock) case (state)

		S_IDLE: if (fire) begin
			color <= color ^ 'hAAA;

			a <= a_in;
			b <= b_in;
			c <= c_in;
			matrix <= matrix_in;
			next_quotient_mask <= 0;

			state <= S_XFORM_A_W;

		end

		S_XFORM_A_W: begin
			l_1 <= matrix.l.x;
			l_2 <= matrix.l.y;
			l_3 <= matrix.l.z;
			l_4 <= matrix.l.w;

			r_1 <= a.pos.x;
			r_2 <= a.pos.y;
			r_3 <= a.pos.z;

			state <= S_XFORM_B_W;

		end

		S_XFORM_B_W: begin
			r_1 <= b.pos.x;
			r_2 <= b.pos.y;
			r_3 <= b.pos.z;

			state <= S_XFORM_C_W;

		end

		S_XFORM_C_W: begin
			homo_a.w <= matrix_row_result;

			r_1 <= c.pos.x;
			r_2 <= c.pos.y;
			r_3 <= c.pos.z;

			state <= S_XFORM_A_X;

		end

		S_XFORM_A_X: begin
			homo_b.w <= matrix_row_result;

			l_1 <= matrix.i.x;
			l_2 <= matrix.i.y;
			l_3 <= matrix.i.z;
			l_4 <= matrix.i.w;

			r_1 <= a.pos.x;
			r_2 <= a.pos.y;
			r_3 <= a.pos.z;

			state <= S_XFORM_B_X;

		end

		S_XFORM_B_X: begin
			homo_c.w <= matrix_row_result;

			r_1 <= b.pos.x;
			r_2 <= b.pos.y;
			r_3 <= b.pos.z;

			next_dividend_1 <= 'h1_0000_0000;
			next_dividend_2 <= 'h1_0000_0000;
			next_dividend_3 <= 'h1_0000_0000;

			next_divisor_1 <= homo_a.w <<< 32;
			next_divisor_2 <= homo_b.w <<< 32;
			next_divisor_3 <= matrix_row_result <<< 32;

			next_quotient_mask <= 'h1_0000_0000;

			state <= S_XFORM_C_X;

		end

		S_XFORM_C_X: begin
			homo_a.x <= matrix_row_result;

			r_1 <= c.pos.x;
			r_2 <= c.pos.y;
			r_3 <= c.pos.z;

			next_quotient_mask <= 0;

			state <= S_XFORM_A_Y;

		end

		S_XFORM_A_Y: begin
			homo_b.x <= matrix_row_result;

			l_1 <= matrix.j.x;
			l_2 <= matrix.j.y;
			l_3 <= matrix.j.z;
			l_4 <= matrix.j.w;

			r_1 <= a.pos.x;
			r_2 <= a.pos.y;
			r_3 <= a.pos.z;

			state <= S_XFORM_B_Y;

		end

		S_XFORM_B_Y: begin
			homo_c.x <= matrix_row_result;

			r_1 <= b.pos.x;
			r_2 <= b.pos.y;
			r_3 <= b.pos.z;

			state <= S_XFORM_C_Y;

		end

		S_XFORM_C_Y: begin
			homo_a.y <= matrix_row_result;

			r_1 <= c.pos.x;
			r_2 <= c.pos.y;
			r_3 <= c.pos.z;

			state <= S_XFORM_A_Z;

		end

		S_XFORM_A_Z: begin
			homo_b.y <= matrix_row_result;

			l_1 <= matrix.k.x;
			l_2 <= matrix.k.y;
			l_3 <= matrix.k.z;
			l_4 <= matrix.k.w;

			r_1 <= a.pos.x;
			r_2 <= a.pos.y;
			r_3 <= a.pos.z;

			state <= S_XFORM_B_Z;

		end

		S_XFORM_B_Z: begin
			homo_c.y <= matrix_row_result;

			r_1 <= b.pos.x;
			r_2 <= b.pos.y;
			r_3 <= b.pos.z;

			state <= S_XFORM_C_Z;

		end

		S_XFORM_C_Z: begin
			homo_a.z <= matrix_row_result;

			r_1 <= c.pos.x;
			r_2 <= c.pos.y;
			r_3 <= c.pos.z;

			state <= S_XFORM_TAIL;

		end

		S_XFORM_TAIL: begin
			homo_b.z <= matrix_row_result;

			state <= S_NORMALIZE_X;

		end

		S_NORMALIZE_X: if (!dividing) begin
			homo_c.z <= matrix_row_result;

			l_1 <= homo_a.x;
			l_2 <= homo_b.x;
			l_3 <= homo_c.x;

			r_1 <= quotient_1;
			r_2 <= quotient_2;
			r_3 <= quotient_3;

			one_over_w_a <= quotient_1;
			one_over_w_b <= quotient_2;
			one_over_w_c <= quotient_3;

			state <= S_NORMALIZE_Y;

		end

		S_NORMALIZE_Y: begin
			l_1 <= homo_a.y;
			l_2 <= homo_b.y;
			l_3 <= homo_c.y;

			state <= S_NORMALIZE_Z;

		end

		S_NORMALIZE_Z: begin
			l_1 <= homo_a.z;
			l_2 <= homo_b.z;
			l_3 <= homo_c.z;

			// TODO: rounding, saturation.
			ndc_a.x <= product_1 >>> 16;
			ndc_b.x <= product_2 >>> 16;
			ndc_c.x <= product_3 >>> 16;

			state <= S_INVERT_U;

		end

		S_INVERT_U: begin
			l_1 <= a.tex.x;
			l_2 <= b.tex.x;
			l_3 <= c.tex.x;

			// TODO: rounding, saturation.
			ndc_a.y <= product_1 >>> 16;
			ndc_b.y <= product_2 >>> 16;
			ndc_c.y <= product_3 >>> 16;

			state <= S_INVERT_V;

		end

		S_INVERT_V: begin
			l_1 <= a.tex.y;
			l_2 <= b.tex.y;
			l_3 <= c.tex.y;

			// TODO: rounding, saturation.
			ndc_a.z <= product_1 >>> 16;
			ndc_b.z <= product_2 >>> 16;
			ndc_c.z <= product_3 >>> 16;

			min_x <= `min(`min(ndc_a.x, ndc_b.x), ndc_c.x) >>> 16;
			max_x <= `max(`max(ndc_a.x, ndc_b.x), ndc_c.x) >>> 16;
			min_y <= `min(`min(ndc_a.y, ndc_b.y), ndc_c.y) >>> 16;
			max_y <= `max(`max(ndc_a.y, ndc_b.y), ndc_c.y) >>> 16;

			state <= S_AREA;

		end

		S_AREA: begin
			l_1 <= a_to_b.x;
			l_2 <= a_to_b.y;

			r_1 <= a_to_c.y;
			r_2 <= a_to_c.x;

			u_a_over_w_a <= product_1;
			u_b_over_w_b <= product_2;
			u_c_over_w_c <= product_3;

			min_x <= `max(min_x, -FRAME_W/SCALE/2);
			max_x <= `min(max_x,  FRAME_W/SCALE/2 - 1);
			min_y <= `max(min_y, -FRAME_H/SCALE/2);
			max_y <= `min(max_y,  FRAME_H/SCALE/2 - 1);

			state <= S_WEIGHT_0;

		end

		S_WEIGHT_0: begin
			l_1 <= b_to_c.x;
			l_2 <= b_to_c.y;

			r_1 <= b_to_o.y;
			r_2 <= b_to_o.x;

			v_a_over_w_a <= product_1;
			v_b_over_w_b <= product_2;
			v_c_over_w_c <= product_3;

			state <= S_WEIGHT_1;

		end

		S_WEIGHT_1: begin
			l_1 <= c_to_a.x;
			l_2 <= c_to_a.y;

			r_1 <= c_to_o.y;
			r_2 <= c_to_o.x;

			if (product_1 > product_2) begin
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
				next_dividend_1    <= 'h1_0000_0000;
				next_divisor_1     <= product_1 - product_2;
				next_quotient_mask <= 'h1_0000_0000;

				state <= S_WEIGHT_2;

			end else
				// Early abort for back-facing trianglws.
				state <= S_IDLE;

		end

		S_WEIGHT_2: begin
			// TODO: rounding, saturation.
			k_0_row <= (product_1 - product_2 >>> 16) - bias_0;

			l_1 <= a_to_b.x;
			l_2 <= a_to_b.y;

			r_1 <= a_to_o.y;
			r_2 <= a_to_o.x;

			next_quotient_mask <= 0;

			state <= S_SETUP_RASTERIZER_1;

		end

		S_SETUP_RASTERIZER_1: begin
			// TODO: rounding, saturation.
			k_1_row <= (product_1 - product_2 >>> 16) - bias_1;

			min_x <= min_x + FRAME_W/SCALE/2;
			max_x <= max_x + FRAME_W/SCALE/2;
			min_y <= min_y + FRAME_H/SCALE/2;
			max_y <= max_y + FRAME_H/SCALE/2;

			state <= S_SETUP_RASTERIZER_2;

		end

		S_SETUP_RASTERIZER_2: begin
			// TODO: rounding, saturation.
			k_2_row <= (product_1 - product_2 >>> 16) - bias_2;

			x <= min_x;
			y <= min_y;

			k_0_dx <= ndc_b.y - ndc_c.y;
			k_1_dx <= ndc_c.y - ndc_a.y;
			k_2_dx <= ndc_a.y - ndc_b.y;

			k_0_dy <= ndc_c.x - ndc_b.x;
			k_1_dy <= ndc_a.x - ndc_c.x;
			k_2_dy <= ndc_b.x - ndc_a.x;

			state <= S_SETUP_RASTERIZER_3;

		end

		S_SETUP_RASTERIZER_3: if (!dividing) begin
			k_0 <= k_0_row;
			k_1 <= k_1_row;
			k_2 <= k_2_row;

			area_reciprocal <= quotient_1;

			state <= S_RASTERIZING;

		end

		S_RASTERIZING: begin
			is_inside <= !(k_0[15] || k_1[15] || k_2[15]);

			raster_x <= x;
			raster_y <= y;

			l_1 <= k_0;
			r_1 <= area_reciprocal;

			l_2 <= k_1;
			r_2 <= area_reciprocal;

			l_3 <= k_2;
			r_3 <= area_reciprocal;

			if (x_maxed && y_maxed) begin
				state <= S_IDLE;

			end else if (x_maxed) begin
				x <= min_x;
				y <= y+1;

				k_0 <= k_0_row + k_0_dy;
				k_1 <= k_1_row + k_1_dy;
				k_2 <= k_2_row + k_2_dy;

				k_0_row <= k_0_row + k_0_dy;
				k_1_row <= k_1_row + k_1_dy;
				k_2_row <= k_2_row + k_2_dy;

			end else begin
				x <= x+1;

				k_0 <= k_0 + k_0_dx;
				k_1 <= k_1 + k_1_dx;
				k_2 <= k_2 + k_2_dx;

			end

		end

	endcase


	bit[7:0] pixels_in_flight = 0;
	bit is_inside;
	bit paint;

	bit[15:0]
		raster_x,
		raster_y;

	bit[15:0]
		paint_x,
		paint_y;

	bit[15:0]
		texture_x,
		texture_y;

	always @(posedge clock) begin
		paint_x <= raster_x;
		paint_y <= raster_y;

		paint <= is_inside;

	end

	wire[-1:-16]	
		alpha =  product_1[47:32],
		beta  =  product_2[47:32],
		gamma = -product_1[47:32] - product_2[47:32];

	wire[7:-24]
		raw_u = alpha * a.tex.x[7:-8] + beta * b.tex.x[7:-8] + gamma * c.tex.x[7:-8],
		raw_v = alpha * a.tex.y[7:-8] + beta * b.tex.y[7:-8] + gamma * c.tex.y[7:-8];

	wire[7:0]
		u = raw_u[7:0],
		v = raw_v[7:0];

	always @(posedge clock) begin
		texel_addr <= ATLAS_W * v + u;
		texture_x <= paint_x;
		texture_y <= paint_y;

		texel_strobe <= paint;

	end

	always @(posedge clock) begin
		pixel_addr <= FRAME_W/SCALE * texture_y + texture_x;
		pixel_out <= texel_in;

		pixel_strobe <= texel_ack;

	end

	always @(posedge clock)
		pixels_in_flight <= pixels_in_flight + paint - pixel_ack;



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

	wire[31:0]
		homo_a_x = homo_a.x,
		homo_a_y = homo_a.y,
		homo_a_z = homo_a.z,
		homo_a_w = homo_a.w,
		homo_b_x = homo_b.x,
		homo_b_y = homo_b.y,
		homo_b_z = homo_b.z,
		homo_b_w = homo_b.w,
		homo_c_x = homo_c.x,
		homo_c_y = homo_c.y,
		homo_c_z = homo_c.z,
		homo_c_w = homo_c.w;

	wire[31:0]
		ndc_a_x = ndc_a.x,
		ndc_a_y = ndc_a.y,
		ndc_a_z = ndc_a.z,
		ndc_a_u = ndc_a.x,
		ndc_a_v = ndc_a.y,
		ndc_b_x = ndc_b.x,
		ndc_b_y = ndc_b.y,
		ndc_b_z = ndc_b.z,
		ndc_b_u = ndc_b.x,
		ndc_b_v = ndc_b.y,
		ndc_c_x = ndc_c.x,
		ndc_c_y = ndc_c.y,
		ndc_c_z = ndc_c.z,
		ndc_c_u = ndc_c.x,
		ndc_c_v = ndc_c.y;
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

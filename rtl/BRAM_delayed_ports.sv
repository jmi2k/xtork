module BRAM #(
	parameter
		NUM_WORDS,
		BYTE_BITS,
		BYTES_PER_WORD,

		FILE = 'x,

	localparam
		WORD_BITS = BYTE_BITS * BYTES_PER_WORD,
		ADDR_BITS = $clog2(NUM_WORDS)
) (
	input wire                     clock_1,
	input wire[ADDR_BITS-1:0]      addr_1,
	input wire[WORD_BITS-1:0]      in_1,
	output bit[WORD_BITS-1:0]      out_1,
	input wire[BYTES_PER_WORD-1:0] select_1,
	input wire                     write_1,
	input wire                     strobe_1,
	output bit                     ack_1 = 0,
	output bit                     retry_1 = 0,

	input wire                     clock_2,
	input wire[ADDR_BITS-1:0]      addr_2,
	input wire[WORD_BITS-1:0]      in_2,
	output bit[WORD_BITS-1:0]      out_2,
	input wire[BYTES_PER_WORD-1:0] select_2,
	input wire                     write_2,
	input wire                     strobe_2,
	output bit                     ack_2 = 0,
	output bit                     retry_2 = 0
);

	(* ram_block, no_rw_check *)
	bit[WORD_BITS-1:0] data[NUM_WORDS];

	initial if (FILE !== 'x)
		$readmemh(FILE, data);

`ifdef PING_PONG_1
	bit ping_pong_1 = 0;
`endif

`ifdef PING_PONG_2
	bit ping_pong_2 = 0;
`endif

`ifdef DELAY_1_1
	bit
		ack_1_delay_0;

	bit[31:0]
		out_1_delay_0;

	always @(posedge clock_1) begin
		ack_1_delay_0 <= strobe_1;
`ifdef PING_PONG_1
		ack_1 <= ack_1_delay_0 & ping_pong_1;
		retry_1 <= ack_1_delay_0 & !ping_pong_1;
		ping_pong_1 <= ack_1_delay_0 ^ ping_pong_1;
`else
		ack_1 <= ack_1_delay_0;
`endif

		out_1_delay_0 <= data[addr_1];
		out_1 <= out_1_delay_0;
	end
`elsif DELAY_1_5
	bit
		ack_1_delay_0,
		ack_1_delay_1,
		ack_1_delay_2,
		ack_1_delay_3,
		ack_1_delay_4;

	bit[31:0]
		out_1_delay_0,
		out_1_delay_1,
		out_1_delay_2,
		out_1_delay_3,
		out_1_delay_4;

	always @(posedge clock_1) begin
		ack_1_delay_0 <= strobe_1;
		ack_1_delay_1 <= ack_1_delay_0;
		ack_1_delay_2 <= ack_1_delay_1;
		ack_1_delay_3 <= ack_1_delay_2;
		ack_1_delay_4 <= ack_1_delay_3;
`ifdef PING_PONG_1
		ack_1 <= ack_1_delay_4 & ping_pong_1;
		retry_1 <= ack_1_delay_4 & !ping_pong_1;
		ping_pong_1 <= ack_1_delay_4 ^ ping_pong_1;
`else
		ack_1 <= ack_1_delay_4;
`endif

		out_1_delay_0 <= data[addr_1];
		out_1_delay_1 <= out_1_delay_0;
		out_1_delay_2 <= out_1_delay_1;
		out_1_delay_3 <= out_1_delay_2;
		out_1_delay_4 <= out_1_delay_3;
		out_1 <= out_1_delay_4;
	end
`else
	always @(posedge clock_1) begin
		out_1 <= data[addr_1];
`ifdef PING_PONG_1
		ack_1 <= strobe_1 & ping_pong_1;
		retry_1 <= strobe_1 & !ping_pong_1;
		ping_pong_1 <= strobe_1 ^ ping_pong_1;
`else
		ack_1 <= strobe_1;
`endif

	end
`endif

`ifdef DELAY_2_2
	bit
		ack_2_delay_0,
		ack_2_delay_1;

	bit[31:0]
		out_2_delay_0,
		out_2_delay_1;

	always @(posedge clock_2) begin
		ack_2_delay_0 <= strobe_2;
		ack_2_delay_1 <= ack_2_delay_0;
`ifdef PING_PONG_2
		ack_2 <= ack_2_delay_1 & ping_pong_2;
		retry_2 <= ack_2_delay_1 & !ping_pong_2;
		ping_pong_2 <= ack_2_delay_1 ^ ping_pong_2;
`else
		ack_2 <= ack_2_delay_1;
`endif

		out_2_delay_0 <= data[addr_2];
		out_2_delay_1 <= out_2_delay_0;
		out_2 <= out_2_delay_1;
	end
`elsif DELAY_2_5
	bit
		ack_2_delay_0,
		ack_2_delay_1,
		ack_2_delay_2,
		ack_2_delay_3,
		ack_2_delay_4;

	bit[31:0]
		out_2_delay_0,
		out_2_delay_1,
		out_2_delay_2,
		out_2_delay_3,
		out_2_delay_4;

	always @(posedge clock_2) begin
		ack_2_delay_0 <= strobe_2;
		ack_2_delay_1 <= ack_2_delay_0;
		ack_2_delay_2 <= ack_2_delay_1;
		ack_2_delay_3 <= ack_2_delay_2;
		ack_2_delay_4 <= ack_2_delay_3;
`ifdef PING_PONG_2
		ack_2 <= ack_2_delay_4 & ping_pong_2;
		retry_2 <= ack_2_delay_4 & !ping_pong_2;
		ping_pong_2 <= ack_2_delay_4 ^ ping_pong_2;
`else
		ack_2 <= ack_2_delay_4;
`endif

		out_2_delay_0 <= data[addr_2];
		out_2_delay_1 <= out_2_delay_0;
		out_2_delay_2 <= out_2_delay_1;
		out_2_delay_3 <= out_2_delay_2;
		out_2_delay_4 <= out_2_delay_3;
		out_2 <= out_2_delay_4;
	end
`elsif DELAY_2_7
	bit
		ack_2_delay_0,
		ack_2_delay_1,
		ack_2_delay_2,
		ack_2_delay_3,
		ack_2_delay_4,
		ack_2_delay_5,
		ack_2_delay_6;

	bit[31:0]
		out_2_delay_0,
		out_2_delay_1,
		out_2_delay_2,
		out_2_delay_3,
		out_2_delay_4,
		out_2_delay_5,
		out_2_delay_6;

	always @(posedge clock_2) begin
		ack_2_delay_0 <= strobe_2;
		ack_2_delay_1 <= ack_2_delay_0;
		ack_2_delay_2 <= ack_2_delay_1;
		ack_2_delay_3 <= ack_2_delay_2;
		ack_2_delay_4 <= ack_2_delay_3;
		ack_2_delay_5 <= ack_2_delay_4;
		ack_2_delay_6 <= ack_2_delay_5;
`ifdef PING_PONG_2
		ack_2 <= ack_2_delay_6 & ping_pong_2;
		retry_2 <= ack_2_delay_6 & !ping_pong_2;
		ping_pong_2 <= ack_2_delay_6 ^ ping_pong_2;
`else
		ack_2 <= ack_2_delay_6;
`endif

		out_2_delay_0 <= data[addr_2];
		out_2_delay_1 <= out_2_delay_0;
		out_2_delay_2 <= out_2_delay_1;
		out_2_delay_3 <= out_2_delay_2;
		out_2_delay_4 <= out_2_delay_3;
		out_2_delay_5 <= out_2_delay_4;
		out_2_delay_6 <= out_2_delay_5;
		out_2 <= out_2_delay_6;
	end
`else
	always @(posedge clock_2) begin
		out_2 <= data[addr_2];
`ifdef PING_PONG_2
		ack_2 <= strobe_2 & ping_pong_2;
		retry_2 <= strobe_2 & !ping_pong_2;
		ping_pong_2 <= strobe_2 ^ ping_pong_2;
`else
		ack_2 <= strobe_2;
`endif

	end
`endif

	for (genvar idx = 0; idx < BYTES_PER_WORD; idx++) begin

		// This crap written twice per line looks disgusting.
`define SLICE   BYTE_BITS*idx +: BYTE_BITS

		wire
			writing_1 = strobe_1 && select_1[idx] && write_1,
			writing_2 = strobe_2 && select_2[idx] && write_2;

		always @(posedge clock_1) if (writing_1)
			data[addr_1][`SLICE] <= in_1[`SLICE];

		always @(posedge clock_2) if (writing_2)
			data[addr_2][`SLICE] <= in_2[`SLICE];

`undef SLICE

	end

endmodule

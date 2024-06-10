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

	always @(posedge clock_1) begin
		out_1 <= data[addr_1];
		ack_1 <= strobe_1;

	end

	always @(posedge clock_2) begin
		out_2 <= data[addr_2];
		ack_2 <= strobe_2;

	end

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

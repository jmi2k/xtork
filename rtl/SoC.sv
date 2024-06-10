// `define DELAY_1_1
// `define DELAY_1_5
// `define DELAY_2_2
// `define DELAY_2_5
// `define DELAY_2_7
// `define PING_PONG_1
// `define PING_PONG_2

`include "rtl/types.svh"
`include "rtl/BRAM.sv"
`include "rtl/RISCV.sv"
`include "rtl/UART.sv"
`include "rtl/Video.sv"

module SoC(
	// 25 MHz
	input wire       board_clock,

	// iCELink UART
	output wire      icelink_tx,
	input wire       icelink_rx,

	// 4×PMOD
	output wire[15:0] port_2
);

`ifndef DUMP
	wire bus_clock;

	// 77.5 MHz
	OSCG #(4) osc(bus_clock);
`else
	bit bus_clock = 0;

	// 77.5 MHz
	always #(1s / (310e6/4) / 2)
		bus_clock <= !bus_clock;
`endif

	// Video adapter.
	wire RGB_444 pixel;
	wire[1:0] sync;

	assign port_2 = {
		pixel.b[3], pixel.b[2], pixel.b[1], pixel.b[0],
		pixel.r[3], pixel.r[2], pixel.r[1], pixel.r[0],
		!sync[0],   !sync[1],   1'bx,       1'bx,
		pixel.g[3], pixel.g[2], pixel.g[1], pixel.g[0]
	};

	// Instruction port
	wire[31:0] next_pc;
	wire[31:0] inst_in;
	wire inst_strobe, inst_ack, inst_retry;

	// Data port
	wire[27:0] addr;
	wire[31:0] cpu_in, cpu_out;
	wire[3:0] select;
	wire write, data_strobe, data_ack, data_retry;

	// Data bus
	wire[31:0] ram_out, icelink_out, video_out;
	wire ram_ack, icelink_ack, video_ack;
	wire ram_retry, icelink_retry, video_retry;
	bit from_ram, from_icelink, from_video;

	wire
		to_ram     = 'b00 == addr[27:26],
		to_icelink = 'b10 == addr[27:26],
		to_video   = 'b11 == addr[27:26];

	assign cpu_in =
		  (from_ram ?       ram_out       : 0)
		| (from_icelink ?   icelink_out   : 0)
		| (from_video ?     video_out     : 0);

	assign data_ack =
		ram_ack ||
		icelink_ack ||
		video_ack;

	assign data_retry =
		ram_retry ||
		icelink_retry ||
		video_retry;

	always @(posedge bus_clock) if (data_strobe) begin
		from_ram <= to_ram;
		from_icelink <= to_icelink;
		from_video <= to_video;

	end

	BRAM #(
		.FILE("build/firmware.hex"),
		.NUM_WORDS(4_096),
		.BYTE_BITS(8),
		.BYTES_PER_WORD(4)
	) ram(
		.clock_1(bus_clock),
		.addr_1(next_pc[13:2]),
		.out_1(inst_in),
		.write_1(0),
		.select_1('b1111),
		.strobe_1(inst_strobe),
		.ack_1(inst_ack),
		.retry_1(inst_retry),

		.clock_2(bus_clock),
		.addr_2(addr[25:0]),
		.in_2(cpu_out),
		.out_2(ram_out),
		.write_2(write),
		.select_2(select),
		.strobe_2(data_strobe && to_ram),
		.ack_2(ram_ack),
		.retry_2(ram_retry)
	);

	UART #(
		.WORD_BITS(32)
	) icelink(
		.clock(bus_clock),
		.tx(icelink_tx),
		.rx(icelink_rx),

		.addr,
		.in(cpu_out),
		.out(icelink_out),
		.write,
		.select(|select),
		.strobe(data_strobe && to_icelink),
		.ack(icelink_ack),
		.retry(icelink_retry)
	);

	Video #(
		.BYTE_BITS(8),
		.BYTES_PER_WORD(4),

		// The board clock is slightly slower than the VGA standard dictates.
		// Making the vertical blanking interval shorter compensates that.
		.V_FP(9),
		.V_SYNC(2),
		.V_BP(31)
	) video(
		.pixel_clock(board_clock),
		.pixel,
		.sync,

		.bus_clock,
		.addr(addr[25:0]),
		.in(cpu_out),
		.out(video_out),
		.write,
		.select,
		.strobe(data_strobe && to_video),
		.ack(video_ack),
		.retry(video_retry)
	);

	RISCV #(
		.ADDR_BITS(28)
	) cpu(
		.clock(bus_clock),
		.next_pc,
		.inst_in,
		.inst_strobe,
		.inst_ack,
		.inst_retry,

		.addr,
		.data_in(cpu_in),
		.data_out(cpu_out),
		.select,
		.write,
		.data_strobe,
		.data_ack,
		.data_retry
	);

endmodule

`timescale 1ns/100ps

`include "rtl/SoC.sv"

module Test;

	localparam
		T_CLOCK = 1s / `FCLK,
		T_BAUD  = 1s / `BAUDS;

	bit board_clock = 0;
	bit icelink_rx = 1;

	always #(T_CLOCK/2)
		board_clock <= !board_clock;

	SoC soc(
		.board_clock,
		.icelink_rx
	);

	initial begin
		$dumpfile(`DUMP);
		$dumpvars;

		#600us icelink_rx <= 0;

		#T_BAUD icelink_rx <= 1;
		#T_BAUD icelink_rx <= 0;
		#T_BAUD icelink_rx <= 0;
		#T_BAUD icelink_rx <= 0;
		#T_BAUD icelink_rx <= 0;
		#T_BAUD icelink_rx <= 0;
		#T_BAUD icelink_rx <= 1;
		#T_BAUD icelink_rx <= 0;

		#T_BAUD icelink_rx <= 1;

		#600us $finish;
	end

endmodule
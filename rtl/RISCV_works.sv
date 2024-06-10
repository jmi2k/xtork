`define ZMMUL

typedef struct packed {
	bit[6:0] funct_7;
	bit[4:0] rs_2;
	bit[4:0] rs_1;
	bit[2:0] funct_3;
	bit[4:0] rd;
	bit[4:0] op;
	bit[1:0] unused_0;
} RISCV_Inst;

module RISCV #(
	parameter
		ADDR_BITS = 32,
		RESET_PC  = 0
) (
	input wire                 clock,

	output wire[31:0]          next_pc,
	input wire RISCV_Inst      inst_in,
	output wire                inst_strobe,
	input wire                 inst_ack,
	input wire                 inst_retry,

	output wire[ADDR_BITS-1:0] addr,
	input wire[31:0]           data_in,
	output bit[31:0]           data_out = 0,
	output bit[3:0]            select = 0,
	output bit                 write = 0,
	output bit                 data_strobe = 0,
	input wire                 data_ack,
	input wire                 data_retry
);

	// TODO: optimize load latency

	// Helpers to extract immediates from an instruction
`define u(i)     32'(        { i[31], i[30:12],                  12'h000 } )
`define i(i)     32'($signed({ i[31], i[30:20]                           }))
`define s(i)     32'($signed({ i[31], i[30:25], i[11:7]                  }))
`define b(i)     32'($signed({ i[31], i[7], i[30:25], i[11:8],      1'b0 }))
`define j(i)     32'($signed({ i[31], i[19:12], i[20], i[30:21],    1'b0 }))
`define csr(i)              ({ i.funct_7, i.rs_2                         })

	bit[31:0] registers[32];
	bit kickstart = 1;

	bit[31:0] pc = RESET_PC;
	bit[31:0] jump_target;
	bit ignore_inst = 0;
	bit take_jump = 1;
	bit await_memory = 0;

	bit forward_execute[2];

	always @(posedge clock)
		kickstart <= 0;

	/* ───────────────────────────────────────────────────────────────────────┐
	                                FETCH STAGE
	 └─────────────────────────────────────────────────────────────────────── */

	assign inst_strobe = kickstart || inst_ack || inst_retry;

	assign next_pc =
		take_jump ?     jump_target  :
		ignore_inst ?   pc           :
		lock_fetch ?    pc           :
		/* else ? */    pc+4;

	// Registered output
	bit[31:0] fetched_pc;
	RISCV_Inst fetched_inst;
	bit fetched;

	// Stage interlock
	wire lock_fetch = fetched && lock_decode;

	always @(posedge clock)

		if (lock_fetch) begin

			// Do nothing

		end else if (take_jump) begin

			pc <= jump_target;
			ignore_inst <= !inst_ack;
			fetched <= 0;

		end else if (inst_ack) begin

			fetched_pc <= pc;
			fetched_inst <= inst_in;

			pc <= next_pc;
			ignore_inst <= 0;
			fetched <= !ignore_inst;

		end else begin

			fetched <= 0;

		end

	/* ───────────────────────────────────────────────────────────────────────┐
	                                DECODE STAGE
	 └─────────────────────────────────────────────────────────────────────── */

	// Registered output
	bit[31:0] decoded_pc;
	RISCV_Inst decoded_inst;
	bit[31:0] values[2];
	bit register_arg;
	bit lui, auipc, jal, jalr, branch, load, store, alu, alur, system;
	bit add, sub, sll, slt, sltu, bxor, srl, sra, bor, band;
	bit beq, bne, blt, bge, bltu, bgeu;
`ifdef ZMMUL
	bit mul, mulh, mulhsu, mulhu, mulhxx;
`endif
	bit csrrw, csrrs, csrrc, csrrx;
	bit ecall, ebreak;
	bit foo;
	bit[31:0] bar;
	bit decoded;

	// Stage interlock
	wire lock_decode = decoded && lock_execute;

	always @(posedge clock)

		if (lock_decode) begin

			// Do nothing

		end else if (take_jump) begin

			decoded <= 0;

		end else if (fetched) begin

			decoded_pc <= fetched_pc;
			decoded_inst <= fetched_inst;

			register_arg <=
				'b11000 == fetched_inst.op ||   // branch
				'b01100 == fetched_inst.op ||   // alur
				'b01000 == fetched_inst.op;     // store

			values[0] <=
				( (save_result && rd == fetched_inst.rs_1) ?   result                         : 0) |
				(!(save_result && rd == fetched_inst.rs_1) ?   registers[fetched_inst.rs_1]   : 0);

			values[1] <=
				( (save_result && rd == fetched_inst.rs_2) ?   result                         : 0) |
				(!(save_result && rd == fetched_inst.rs_2) ?   registers[fetched_inst.rs_2]   : 0);

			// Decode instruction kind
			lui    <= 'b01101 == fetched_inst.op;
			auipc  <= 'b00101 == fetched_inst.op;
			jal    <= 'b11011 == fetched_inst.op;
			jalr   <= 'b11001 == fetched_inst.op;
			branch <= 'b11000 == fetched_inst.op;
			load   <= 'b00000 == fetched_inst.op;
			store  <= 'b01000 == fetched_inst.op;
			alu    <= 'b00100 == fetched_inst.op;
			alur   <= 'b01100 == fetched_inst.op;
			system <= 'b11100 == fetched_inst.op;

			// Decode ALU operation
			add  <= 'b000_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]) && !(fetched_inst[30] && fetched_inst[5]);
			sub  <= 'b000_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]) &&  (fetched_inst[30] && fetched_inst[5]);
			sll  <= 'b001_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]);
			slt  <= 'b010_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]);
			sltu <= 'b011_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]);
			bxor <= 'b100_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]);
			srl  <= 'b101_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]) &&  !fetched_inst[30];
			sra  <= 'b101_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]) &&   fetched_inst[30];
			bor  <= 'b110_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]);
			band <= 'b111_0 == { fetched_inst.funct_3, fetched_inst[2] } && !(fetched_inst[25] && fetched_inst[5]);

			// Decode predicate operation
			beq  <= 'b11000_000 == { fetched_inst.op, fetched_inst.funct_3 };
			bne  <= 'b11000_001 == { fetched_inst.op, fetched_inst.funct_3 };
			blt  <= 'b11000_100 == { fetched_inst.op, fetched_inst.funct_3 };
			bge  <= 'b11000_101 == { fetched_inst.op, fetched_inst.funct_3 };
			bltu <= 'b11000_110 == { fetched_inst.op, fetched_inst.funct_3 };
			bgeu <= 'b11000_111 == { fetched_inst.op, fetched_inst.funct_3 };

			// Decode CSR instructions
			csrrw <= 'b11100_01 == { fetched_inst.op, fetched_inst.funct_3[2:0] };
			csrrs <= 'b11100_10 == { fetched_inst.op, fetched_inst.funct_3[2:0] };
			csrrc <= 'b11100_11 == { fetched_inst.op, fetched_inst.funct_3[2:0] };
			csrrx <= 'b11100    ==   fetched_inst.op && |fetched_inst.funct_3;

			// Decode system instruction
			ecall  <= 'b000000000000_00000_000_00000_1110011 == fetched_inst;
			ebreak <= 'b000000000001_00000_000_00000_1110011 == fetched_inst;

`ifdef ZMMUL
			// Decode M operation
			mul    <= 'b000_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25];
			mulh   <= 'b001_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25];
			mulhsu <= 'b010_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25];
			mulhu  <= 'b011_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25];

			mulhxx <=
				'b001_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25] ||
				'b010_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25] ||
				'b011_01100 == { fetched_inst.funct_3, fetched_inst.op } && fetched_inst[25];
`endif

			foo <=
				'b01101 == fetched_inst.op ||   // lui
				'b00101 == fetched_inst.op ||   // auipc
				'b11011 == fetched_inst.op ||   // jal
				'b11001 == fetched_inst.op;     // jalr

			bar <=
				('b01101 == fetched_inst.op ?      `u(fetched_inst)             : 0) |
				('b00101 == fetched_inst.op ?   fetched_pc + `u(fetched_inst)   : 0) |
				('b11011 == fetched_inst.op ?   fetched_pc + 4                  : 0) |
				('b11001 == fetched_inst.op ?   fetched_pc + 4                  : 0);

			decoded <= 1;

		end else begin

			decoded <= 0;

		end

	/* ───────────────────────────────────────────────────────────────────────┐
	                               EXECUTE STAGE
	 └─────────────────────────────────────────────────────────────────────── */

	bit[ADDR_BITS+1:0] full_addr;
	wire[1:0] offset;

	assign { addr, offset } = full_addr;

	wire[31:0] left =
		( forward_execute[0] ?   result      : 0) |
		(!forward_execute[0] ?   values[0]   : 0);

	wire[31:0] right =
		(!register_arg ?                          `i(decoded_inst)   : 0) |
		( register_arg &&  forward_execute[1] ?   result             : 0) |
		( register_arg && !forward_execute[1] ?   values[1]          : 0);

	bit access_byte, access_half, access_word;

	wire[15:0] data_half =
		offset[1] ? data_in[31:16] : data_in[15:0];

	wire[7:0] data_byte =
		(offset == 0 ?   data_in[7:0]     : 0) |
		(offset == 1 ?   data_in[15:8]    : 0) |
		(offset == 2 ?   data_in[23:16]   : 0) |
		(offset == 3 ?   data_in[31:24]   : 0);

	wire[31:0] next_addr =
		(store ?   `s(decoded_inst) + left   : 0) |
		(load ?    `i(decoded_inst) + left   : 0);

	// Registered output
`ifdef DUMP
	bit[31:0] executed_pc;
	RISCV_Inst executed_inst;
`endif
	bit[4:0] rd;
	bit load_memory;
	bit save_result;
	bit executed;
	bit exec_was_mul;

`ifdef ZMMUL
	bit[31:0] results[4];

	wire signed[32:0] mul_left =
		mulhu
			?   33'($unsigned(left))
			:   33'($signed(left));

	wire signed[32:0] mul_right =
		mulhu || mulhsu
			?   33'($unsigned(right))
			:   33'($signed(right));

	wire signed[63:0] full_mul = 64'(mul_left) * 64'(mul_right);

	wire[31:0] result =
		results[0] |
		results[1] |
		results[2] |
		results[3];
`else
	bit[31:0] results[2];

	wire[31:0] result = results[0] | results[1];
`endif

	// Stage interlock
	wire lock_execute = await_memory;

	always @(posedge clock)

		if (lock_execute) begin

			// TODO: sign
			results[0] <=
				(access_byte ?   data_byte   : 0) |
				(access_half ?   data_half   : 0) |
				(access_word ?   data_in     : 0);

			data_strobe <= data_retry;
			await_memory <= !data_ack;

		end else if (take_jump) begin

			take_jump <= 0;
			executed <= 0;

		end else if (decoded) begin

			access_byte <= 'b00 == decoded_inst.funct_3[1:0];
			access_half <= 'b01 == decoded_inst.funct_3[1:0];
			access_word <= 'b10 == decoded_inst.funct_3[1:0];

			full_addr <= next_addr;

			select <=
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 0 ?   'b0001   : 0) |
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 1 ?   'b0010   : 0) |
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 2 ?   'b0100   : 0) |
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 3 ?   'b1000   : 0) |
				('b01 == decoded_inst.funct_3[1:0] &&  !next_addr[1] ?        'b0011   : 0) |
				('b01 == decoded_inst.funct_3[1:0] &&   next_addr[1] ?        'b1100   : 0) |
				('b10 == decoded_inst.funct_3[1:0] ?                          'b1111   : 0);

			data_strobe <= load || store;
			write <= store;

			data_out <=
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 0 ?   right[7:0]           : 0) |
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 1 ?   right[7:0]   << 8    : 0) |
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 2 ?   right[7:0]   << 16   : 0) |
				('b00 == decoded_inst.funct_3[1:0] && next_addr[1:0] == 3 ?   right[7:0]   << 24   : 0) |
				('b01 == decoded_inst.funct_3[1:0] &&  !next_addr[1] ?        right[15:0]          : 0) |
				('b01 == decoded_inst.funct_3[1:0] &&   next_addr[1] ?        right[31:16] << 16   : 0) |
				('b10 == decoded_inst.funct_3[1:0] ?                          right                : 0);

			await_memory <= load || store;

			jump_target <=
				(jal ?      `j(decoded_inst) + decoded_pc   : 0) |
				(jalr ?     `i(decoded_inst) + left         : 0) |
				(branch ?   `b(decoded_inst) + decoded_pc   : 0);

			take_jump <=
				(beq ?             left == right            : 0) |
				(bne ?             left != right            : 0) |
				(blt ?    $signed(left) <  $signed(right)   : 0) |
				(bge ?    $signed(left) >= $signed(right)   : 0) |
				(bltu ?            left <  right            : 0) |
				(bgeu ?            left >= right            : 0) |
				(                   jal || jalr                );

`ifdef DUMP
			executed_pc <= decoded_pc;
			executed_inst <= decoded_inst;
`endif

			rd <= decoded_inst.rd;

			// TODO: M extension
			results[0] <=
				(foo ?                   bar                  : 0) |
				(add ?              left  +  right            : 0) |
				(sub ?              left  -  right            : 0) |
				(slt ?     $signed(left)  <  $signed(right)   : 0) |
				(sltu ?             left  <  right            : 0) |
				(bxor ?             left  ^  right            : 0) |
				(bor ?              left  |  right            : 0) |
				(band ?             left  &  right            : 0) |
				(csrrx ?              csr_value               : 0);

			results[1] <=
				(sll ?              left <<  right[4:0]       : 0) |
				(srl ?              left  >> right[4:0]       : 0) |
				(sra ?              left >>> right[4:0]       : 0);

`ifdef ZMMUL
			results[2] <=
				(mul ?             full_mul[31:0]             : 0);

			results[3] <=
				(mulhxx ?          full_mul[63:32]            : 0);

			exec_was_mul <= mul || mulhxx;
`endif

			forward_execute[0] <=
				decoded_inst.rd &&
				!branch &&
				!store &&
				decoded_inst.rd == fetched_inst.rs_1;

			forward_execute[1] <=
				decoded_inst.rd &&
				!branch &&
				!store &&
				decoded_inst.rd == fetched_inst.rs_2;

			save_result <=
				decoded_inst.rd &&
				!branch &&
				!store;

			executed <= 1;

		end else begin

			take_jump <= 0;
			executed <= 0;

		end

	/* ──────────────────────────────────────────────────────────────────────┐
	                                SAVE STAGE
	 └────────────────────────────────────────────────────────────────────── */

	always @(posedge clock)

		if (save_result)
			registers[rd] <= result;

	/* ──────────────────────────────────────────────────────────────────────┐
	                                 CSR LOGIC
	 └────────────────────────────────────────────────────────────────────── */

	// TODO: instret
	bit[63:0]
		cycle   = 0,
		instret = 0;

	always @(posedge clock)
		cycle <= cycle+1;

	wire[31:0] csr_value =
		('hC00 == `csr(decoded_inst) ?   cycle[31:0]      : 0) |
		('hC01 == `csr(decoded_inst) ?   cycle[31:0]      : 0) |
		('hC02 == `csr(decoded_inst) ?   instret[31:0]    : 0) |
		('hC80 == `csr(decoded_inst) ?   cycle[63:32]     : 0) |
		('hC81 == `csr(decoded_inst) ?   cycle[63:32]     : 0) |
		('hC82 == `csr(decoded_inst) ?   instret[63:32]   : 0);

`undef u
`undef i
`undef s
`undef b
`undef j
`undef csr

`ifdef DUMP
	wire[31:0]
		x_1  = registers[1],
		x_2  = registers[2],
		x_3  = registers[3],
		x_4  = registers[4],
		x_5  = registers[5],
		x_6  = registers[6],
		x_7  = registers[7],
		x_8  = registers[8],
		x_9  = registers[9],
		x_10 = registers[10],
		x_11 = registers[11],
		x_12 = registers[12],
		x_13 = registers[13],
		x_14 = registers[14],
		x_15 = registers[15],
		x_16 = registers[16],
		x_17 = registers[17],
		x_18 = registers[18],
		x_19 = registers[19],
		x_20 = registers[20],
		x_21 = registers[21],
		x_22 = registers[22],
		x_23 = registers[23],
		x_24 = registers[24],
		x_25 = registers[25],
		x_26 = registers[26],
		x_27 = registers[27],
		x_28 = registers[28],
		x_29 = registers[29],
		x_30 = registers[30],
		x_31 = registers[31];

	wire[31:0]
		ra   = registers[1],
		sp   = registers[2],
		gp   = registers[3],
		tp   = registers[4],
		t_0  = registers[5],
		t_1  = registers[6],
		t_2  = registers[7],
		fp   = registers[8],
		s_0  = registers[8],
		s_1  = registers[9],
		a_0  = registers[10],
		a_1  = registers[11],
		a_2  = registers[12],
		a_3  = registers[13],
		a_4  = registers[14],
		a_5  = registers[15],
		a_6  = registers[16],
		a_7  = registers[17],
		s_2  = registers[18],
		s_3  = registers[19],
		s_4  = registers[20],
		s_5  = registers[21],
		s_6  = registers[22],
		s_7  = registers[23],
		s_8  = registers[24],
		s_9  = registers[25],
		s_10 = registers[26],
		s_11 = registers[27],
		t_3  = registers[28],
		t_4  = registers[29],
		t_5  = registers[30],
		t_6  = registers[31];
`endif

endmodule

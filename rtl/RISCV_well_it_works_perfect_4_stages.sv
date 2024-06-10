module RISCV #(
	parameter
		ADDR_BITS = 32,
		RESET_PC  = 0
) (
	input wire                 clock,

	output wire[31:0]          next_pc,
	input wire[31:0]           inst_in,
	output wire                inst_strobe,
	input wire                 inst_ack,
	input wire                 inst_retry,

	output wire[ADDR_BITS-1:0] addr,
	input wire[31:0]           data_in,
	output wire[31:0]          data_out,
	output wire[3:0]           select,
	output wire                write,
	output wire                data_strobe,
	input wire                 data_ack,
	input wire                 data_retry
);

	// TODO: LOAD sign.
	// TODO: memory I/O retry support.
	// TODO: clean up.

	// Instruction opcodes.
	localparam
		LUI    = 'b01101_11,
		AUIPC  = 'b00101_11,
		JALI   = 'b11011_11,
		JALR   = 'b11001_11,
		BRANCH = 'b11000_11,
		LOAD   = 'b00000_11,
		STORE  = 'b01000_11,
		ALUR   = 'b01100_11,
		ALUI   = 'b00100_11,
		ALU    = 'b0?100_11,
		SYSTEM = 'b11100_11;

	// Helpers to extract instruction slices
`define i(i)          32'($signed({ i[31], i[30:20] }))
`define s(i)          32'($signed({ i[31], i[30:25], i[11:7] }))
`define b(i)          32'($signed({ i[31], i[7], i[30:25], i[11:8], 1'b0 }))
`define u(i)                  32'({ i[31], i[30:12], 12'h000 })
`define j(i)          32'($signed({ i[31], i[19:12], i[20], i[30:21], 1'b0 }))
`define op(i)                       i[6:0]
`define rd(i)                       i[11:7]
`define funct_3(i)                  i[14:12]
`define rs_1(i)                     i[19:15]
`define rs_2(i)                     i[24:20]
`define funct_12(i)                 i[31:20]
`define funct_7(i)                  i[31:25]
`define sign(i)                     i[31]
`define csr(i)            `funct_12(i)

	// Helpers to test instruction kind.
	// These are optimized for efficiency and will give false positives for
	// illegal or unimplemented instructions.
`define lui(i)      (`op(i) == LUI)
`define auipc(i)    (`op(i) == AUIPC)
`define jali(i)     (`op(i) == JALI)
`define jalr(i)     (`op(i) == JALR)
`define branch(i)   (`op(i) == BRANCH)
`define load(i)     (`op(i) == LOAD)
`define store(i)    (`op(i) == STORE)
`define alui(i)     (`op(i) == ALUI)
`define alur(i)     (`op(i) == ALUR)
`define system(i)   (`op(i) == SYSTEM)
	// ALU-specific decoders.
	// "s" stands for simple — every I operation.
	// "m" stands for multiplication — every Zmmul operation.
`define alurs(i)    (`alur(i) && !i[25])
`define alurm(i)    (`alur(i) &&  i[25])
`define alus(i)     (`alui(i) || `alurs(i))
	// Branch-specific decoders.
`define bltge(i)    (`branch(i) && i[14])
	// ALU-specific decoders.
`define add(i)      (`alui(i)  && `funct_3(i) == 'b000 || \
                     `alurs(i) && `funct_3(i) == 'b000 && !i[30])
`define sub(i)      (`alurs(i) && `funct_3(i) == 'b000 &&  i[30])
`define sl(i)       (`alus(i)  && `funct_3(i) == 'b001)
`define slt(i)      (`alus(i)  && i[14:13]    == 'b01_)
`define bxor(i)     (`alus(i)  && `funct_3(i) == 'b100)
`define sr(i)       (`alus(i)  && `funct_3(i) == 'b101)
`define bor(i)      (`alus(i)  && `funct_3(i) == 'b110)
`define band(i)     (`alus(i)  && `funct_3(i) == 'b111)
	// Zmmul-specific decoders.
`define mul(i)      (`alurm(i) && i[13:12] == 'b00)
`define mulh(i)     (`alurm(i) && i[13:12] != 'b00)
`define mulhs(i)    (`alurm(i) && i[13:12] == 'b01)
`define mulhsu(i)   (`alurm(i) && i[13:12] == 'b10)
`define mulhu(i)    (`alurm(i) && i[13:12] == 'b11)
	// Zicsr-specific decoders.
`define csrrx(i)    (`system(i) && `funct_3(i))

	// Helpers to test if an instruction writes to/reads from a register.
`define uses_rs_2(i)    i[5]
`define uses_rd(i)      (!`branch(i) && !`store(i))
`define write_back(i)   (`uses_rd(i) && `rd(i))





	//    ██████   ██████   ███████   ████████
	//   ██       ██    ██  ██    ██  ██
	//   ██       ██    ██  ██    ██  ██████
	//   ██       ██    ██  ██    ██  ██
	//    ██████   ██████   ███████   ████████



	(* ram_block, no_rw_check *)
	bit[31:0] registers[32];

	bit[31:0] pc = RESET_PC;

	// PC value override ocurring in the EX stage.
	bit warp;
	bit[31:0] warp_target;

	// Provide a start condition for the instruction port feedback loop.
	bit kickstart = 1;

	// Make the instruction interface strobe itself forever.
	assign inst_strobe = kickstart || inst_ack || inst_retry;

	// Branch predictor which assumes only backward branches will be taken.
	wire follow_branch = `branch(inst_in) && `sign(inst_in);

	//
	// A stalled stage waits due to an external condition.
	//
	// Even if any of `fetched`/`decoded`/`executed` are asserted, if its stall
	// signal is asserted then it must not be treated as such by its successor
	// stage.
	//
	// The WB stage cannot stall so there is no signal for it.
	//

	wire stall_fetch = stall_decode && fetched;

/////////////////// UGLY BLOCK INCOMING /////////////////////////////////
	wire stall_decode =
		   stall_execute && decoded
		|| conflict_execute && cannot_forward_execute;
/////////////////////////////////////////////////////////////////////////

	wire stall_execute = await_memory && !data_ack;

	// TODO: JALI and branch are dangerous, as `inst_in` may change!
	// It might be mitigated by keeping a copy around.
	assign next_pc =
		stall_fetch ?        pc                 :
		inst_retry ?         pc                 :
		kickstart ?          pc                 :
		warp ?             warp_target          :
		`jali(inst_in) ?     pc + `j(inst_in)   :
		follow_branch ?      pc + `b(inst_in)   :
		/* else ? */         pc + 4;



	always @(posedge clock) begin
		kickstart <= 0;

		if (inst_ack)
			pc <= next_pc;

	end





	//   ███████    ██████   ████████   ██████
	//   ██    ██  ██    ██     ██     ██    ██
	//   ██    ██  ████████     ██     ████████
	//   ██    ██  ██    ██     ██     ██    ██
	//   ███████   ██    ██     ██     ██    ██



	// A memory operation is ongoing.
	bit await_memory;

	// Sub-word offset.
	wire[1:0] offset;

	assign { addr, offset } =
		store ?        uleft + `s(decode_inst)   :
		/* load ? */   uleft + `i(decode_inst);

	assign write = store;

/////////////////// UGLY BLOCK INCOMING /////////////////////////////////
	assign data_strobe =
		   data_retry
		|| (load || store) && decoded && !stall_decode && !warp;

	assign data_out =
		('b00 == decode_inst[13:12] && offset[1:0] == 0 ?   uright[7:0]           : 0) |
		('b00 == decode_inst[13:12] && offset[1:0] == 1 ?   uright[7:0]   << 8    : 0) |
		('b00 == decode_inst[13:12] && offset[1:0] == 2 ?   uright[7:0]   << 16   : 0) |
		('b00 == decode_inst[13:12] && offset[1:0] == 3 ?   uright[7:0]   << 24   : 0) |
		('b01 == decode_inst[13:12] &&  !offset[1] ?        uright[15:0]          : 0) |
		('b01 == decode_inst[13:12] &&   offset[1] ?        uright[31:16] << 16   : 0) |
		('b10 == decode_inst[13:12] ?                       uright                : 0);

	assign select =
		('b00 == decode_inst[13:12] && offset[1:0] == 0 ?   'b0001   : 0) |
		('b00 == decode_inst[13:12] && offset[1:0] == 1 ?   'b0010   : 0) |
		('b00 == decode_inst[13:12] && offset[1:0] == 2 ?   'b0100   : 0) |
		('b00 == decode_inst[13:12] && offset[1:0] == 3 ?   'b1000   : 0) |
		('b01 == decode_inst[13:12] &&  !offset[1] ?        'b0011   : 0) |
		('b01 == decode_inst[13:12] &&   offset[1] ?        'b1100   : 0) |
		('b10 == decode_inst[13:12] ?                       'b1111   : 0);

	bit access_byte, access_half, access_word;
	bit[1:0] last_offset;

	wire[7:0] data_byte =
		(last_offset == 0 ?   data_in[7:0]     : 0) |
		(last_offset == 1 ?   data_in[15:8]    : 0) |
		(last_offset == 2 ?   data_in[23:16]   : 0) |
		(last_offset == 3 ?   data_in[31:24]   : 0);

	wire[15:0] data_half =
		last_offset[1] ? data_in[31:16] : data_in[15:0];

	wire[31:0] data_in_fixed = 
		(access_byte ?   data_byte   : 0) |
		(access_half ?   data_half   : 0) |
		(access_word ?   data_in     : 0);

	always @(posedge clock) begin
		if (decoded && !stall_decode) begin
			last_offset <= offset;
			access_byte <= 'b00 == decode_inst[13:12];
			access_half <= 'b01 == decode_inst[13:12];
			access_word <= 'b10 == decode_inst[13:12];
		end

	end
/////////////////////////////////////////////////////////////////////////





	//    ██████   ███████  ███████
	//   ██       ██        ██    ██
	//   ██        ██████   ███████
	//   ██             ██  ██    ██
	//    ██████  ███████   ██    ██



	localparam
		CYCLE    = 'hC00,
		TIME     = 'hC01,
		INSTRET  = 'hC02,
		CYCLEH   = 'hC00,
		TIMEH    = 'hC01,
		INSTRETH = 'hC02;

	bit[63:0]
		cycle   = 0,
		instret = 0;

	// TODO: extract comparisons to registered signals in the ID stage?
	wire[31:0] value_csr =
		  (CYCLE    == `csr(decode_inst) ?   cycle[31:0]      : 0)
		| (TIME     == `csr(decode_inst) ?   cycle[31:0]      : 0)
		| (INSTRET  == `csr(decode_inst) ?   instret[31:0]    : 0)
		| (CYCLEH   == `csr(decode_inst) ?   cycle[63:32]     : 0)
		| (TIMEH    == `csr(decode_inst) ?   cycle[63:32]     : 0)
		| (INSTRETH == `csr(decode_inst) ?   instret[63:32]   : 0);



	always @(posedge clock)
		cycle <= cycle+1;





	//   ██    ██   ██████   ████████   ██████   ███████   ███████
	//   ██    ██  ██    ██        ██  ██    ██  ██    ██  ██    ██
	//   ████████  ████████   ██████   ████████  ███████   ██    ██
	//   ██    ██  ██    ██  ██        ██    ██  ██    ██  ██    ██
	//   ██    ██  ██    ██  ████████  ██    ██  ██    ██  ███████



	//
	// A RAW data hazard occurring *NOW* between the IF and EX stages.
	// This hazard is fully solved by forwarding.
	//

	wire conflict_decode_1 =
		   executed
		&& write_back
		&& rd == `rs_1(fetch_inst);

	wire conflict_decode_2 =
		   executed
		&& write_back
		&& rd == `rs_2(fetch_inst)
		&& `uses_rs_2(fetch_inst);

	// Debug signals to align the forwarding decisions with the ID stage result
	// in the waveform dump.
`ifdef DUMP
	bit
		forwarded_decode_1,
		forwarded_decode_2;
`endif

	//
	// A RAW data hazard occurring *NOW* between the ID and EX stages.
	// This hazard is fully solved by forwarding.
	//

	wire conflict_execute_1 =
		   executed
		&& write_back
		&& rd == `rs_1(decode_inst);

	wire conflict_execute_2 =
		   executed
		&& write_back
		&& rd == `rs_2(decode_inst)
		&& `uses_rs_2(decode_inst);

	wire conflict_execute = conflict_execute_1 || conflict_execute_2;

	// The executed operation cannot be looped back into the execute stage.
	wire cannot_forward_execute = await_memory || take_mul || take_mulh;

///////////////////////////////////////////////////////////////////////





	//   ████████  ████████  ████████   ██████  ██    ██
	//   ██        ██           ██     ██       ██    ██
	//   ██████    ██████       ██     ██       ████████
	//   ██        ██           ██     ██       ██    ██
	//   ██        ████████     ██      ██████  ██    ██



	bit fetched = 0;

	bit[31:0]
		fetch_inst,
		fetch_pc;

	bit fetch_branched;



	always @(posedge clock) begin

		if (warp) begin
			fetched <= 0;

		end else if (stall_fetch) begin
			// Do nothing...

		end else if (inst_ack) begin
			fetch_inst <= inst_in;
			fetch_pc <= pc;
			fetch_branched <= follow_branch;

			fetched <= 1;

		end else
			fetched <= 0;

	end





	//   ███████   ████████   ██████   ██████   ███████   ████████
	//   ██    ██  ██        ██       ██    ██  ██    ██  ██      
	//   ██    ██  ██████    ██       ██    ██  ██    ██  ██████  
	//   ██    ██  ██        ██       ██    ██  ██    ██  ██      
	//   ███████   ████████   ██████   ██████   ███████   ████████



	bit decoded = 0;

	bit[31:0]
		decode_inst,
		decode_pc;

	bit decode_branched;

	bit[31:0]
		value_1,
		value_2,
		decode_result;

	bit
		jalr,
		branch, bltge,
		load, store,
		add, sub, slt, bxor, bor, band, sl, sr,
		mul, mulh, mulhs, mulhsu,
		csrrx;

	bit will_write_back;

	bit
		signed_1,
		signed_2;

/////////////////// UGLY BLOCK INCOMING /////////////////////////////////
	wire[31:0]
		uleft  = conflict_execute_1 && !cannot_forward_execute ? execute_result : value_1,
		uright = conflict_execute_2 && !cannot_forward_execute ? execute_result : value_2;
/////////////////////////////////////////////////////////////////////////

	wire signed[32:0]
		sleft  = $signed({ signed_1 && uleft[31],  uleft  }),
		sright = $signed({ signed_2 && uright[31], uright });


	always @(posedge clock)

		if (warp) begin
			decoded <= 0;

		end else if (stall_decode) begin
			if (conflict_execute_1)
				value_1 <= final_value;

			if (conflict_execute_2)
				value_2 <= final_value;

		end else if (fetched && !stall_fetch) begin
			decode_inst <= fetch_inst;
			decode_pc <= fetch_pc;

			decode_branched <= fetch_branched;

`ifdef DUMP
			forwarded_decode_1 <= conflict_decode_1;
			forwarded_decode_2 <= conflict_decode_2;
`endif

			value_1 <=
				conflict_decode_1 ?         final_value      :
				/* else ? */                registers[`rs_1(fetch_inst)];

			value_2 <=
				!`uses_rs_2(fetch_inst) ?   `i(fetch_inst)   :
				conflict_decode_2 ?         final_value      :
				/* else ? */                registers[`rs_2(fetch_inst)];

			// Precompute results for some opcodes before the execute stage.
			decode_result <=
				  (`lui(fetch_inst) ?            0 + `u(fetch_inst)   : 0)
				| (`auipc(fetch_inst) ?   fetch_pc + `u(fetch_inst)   : 0)
				| (`jali(fetch_inst) ?    fetch_pc + 4                : 0)
				| (`jalr(fetch_inst) ?    fetch_pc + 4                : 0);

			jalr   <= `jalr(fetch_inst);
			load   <= `load(fetch_inst);
			store  <= `store(fetch_inst);
			branch <= `branch(fetch_inst);
			bltge  <= `bltge(fetch_inst);
			add    <= `add(fetch_inst);
			sub    <= `sub(fetch_inst);
			sl     <= `sl(fetch_inst);
			slt    <= `slt(fetch_inst);
			bxor   <= `bxor(fetch_inst);
			sr     <= `sr(fetch_inst);
			bor    <= `bor(fetch_inst);
			band   <= `band(fetch_inst);
			mul    <= `mul(fetch_inst);
			mulh   <= `mulh(fetch_inst);
			mulhs  <= `mulhs(fetch_inst);
			mulhsu <= `mulhsu(fetch_inst);
			csrrx  <= `csrrx(fetch_inst);

			will_write_back <= `write_back(fetch_inst);

			signed_1 <=
				   `bltge(fetch_inst) && !fetch_inst[13]   // blt/bge.
				|| `slt(fetch_inst) && !fetch_inst[12]     // slt.
				|| `sr(fetch_inst) && fetch_inst[30]       // sra.
				|| `mulhs(fetch_inst)                      // mulh.
				|| `mulhsu(fetch_inst);                    // mulhsu.

			signed_2 <=
				   `bltge(fetch_inst) && !fetch_inst[13]   // blt/bge.
				|| `slt(fetch_inst) && !fetch_inst[12]     // slt.
				|| `mulhs(fetch_inst);                     // mulh.

			decoded <= 1;

		end else
			decoded <= 0;





	//   ████████  ██    ██  ████████   ██████  ██    ██  ████████  ████████
	//   ██        ██    ██  ██        ██       ██    ██     ██     ██
	//   ██████     ██████   ██████    ██       ██    ██     ██     ██████
	//   ██        ██    ██  ██        ██       ██    ██     ██     ██
	//   ████████  ██    ██  ████████   ██████   ██████      ██     ████████



	bit executed = 0;

`ifdef DUMP
	bit[31:0]
		execute_inst,
		execute_pc;
`endif

	bit[31:0]
		term_1,
		term_4;

	bit[32:0]
		term_2,
		term_3;

	bit
		take_mul,
		take_mulh;

	bit[31:0] execute_result;
	bit[4:0] rd;
	bit write_back;

/////////////////// UGLY BLOCK INCOMING /////////////////////////////////
	// TODO: explain how values are merged together?
	wire[63:0] product;
	
	assign
		product[63:16] = $signed({ term_4, term_1[31:16] }) + (term_2 + term_3),
		product[15:0]  =                   term_1[15:0];
/////////////////////////////////////////////////////////////////////////

	// Value to be written back, according to the kind of instruction executed.
	wire[31:0] final_value =
		  execute_result
/////////////////// UGLY BLOCK INCOMING /////////////////////////////////
		| (await_memory ?   data_in_fixed    : 0)
/////////////////////////////////////////////////////////////////////////
		| (take_mul ?       product[31:0]    : 0)
		| (take_mulh ?      product[63:32]   : 0);

	wire branch_result =
		bltge ?         sleft <  sright   :
		/* beqne ? */   uleft == uright;

	// Bit 12 determines if the comparison result must be reversed.
	wire branch_mistaken = decode_inst[12] ^ branch_result != decode_branched;



	always @(posedge clock)

		if (warp) begin
			warp <= !inst_ack;
			executed <= 0;

		end else if (stall_execute) begin
			// Do nothing...

		end else if (decoded && !stall_decode) begin
`ifdef DUMP
			execute_inst <= decode_inst;
			execute_pc <= decode_pc;
`endif

		// SystemVerilog makes things too verbose...
`define lo(val)   $signed({ 1'b0, val[15:0] })
`define hi(val)   $signed(        val[32:16] )
		term_1 <= `lo(uleft) * `lo(uright);
		term_2 <= `lo(uleft) * `hi(sright);
		term_3 <= `hi(sleft) * `lo(uright);
		term_4 <= `hi(sleft) * `hi(sright);
`undef lo
`undef hi

			take_mul <= mul;
			take_mulh <= mulh;

			execute_result <=
				   decode_result
				| (add ?      uleft  +  uright        : 0)
				| (sub ?      sleft  -  sright        : 0)
				| (slt ?     (sleft  -  sright) < 0   : 0)
				| (bxor ?     uleft  ^  uright        : 0)
				| (bor ?      uleft  |  uright        : 0)
				| (band ?     uleft  &  uright        : 0)
				| (sl ?       uleft <<  uright[4:0]   : 0)
				| (sr ?       sleft >>> uright[4:0]   : 0)
				| (csrrx ?       value_csr            : 0);

			rd <= `rd(decode_inst);
			write_back <= will_write_back;

			warp_target <=
				jalr ?                  uleft + `i(decode_inst)   :
				decode_branched ?   decode_pc + 4                 :
				/* else ? */        decode_pc + `b(decode_inst);

			warp <= jalr || branch && branch_mistaken;
			await_memory <= load || store;
			executed <= 1;

		end else begin
			await_memory <= 0;
			executed <= 0;

		end




	//    ███████   ██████   ██    ██  ████████
	//   ██        ██    ██  ██    ██  ██
	//    ██████   ████████  ██    ██  ██████
	//         ██  ██    ██   ██  ██   ██
	//   ███████   ██    ██     ██     ████████



`ifdef DUMP
	bit saved = 0;

	bit[31:0]
		save_inst,
		save_pc;
`endif



	always @(posedge clock)

		if (executed && !stall_execute) begin
			if (write_back)
				registers[rd] <= final_value;

			instret <= instret+1;

`ifdef DUMP
			save_inst <= execute_inst;
			save_pc <= execute_pc;

			saved = 1;

		end else begin
			saved <= 0;

`endif
		end





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

`undef i
`undef s
`undef b
`undef u
`undef j
`undef op
`undef rd
`undef funct_3
`undef rs_1
`undef rs_2
`undef funct_12
`undef funct_7
`undef sign

`undef lui
`undef auipc
`undef jali
`undef jalr
`undef branch
`undef load
`undef store
`undef alui
`undef alur
`undef alu
`undef system

`undef alurs
`undef alurm
`undef alus

`undef beqne
`undef bltge

`undef add
`undef sub
`undef sl
`undef slt
`undef bxor
`undef sr
`undef bor
`undef band
`undef mul
`undef mulh
`undef mulhs
`undef mulhsu
`undef mulhu
`undef csrrx

`undef uses_rs_1
`undef uses_rs_2
`undef uses_rd
`undef write_back

endmodule

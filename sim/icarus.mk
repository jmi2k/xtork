build/%.vcd: build/test/%.vvp
	vvp "$<"

build/test/%.vvp: test/%.sv
	@mkdir -p `dirname "$@"`
	iverilog \
		-g 2012 \
		-I rtl \
		-D 'DUMP="build/$*.vcd"' \
		-D 'FCLK=${FCLK}' \
		-D 'BAUDS=${BAUDS}' \
		-o "$@" \
		"$<"

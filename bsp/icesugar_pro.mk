FCLK    = 25000000
SIZE    = 25k
SPEED   = 6
PACKAGE = CABGA256

flash: build/${TOP}.bit
	cp "$<" /media/*/iCELink/.
	# icesprog "$<"

build/%.bit: build/rtl/%.config
	ecppack --compress --input "$<" --bit "$@"

build/rtl/%.config: build/rtl/%.json
	nextpnr-ecp5 \
		--${SIZE} \
		--json "$<" \
		--lpf-allow-unconstrained \
		--lpf "bsp/${BOARD}.lpf" \
		--package ${PACKAGE} \
		--randomize-seed \
		--speed ${SPEED} \
		--textcfg "$@" \
		--timing-allow-fail

build/rtl/%.json: rtl/%.sv
	@mkdir -p `dirname "$@"`
	yosys \
		-q \
		-D 'BAUDS=${BAUDS}' \
		-D 'ECP5' \
		-D 'FCLK=${FCLK}' \
		-p 'read -incdir rtl' \
		-p 'synth_ecp5 -abc2' \
		-p 'write_json "$@"' \
		"$<"

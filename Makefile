.PHONY: bit clean default elf flash hex serial

default:
	@echo 'usage: make bit|clean|elf|flash|hex|serial' >&2

SIM   = icarus
BOARD = icesugar_pro
TOP   = SoC
TEST  = dummy_soc
ISA   = rv32im   # rv32im_Zicntr_Zicsr
TTY   = /dev/ttyACM0
BAUDS = 921600
VIDEO = /dev/video0

rtl/SoC.sv: \
	build/res/dingus_nowhiskers.666.hex \
	build/firmware.hex \
	rtl/BRAM.sv \
	rtl/RISCV.sv \
	rtl/UART.sv \
	rtl/Video.sv \
	rtl/types.svh \

test/dummy_soc.sv: \
	rtl/SoC.sv \

clean:
	-rm -r build

serial: 
	picocom -q -b ${BAUDS} "${TTY}"

vga:
	v4l2-ctl -d "${VIDEO}" --set-fmt-video=width=640,height=480,pixelformat=YUYV
	ffplay "${VIDEO}"

bit: build/${TOP}.bit
elf: build/${EXE}.elf
hex: build/${EXE}.hex
wave: build/${TEST}.vcd

include sim/${SIM}.mk
include bsp/${BOARD}.mk
include src/firmware.mk

build/res/%.666.hex: res/%.png
	@mkdir -p `dirname "$@"`
	python3 util/encode_image.py -e RGB666 -n res/blue_noise.png "$<" \
	| od -v -A n -t x4 | sed 's/ 000/ /g' > "$@"

build/res/%.h: res/%.obj
	@mkdir -p `dirname "$@"`
	python3 util/encode_obj.py "$<" > "$@"

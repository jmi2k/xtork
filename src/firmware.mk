LDSCRIPT = src/linker.ld
CFLAGS   = -O3 -std=c11 -Wall -Wextra -pedantic

build/firmware.elf: \
	build/src/boot.o \
	build/src/command.o \
	build/src/graphics.o \
	build/src/main.o \
	build/src/u.o \

build/src/*.o: ${LDSCRIPT}

build/%.hex: build/%.elf
	riscv64-unknown-elf-objcopy -O binary "$<" /dev/stdout \
	| od -v -A n -t x4 > "$@"

build/%.elf:
	riscv64-unknown-elf-ld \
		-flto \
		-nostdlib \
		-b elf32-littleriscv \
		-m elf32lriscv --no-relax \
		-o "$@" \
		-T "${LDSCRIPT}" \
		$^

build/src/%.o: src/%.[cS]
	@mkdir -p `dirname "$@"`
	riscv64-unknown-elf-gcc \
		-c \
		-DBAUDS=${BAUDS} \
		-fno-builtin \
		-static-libgcc \
		-mabi=ilp32 \
		-march=${ISA} \
		-o "$@" \
		${CFLAGS} \
		"$<"

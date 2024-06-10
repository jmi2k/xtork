#include "u.h"
#include "command.h"
#include "graphics.h"

void
cmd_csr_cycle(void)
{
	print(ICELINK, "0x%x\r\n", read_cycle());
}

void
cmd_csr_time(void)
{
	print(ICELINK, "0x%x\r\n", read_time());
}

void
cmd_csr_instret(void)
{
	print(ICELINK, "0x%x\r\n", read_instret());
}

// void
// cmd_sdram_read(void)
// {
// 	SDRAM[0U];
// 	print(ICELINK, "@0x%x : 0x%x\r\n", 0U, SDRAM[0U]);
// }

// void
// cmd_sdram_write(void)
// {
// 	SDRAM[0U] = 0xCAFEU;
// }

// void
// cmd_sdram_clear(void)
// {
// 	for (unsigned addr = 0U; addr < 0x400000U; addr++)
// 		SDRAM[addr] = 0U;
// }

// void
// cmd_sdram_fill(void)
// {
// 	unsigned state = 0xDEADBEEFU;

// 	for (unsigned addr = 0U; addr < 0x400000U; addr++)
// 		SDRAM[addr] = state = next_xorshift(state);
// }

// void
// cmd_sdram_check(void)
// {
// 	unsigned state = 0xDEADBEEFU;
// 	unsigned failed = 0U;

// 	for (unsigned addr = 0U; addr < 0x400000U; addr++) {
// 		const unsigned read_value = SDRAM[addr];
// 		state = next_xorshift(state);

// 		if (read_value != (unsigned short)state) {
// 			print(
// 				ICELINK,
// 				"Mismatch @0x%x (expected 0x%x, got 0x%x)\r\n",
// 				addr,
// 				(unsigned short)state,
// 				read_value);

// 			failed++;
// 		}
// 	}
// }

void
cmd_video_clear(void)
{
	clear_screen(0U);
}

static char atlas[] = {
#include "../build/atlas.h"
};

void
cmd_video_tri(void)
{

	Vec2 xy, uv;
	unsigned random, color;

	random = xorshift();
	color = random & 0xFFFFFF;
	random = xorshift();
	xy.x = (random & 0xFFU) % 160U;
	random >>= 8U;
	xy.y = (random & 0xFFU) % 120U;
	uv = (Vec2) { 0, 0 };
	Vert2 a = { xy, uv, color };

	random = xorshift();
	color = random & 0xFFFFFF;
	random = xorshift();
	xy.x = (random & 0xFFU) % 160U;
	random >>= 8U;
	xy.y = (random & 0xFFU) % 120U;
	uv = (Vec2) { 0, 16 };
	Vert2 b = { xy, uv, color };

	random = xorshift();
	color = random & 0xFFFFFF;
	random = xorshift();
	xy.x = (random & 0xFFU) % 160U;
	random >>= 8U;
	xy.y = (random & 0xFFU) % 120U;
	uv = (Vec2) { 16, 0 };
	Vert2 c = { xy, uv, color };

	char *tex = random & 0x800000 ? atlas : NULL;

	draw_triangle((Tri2) { tex, a, b, c });
}

void
cmd_video_tris(void)
{
	for (int idx = 0; idx < 1000; idx++)
		cmd_video_tri();
}

void
cmd_video_hello(void)
{
	draw_triangle((Tri2) { NULL,  {{ 32,  12}, {}, 0x0000FF}, {{ 32, 108}, {}, 0x00FF00}, {{128,  12}, {}, 0xFF0000} });
	draw_triangle((Tri2) { atlas, {{128, 108}, { 0, 16}},     {{128,  12}, {16,  0}},     {{ 32, 108}, {16, 16}} });
}

void
cmd_wait_10s(void)
{
	spin_cycles(10 * 62000000);
}

void
cmd_plot(void)
{
	const int w = 480;
	const int h = 480;

	put_string(ICELINK, "\x1BPq");

	for (int row = -h/6/2; row < h/6/2; row++) {
		for (int x = -w/2; x < w/2; x++) {
			int y = 6*row;
			char sixel = '?';

			for (int dy = 0; dy < 6; dy++, y++) {
				unsigned lit = 0
				    || x == 0
				    || y == 0
				    || x*x >> 8 == -y;

				sixel += lit << dy;
			}

			put_char(ICELINK, sixel);
		}

		put_string(ICELINK, "$-");
	}

	put_string(ICELINK, "\x1B\\");
}

void
cmd_random(void)
{
	print(ICELINK, "0x%x\r\n", xorshift());
}

static const struct {
	const char *name;
	Command *proc;
} COMMANDS[] = {
	{ "csr/cycle",     cmd_csr_cycle },
	{ "csr/time",      cmd_csr_time },
	{ "csr/instret",   cmd_csr_instret },
	// { "sdram/read",    cmd_sdram_read },
	// { "sdram/write",   cmd_sdram_write },
	// { "sdram/clear",   cmd_sdram_clear },
	// { "sdram/fill",    cmd_sdram_fill },
	// { "sdram/check",   cmd_sdram_check },
	{ "video/clear",   cmd_video_clear },
	{ "video/tri",     cmd_video_tri },
	{ "video/tris",    cmd_video_tris },
	{ "video/hello",   cmd_video_hello },
	{ "wait/10s",      cmd_wait_10s },
	{ "plot",          cmd_plot },
	{ "random",        cmd_random },
};

Command *
lookup_command(const char *const line)
{
    for (int pos = 0; pos < (int)NELEMS(COMMANDS); pos++)
        if (compare_strings(line, COMMANDS[pos].name) == 0)
            return COMMANDS[pos].proc;

    return NULL;
}

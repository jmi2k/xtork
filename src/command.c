#include "u.h"
#include "command.h"
#include "graphics.h"

void
cmd_wait_1s(void)
{
	spin_cycles(103333333);
}

void
cmd_wait_10s(void)
{
	spin_cycles(10 * 103333333);
}

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

void
cmd_video_clear(void)
{
	fill_screen(0U);
}

void
cmd_video_fill(void)
{
	fill_screen(xorshift());
}

void
cmd_video_hello(void)
{
	// raster_triangle((Triangle) {
	// 	{ { FIX(160), FIX(100), 0 }, { 0x1F0000, 0 } },
	// 	{ { FIX(  0), FIX(100), 0 }, { 0x001F00, 0 } },
	// 	{ { FIX(160), FIX(  0), 0 }, { 0x00001F, 0 } },
	// });
	// raster_triangle((Triangle) {
	// 	{ { FIX(  0), FIX(  0), 0 }, { 0x1F0000, 0 } },
	// 	{ { FIX(160), FIX(  0), 0 }, { 0x001F00, 0 } },
	// 	{ { FIX(  0), FIX(100), 0 }, { 0x00001F, 0 } },
	// });

	// raster_triangle((Triangle) {
	// 	{ { FIX(10),      FIX(10),      0 }, { 0x1F0000, 0 } },
	// 	{ { FIX(10),      FIX(10 + 30), 0 }, { 0x00001F, 0 } },
	// 	{ { FIX(10 + 30), FIX(10),      0 }, { 0x001F00, 0 } },
	// });
	// raster_triangle((Triangle) {
	// 	{ { FIX(20),     FIX(12),     0 }, { 0x001F00, 0 } },
	// 	{ { FIX(20),     FIX(12 + 5), 0 }, { 0x1F0000, 0 } },
	// 	{ { FIX(20 + 5), FIX(12),     0 }, { 0x00001F, 0 } },
	// });
	// raster_triangle((Triangle) {
	// 	{ { FIX(30),     FIX(22),     0 }, { 0x00001F, 0 } },
	// 	{ { FIX(30),     FIX(22 - 5), 0 }, { 0x001F00, 0 } },
	// 	{ { FIX(30 - 5), FIX(22),     0 }, { 0x1F0000, 0 } },
	// });

	// raster_triangle((Triangle) {
	// 	{ { FIX( 80), FIX( 25), 0 }, { 0x1F0000, 0 } },
	// 	{ { FIX( 80), FIX( 75), 0 }, { 0x001F00, 0 } },
	// 	{ { FIX( 30), FIX( 25), 0 }, { 0x00001F, 0 } },
	// });
	// raster_triangle((Triangle) {
	// 	{ { FIX( 80), FIX( 25), 0 }, { 0x1F0000, 0 } },
	// 	{ { FIX(130), FIX( 25), 0 }, { 0x001F00, 0 } },
	// 	{ { FIX( 80), FIX( 75), 0 }, { 0x00001F, 0 } },
	// });

	// raster_triangle((Triangle) {
	// 	{ { FIX( 48), FIX( 18), FIX(10) }, { FIX(  0), FIX(  0) } },
	// 	{ { FIX(112), FIX( 18), FIX(19) }, { FIX(128), FIX(  0) } },
	// 	{ { FIX( 48), FIX( 82), FIX(10) }, { FIX(  0), FIX(128) } },
	// });
	// raster_triangle((Triangle) {
	// 	{ { FIX(112), FIX( 82), 0 },  { FIX(128), FIX(128) } },
	// 	{ { FIX( 48), FIX( 82), 0 },  { FIX(  0), FIX(128) } },
	// 	{ { FIX(112), FIX( 18), 0 },  { FIX(128), FIX(  0) } },
	// });

	raster_triangle((Triangle) {
		{ { FIX( -1), FIX( -1), FIX(2) }, { FIX(  0), FIX(  0) } },
		{ { FIX(  1), FIX( -1), FIX(4) }, { FIX(128), FIX(  0) } },
		{ { FIX( -1), FIX(  1), FIX(2) }, { FIX(  0), FIX(128) } },
	});
	raster_triangle((Triangle) {
		{ { FIX(  1), FIX(  1), FIX(4) }, { FIX(128), FIX(128) } },
		{ { FIX( -1), FIX(  1), FIX(2) }, { FIX(  0), FIX(128) } },
		{ { FIX(  1), FIX( -1), FIX(4) }, { FIX(128), FIX(  0) } },
	});
}

static const Triangle model[] = {
	{
		{ { FIX(-50), FIX( 10), FIX(10) }, { FIX(  0), FIX(  0) } },
		{ { FIX(-30), FIX( 10), FIX(10) }, { FIX(128), FIX(  0) } },
		{ { FIX(-50), FIX(-10), FIX(10) }, { FIX(  0), FIX(128) } },
	},
	{
		{ { FIX(-30), FIX(-10), FIX(10) }, { FIX(128), FIX(128) } },
		{ { FIX(-50), FIX(-10), FIX(10) }, { FIX(  0), FIX(128) } },
		{ { FIX(-30), FIX( 10), FIX(10) }, { FIX(128), FIX(  0) } },
	},
	{
		{ { FIX(-30), FIX( 10), FIX(10) }, { FIX(  0), FIX(  0) } },
		{ { FIX(-30), FIX( 10), FIX(30) }, { FIX(128), FIX(  0) } },
		{ { FIX(-30), FIX(-10), FIX(10) }, { FIX(  0), FIX(128) } },
	},
	{
		{ { FIX(-30), FIX(-10), FIX(30) }, { FIX(128), FIX(128) } },
		{ { FIX(-30), FIX(-10), FIX(10) }, { FIX(  0), FIX(128) } },
		{ { FIX(-30), FIX( 10), FIX(30) }, { FIX(128), FIX(  0) } },
	},
};

void
cmd_video_demo(void)
{
	Vec3 pov = { FIX(0), FIX(0), FIX(0) };
	uvlong then = read_time();
	char aim = '\0';
	int i = 0;

	for (;;) {
		const uvlong now = read_time();
		const int dt = now - then;

		if (ICELINK->full)
			aim = ICELINK->data;

		if (!OUIJA->v_blank)
			continue;

		then = now;
		// fill_screen(0U);

#define FACTOR   200

		fix dx = 0;
		fix dy = 0;
		fix dz = 0;

		switch (aim) {
		case 'w':
			dz += dt / FACTOR;
			break;

		case 'a':
			dx -= dt / FACTOR;
			break;

		case 's':
			dz -= dt / FACTOR;
			break;

		case 'd':
			dx += dt / FACTOR;
			break;
		}

		pov.x += dx;
		pov.y += dy;
		pov.z += dz;

		if (i++ == 100) {
			print(ICELINK, "%q %q %q %x %x %x %x\r\n", pov.x, pov.y, pov.z, dt, dx, dy, dz);
			i = 0;
		}

		render_model(model, NELEMS(model), pov);
	}
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
	{ "wait/1s",     cmd_wait_1s },
	{ "wait/10s",    cmd_wait_10s },
	{ "csr/cycle",   cmd_csr_cycle },
	{ "csr/time",    cmd_csr_time },
	{ "csr/instret", cmd_csr_instret },
	{ "video/clear", cmd_video_clear },
	{ "video/fill",  cmd_video_fill },
	{ "video/hello", cmd_video_hello },
	{ "video/demo",  cmd_video_demo },
	{ "plot",        cmd_plot },
	{ "random",      cmd_random },
};

Command *
lookup_command(const char *const line)
{
    for (int pos = 0; pos < (int)NELEMS(COMMANDS); pos++)
        if (compare_strings(line, COMMANDS[pos].name) == 0)
            return COMMANDS[pos].proc;

    return NULL;
}

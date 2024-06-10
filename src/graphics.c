#include "u.h"
#include "graphics.h"

static int
is_top_left(Vec2 start, Vec2 end) {
	Vec2 edge = { end.x - start.x, end.y - start.y };
	int is_top_edge = edge.y == 0 && edge.x > 0;
	int is_left_edge = edge.y < 0;

	return is_left_edge || is_top_edge;
}

static int
edge_cross(Vec2 a, Vec2 b, Vec2 p) {
	Vec2 ab = { b.x - a.x, b.y - a.y };
	Vec2 ap = { p.x - a.x, p.y - a.y };

	return ab.x * ap.y - ab.y * ap.x;
}

void
clear_screen(const unsigned short color)
{
	for (int y = 0U; y < 120; y++)
	for (int x = 0U; x < 160; x++)
		draw_pixel((Vec2) { x, y }, color);
}

void
draw_pixel(const Vec2 p, const unsigned short color)
{
	VIDEO[160U*p.y + p.x] = color;
}

// Padded and shifted table made from:
//
// def srgb2linear(v):
//     if v > 0.0031308:
//         return 1.055 * (pow(v, 1. / 2.4)) - 0.05499999999999999
//     else:
//         return 12.92 * v
//
// table = [int(0xFF * srgb2linear(n / 0xFF)) for n in range(0x100)]
//
// for y in range(32):
//     line = ", ".join(["0x{:02X}".format(n) for n in table[8*y:8*y+8]])
//     print(f"\t{line}")

static const char srgb2linear[288] = {
	// 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
	0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,

	0x0, 0x0, 0x1, 0x1, 0x2, 0x2, 0x2, 0x2,
	0x3, 0x3, 0x3, 0x3, 0x3, 0x3, 0x4, 0x4,
	0x4, 0x4, 0x4, 0x4, 0x4, 0x5, 0x5, 0x5,
	0x5, 0x5, 0x5, 0x5, 0x5, 0x5, 0x6, 0x6,
	0x6, 0x6, 0x6, 0x6, 0x6, 0x6, 0x6, 0x6,
	0x6, 0x6, 0x7, 0x7, 0x7, 0x7, 0x7, 0x7,
	0x7, 0x7, 0x7, 0x7, 0x7, 0x7, 0x7, 0x7,
	0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8,
	0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8,
	0x9, 0x9, 0x9, 0x9, 0x9, 0x9, 0x9, 0x9,
	0x9, 0x9, 0x9, 0x9, 0x9, 0x9, 0x9, 0x9,
	0x9, 0x9, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
	0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA,
	0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xA, 0xB,
	0xB, 0xB, 0xB, 0xB, 0xB, 0xB, 0xB, 0xB,
	0xB, 0xB, 0xB, 0xB, 0xB, 0xB, 0xB, 0xB,
	0xB, 0xB, 0xB, 0xB, 0xB, 0xB, 0xB, 0xC,
	0xC, 0xC, 0xC, 0xC, 0xC, 0xC, 0xC, 0xC,
	0xC, 0xC, 0xC, 0xC, 0xC, 0xC, 0xC, 0xC,
	0xC, 0xC, 0xC, 0xC, 0xC, 0xC, 0xC, 0xC,
	0xC, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD,
	0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD,
	0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD,
	0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xD, 0xE,
	0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE,
	0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE,
	0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE,
	0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xE, 0xF,
	0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF,
	0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF,
	0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF,
	0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF,

	0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF,
	// 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF,
};

void
draw_triangle(const Tri2 tri)
{
	const Vec2 b = tri.b.xy;
	Vec2 a, c;

	if ((tri.b.xy.x - tri.a.xy.x)*(tri.c.xy.y - tri.a.xy.y) - (tri.c.xy.x - tri.a.xy.x)*(tri.b.xy.y - tri.a.xy.y) > 0) {
		a = tri.a.xy;
		c = tri.c.xy;
	} else {
		a = tri.c.xy;
		c = tri.a.xy;
	}

	unsigned ar =  tri.a.color         & 0xFF;
	unsigned ag = (tri.a.color >>  8U) & 0xFF;
	unsigned ab = (tri.a.color >> 16U) & 0xFF;

	unsigned br =  tri.b.color         & 0xFF;
	unsigned bg = (tri.b.color >>  8U) & 0xFF;
	unsigned bb = (tri.b.color >> 16U) & 0xFF;

	unsigned cr =  tri.c.color         & 0xFF;
	unsigned cg = (tri.c.color >>  8U) & 0xFF;
	unsigned cb = (tri.c.color >> 16U) & 0xFF;

	unsigned au = tri.a.uv.x;
	unsigned av = tri.a.uv.y;

	unsigned bu = tri.b.uv.x;
	unsigned bv = tri.b.uv.y;

	unsigned cu = tri.c.uv.x;
	unsigned cv = tri.c.uv.y;

	// Finds the bounding box with all candidate pixels
	int x_min = MIN(MIN(a.x, b.x), c.x);
	int y_min = MIN(MIN(a.y, b.y), c.y);
	int x_max = MAX(MAX(a.x, b.x), c.x);
	int y_max = MAX(MAX(a.y, b.y), c.y);

	// Compute the constant delta_s that will be used for the horizontal and vertical steps
	int delta_w0_col = (b.y - c.y);
	int delta_w1_col = (c.y - a.y);
	int delta_w2_col = (a.y - b.y);
	int delta_w0_row = (c.x - b.x);
	int delta_w1_row = (a.x - c.x);
	int delta_w2_row = (b.x - a.x);

	// Rasterization fill convention (top-left rule)
	int bias0 = is_top_left(b, c) ? 0 : -1;
	int bias1 = is_top_left(c, a) ? 0 : -1;
	int bias2 = is_top_left(a, b) ? 0 : -1;

	// Compute the edge functions for the fist (top-left) point
	Vec2 p0 = { x_min, y_min };
	int w0_row = edge_cross(b, c, p0) + bias0;
	int w1_row = edge_cross(c, a, p0) + bias1;
	int w2_row = edge_cross(a, b, p0) + bias2;

	int area = edge_cross(a, b, c);
	unsigned long long area_recip = 0xFFFFFFFFU / (unsigned)area + 1;

	// Loop all candidate pixels inside the bounding box
	for (int y = y_min; y <= y_max; y++) {
		int w0 = w0_row;
		int w1 = w1_row;
		int w2 = w2_row;

		int last_was_inside = 0;

		for (int x = x_min; x <= x_max; x++) {
			int is_inside = (w0 | w1 | w2) >= 0;

			if (is_inside) {
				Vec2 p = { x, y };

				// Dithering
				int random = xorshift();
				int noise =  random & 0xF;

				// TODO: 256 or 255?
				int alpha = (unsigned long long)(256*w0)*area_recip >> 32U;
				int beta  = (unsigned long long)(256*w1)*area_recip >> 32U;
				int gamma = (unsigned long long)(256*w2)*area_recip >> 32U;

				unsigned r, g, b;

				if (!tri.tex) {
					r = srgb2linear[((ar*alpha + br*beta + cr*gamma) >> 8U) + noise];
					g = srgb2linear[((ag*alpha + bg*beta + cg*gamma) >> 8U) + noise];
					b = srgb2linear[((ab*alpha + bb*beta + cb*gamma) >> 8U) + noise];
				} else {
					int u = (au*alpha + bu*beta + cu*gamma) >> 8U;
					int v = (av*alpha + bv*beta + cv*gamma) >> 8U;

					int pos = 3*(32*u + v);
					int sr = tri.tex[pos];
					int sg = tri.tex[pos + 1];
					int sb = tri.tex[pos + 2];

					r = srgb2linear[sr + noise];
					g = srgb2linear[sg + noise];
					b = srgb2linear[sb + noise];
				}

				unsigned color = (r << 8) | (g << 4) | b;

				draw_pixel(p, color);
			} else if (last_was_inside) {
				int x_remaining = x_max - x;
				w0 += delta_w0_col * x_remaining;
				w1 += delta_w1_col * x_remaining;
				w2 += delta_w2_col * x_remaining;
				break;
			}

			last_was_inside = is_inside;
			w0 += delta_w0_col;
			w1 += delta_w1_col;
			w2 += delta_w2_col;
		}

		w0_row += delta_w0_row;
		w1_row += delta_w1_row;
		w2_row += delta_w2_row;
	}
}

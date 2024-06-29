#include "u.h"
#include "graphics.h"

inline fix
fix_mul(const fix l, const fix r)
{
	vlong product = (vlong)l * (int)r;
	return (product + 0x8000) >> 16;
}

void
fill_screen(const Color color)
{
	for (int pos = 0; pos < 320*200; pos += 8) {
		FRAME[pos + 0] = color;
		FRAME[pos + 1] = color;
		FRAME[pos + 2] = color;
		FRAME[pos + 3] = color;
		FRAME[pos + 4] = color;
		FRAME[pos + 5] = color;
		FRAME[pos + 6] = color;
		FRAME[pos + 7] = color;
	}
}

inline int
is_top_left(Vec2 start, Vec2 end) {
	Vec2 edge = { end.x - start.x, end.y - start.y };
	int is_top_edge = edge.y == 0 && edge.x > 0;
	int is_left_edge = edge.y < 0;

	return is_left_edge || is_top_edge;
}

inline int
edge_cross(Vec2 a, Vec2 b, Vec2 p) {
	Vec2 ab = { b.x - a.x, b.y - a.y };
	Vec2 ap = { p.x - a.x, p.y - a.y };

	return fix_mul(ab.x, ap.y) - fix_mul(ab.y, ap.x);
}

void
render_model(const Triangle model[], const int len, const Vec3 pov)
{
	for (int pos = 0; pos < len; pos++) {
		Triangle tri = model[pos];
		// Tri2 tri_2;

		// fix a_x = tri_3.a.xyz.x - pov.x;
		// fix a_y = tri_3.a.xyz.y - pov.y;
		// fix a_z = tri_3.a.xyz.z - pov.z;

		// fix b_x = tri_3.b.xyz.x - pov.x;
		// fix b_y = tri_3.b.xyz.y - pov.y;
		// fix b_z = tri_3.b.xyz.z - pov.z;

		// fix c_x = tri_3.c.xyz.x - pov.x;
		// fix c_y = tri_3.c.xyz.y - pov.y;
		// fix c_z = tri_3.c.xyz.z - pov.z;

		// fix a_z_inv = 0xFFFFFFFFU / (unsigned)a_z + 1;
		// fix b_z_inv = 0xFFFFFFFFU / (unsigned)b_z + 1;
		// fix c_z_inv = 0xFFFFFFFFU / (unsigned)c_z + 1;

		// fix fov = 0x100;

		// tri_2.a.xy.x = FIX(160) + fix_mul(fix_mul(fov, a_x), a_z_inv);
		// tri_2.a.xy.y = FIX(100) - fix_mul(fix_mul(fov, a_y), a_z_inv);

		// tri_2.b.xy.x = FIX(160) + fix_mul(fix_mul(fov, b_x), b_z_inv);
		// tri_2.b.xy.y = FIX(100) - fix_mul(fix_mul(fov, b_y), b_z_inv);

		// tri_2.c.xy.x = FIX(160) + fix_mul(fix_mul(fov, c_x), c_z_inv);
		// tri_2.c.xy.y = FIX(100) - fix_mul(fix_mul(fov, c_y), c_z_inv);
		OUIJA->matrix.i = (Vec4) { FIX(100.0), FIX(  0.0), FIX(  0.0),   -pov.x };
		OUIJA->matrix.j = (Vec4) { FIX(  0.0), FIX(100.0), FIX(  0.0),   -pov.y };
		OUIJA->matrix.k = (Vec4) { FIX(  0.0), FIX(  0.0), FIX(  0.0),   -pov.z };
		OUIJA->matrix.l = (Vec4) { FIX(  0.0), FIX(  0.0), FIX(  1.0), FIX(1.0) };

		raster_triangle(tri);
	}
}

fix
fix_reciprocal(const fix f)
{
	return 0xFFFFFFFFU / (uint)f + 1U;
}

void
raster_triangle(const Triangle tri)
{
	// const Vec2 b = tri.b.xy;
	// const Vec2 a = tri.a.xy;
	// const Vec2 c = tri.c.xy;

	// // Finds the bounding box with all candidate pixels
	// fix x_min = MIN(MIN(a.x, b.x), c.x);
	// fix y_min = MIN(MIN(a.y, b.y), c.y);
	// fix x_max = MAX(MAX(a.x, b.x), c.x);
	// fix y_max = MAX(MAX(a.y, b.y), c.y);

	// // Compute the constant delta_s that will be used for the horizontal and vertical steps
	// fix dc_0 = (b.y - c.y);
	// fix dc_1 = (c.y - a.y);
	// fix dc_2 = (a.y - b.y);
	// fix dr_0 = (c.x - b.x);
	// fix dr_1 = (a.x - c.x);
	// fix dr_2 = (b.x - a.x);

	// // Rasterization fill convention (top-left rule)
	// fix bias0 = is_top_left(b, c) ? 0 : -1;
	// fix bias1 = is_top_left(c, a) ? 0 : -1;
	// fix bias2 = is_top_left(a, b) ? 0 : -1;

	// // Compute the edge functions for the fist (top-left) point
	// Vec2 p0 = { x_min, y_min };
	// fix w0_row = edge_cross(b, c, p0) + bias0;
	// fix w1_row = edge_cross(c, a, p0) + bias1;
	// fix w2_row = edge_cross(a, b, p0) + bias2;

	// fix area = edge_cross(a, b, c);

	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(1), fix_reciprocal(FIX(1)));
	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(2), fix_reciprocal(FIX(2)));
	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(3), fix_reciprocal(FIX(3)));
	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(4), fix_reciprocal(FIX(4)));
	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(5), fix_reciprocal(FIX(5)));
	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(6), fix_reciprocal(FIX(6)));
	// // print(ICELINK, "x = %q = 1 / %q\r\n", FIX(7), fix_reciprocal(FIX(7)));

	// // print(ICELINK, "");

	// print(ICELINK, "%q = 1 / %q\r\n", area, fix_reciprocal(area));
	// print(ICELINK, "%q = 1 / %q\r\n", INT(area), fix_reciprocal(INT(area)));

	// // xxx
	// OUIJA->x_min = INT(x_min);
	// OUIJA->x_max = INT(x_max);
	// OUIJA->y_min = INT(y_min);
	// OUIJA->y_max = INT(y_max);

	// // This exploits the fact that:
	// //
	// //     1.0 / X.0 = 0.Y <=> 1.0 / 0.X = Y.0
	// //
	// // Example:
	// //
	// //     1.0 / 2.0 = 0.5 <=> 1.0 / 0.2 = 5.0
	// //
	// // The advantage of doing this is a more precise reciprocal value.
	// //
	// OUIJA->reciprocal = fix_reciprocal(INT(area));

	// OUIJA->iw_0 = w0_row;
	// OUIJA->iw_1 = w1_row;
	// OUIJA->iw_2 = w2_row;
	// OUIJA->dc_0 = dc_0;
	// OUIJA->dc_1 = dc_1;
	// OUIJA->dc_2 = dc_2;
	// OUIJA->dr_0 = dr_0;
	// OUIJA->dr_1 = dr_1;
	// OUIJA->dr_2 = dr_2;

	// OUIJA->matrix.i = (Vec4) { FIX(160.0), FIX(  0.0), FIX(  0.0), FIX(   80.0) };
	// OUIJA->matrix.j = (Vec4) { FIX(  0.0), FIX(100.0), FIX(  0.0), FIX(   50.0) };
	// OUIJA->matrix.k = (Vec4) { FIX(  0.0), FIX(  0.0),    0x10008, FIX(-4096.5) };
	// OUIJA->matrix.l = (Vec4) { FIX(  0.0), FIX(  0.0), FIX(  1.0), FIX(    0.0) };
	OUIJA->matrix.i = (Vec4) { FIX(100.0), FIX(  0.0), FIX(  0.0), FIX(    0.0) };
	OUIJA->matrix.j = (Vec4) { FIX(  0.0), FIX(100.0), FIX(  0.0), FIX(    0.0) };
	OUIJA->matrix.k = (Vec4) { FIX(  0.0), FIX(  0.0), FIX(  0.0), FIX(    0.0) };
	OUIJA->matrix.l = (Vec4) { FIX(  0.0), FIX(  0.0), FIX(  1.0), FIX(    0.0) };
	OUIJA->triangle = tri;

	while (OUIJA->busy) {}
	OUIJA->fire = 1;

				// int alpha = (unsigned long long)(256*w0)*area_recip >> 32U;
				// int beta  = (unsigned long long)(256*w1)*area_recip >> 32U;
				// int gamma = (unsigned long long)(256*w2)*area_recip >> 32U;

				// unsigned r, g, b;

				// if (!tri.tex) {
				// 	r = srgb2linear[(ar*alpha + br*beta + cr*gamma) >> 8U];
				// 	g = srgb2linear[(ag*alpha + bg*beta + cg*gamma) >> 8U];
				// 	b = srgb2linear[(ab*alpha + bb*beta + cb*gamma) >> 8U];
				// } else {
				// 	int u = (au*alpha + bu*beta + cu*gamma) >> 8U;
				// 	int v = (av*alpha + bv*beta + cv*gamma) >> 8U;

				// 	int idx = 3*(32*u + v);
				// 	int sr = tri.tex[idx];
				// 	int sg = tri.tex[idx + 1];
				// 	int sb = tri.tex[idx + 2];

				// 	r = srgb2linear[sr];
				// 	g = srgb2linear[sg];
				// 	b = srgb2linear[sb];
				// }
}

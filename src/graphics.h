typedef unsigned short Color;

typedef struct {
	fix x;
	fix y;
} Vec2;

typedef struct {
	fix x;
	fix y;
	fix z;
} Vec3;

typedef struct {
	fix x;
	fix y;
	fix z;
	fix w;
} Vec4;

typedef struct {
	Vec4 i;
	Vec4 j;
	Vec4 k;
	Vec4 l;
} Mat4;

typedef struct {
	Vec3 xyz;
	Vec2 uv;
} Vertex;

typedef struct {
	Vertex a;
	Vertex b;
	Vertex c;
} Triangle;

typedef struct {
	Mat4     matrix;
	unsigned v_blank;
	unsigned fire;
	unsigned busy;
	Triangle triangle;
} Ouija;

void render_model(const Triangle model[], const int len, const Vec3 pov);
void fill_screen(const Color color);
void raster_triangle(const Triangle tri);

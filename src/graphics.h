typedef struct {
	int x;
	int y;
} Vec2;

typedef struct {
	int x;
	int y;
	int z;
} Vec3;

typedef struct {
	Vec2 xy;
	Vec2 uv;
	unsigned color;
} Vert2;

typedef struct {
	Vec3 xyz;
	Vec2 uv;
	unsigned color;
} Vert3;

typedef struct {
	char *tex;
	Vert2 a;
	Vert2 b;
	Vert2 c;
} Tri2;

typedef struct {
	char *tex;
	Vert3 a;
	Vert3 b;
	Vert3 c;
} Tri3;

void clear_screen(const unsigned short color);
void draw_pixel(const Vec2 p, const unsigned short color);
void draw_triangle(const Tri2 tri);

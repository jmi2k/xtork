typedef struct packed {
	bit signed[15:-16] x;
	bit signed[15:-16] y;
} Vec2;

typedef struct packed {
	bit signed[15:-16] x;
	bit signed[15:-16] y;
	bit signed[15:-16] z;
} Vec3;

typedef struct packed {
	bit signed[15:-16] x;
	bit signed[15:-16] y;
	bit signed[15:-16] z;
	bit signed[15:-16] w;
} Vec4;

typedef struct packed {
	Vec4 i;
	Vec4 j;
	Vec4 k;
	Vec4 l;
} Mat4;

typedef struct packed {
	Vec3 pos;
	Vec2 tex;
} Vertex;

typedef struct packed {
	Vertex a;
	Vertex b;
	Vertex c;
} Triangle;

typedef struct packed {
	bit[5:0] r;
	bit[5:0] g;
	bit[5:0] b;
} RGB_666;

`define vec2_add(l, r)   { 32'(l.x + r.x), 32'(l.y + r.y) }
`define vec2_sub(l, r)   { 32'(l.x - r.x), 32'(l.y - r.y) }

`define min(l, r)   ((l) < (r) ? (l) : (r))
`define max(l, r)   ((l) > (r) ? (l) : (r))

`define rgb666_pack(word)      { word[21:16], word[13:8], word[5:0] }
`define rgb666_unpack(color)   { color.b, 2'b00, color.g, 2'b00, color.r }

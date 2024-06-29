typedef unsigned char uchar;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef unsigned long long uvlong;

typedef long long vlong;
typedef signed char schar;

typedef int fix;

typedef volatile struct {
	int data;
	int divisor;
	int busy;
	int full;
} Uart;

#define NULL                            ((void *)0U)
#define ICELINK       ((volatile Uart *)0x20000000U)
// Defined in `graphics.h`.
#define OUIJA        ((volatile Ouija *)0x30000000U)
#define FRAME     ((volatile unsigned *)0x30020000U)
#define TEXTURE   ((volatile unsigned *)0x30040000U)

#define NELEMS(array)      (sizeof(array) / sizeof(*array))
#define MIN(left, right)   ((left) < (right) ? (left) : (right))
#define MAX(left, right)   ((left) > (right) ? (left) : (right))
#define FIX(i)             (fix)((i) * 0x10000)
#define INT(f)             (fix)((f) / 0x10000)
#define FRACT(f)           (fix)((f) % 0x10000)

int init(void);

//
// Memory.
//

void *copy_memory(
	const void *const restrict from,
	void *const restrict to,
	unsigned len);

void *set_memory(void *const mem, char val, unsigned len);

//
// Console.
//

char get_char(Uart *const);
void put_char(Uart *const, const char chr);
void put_decimal(Uart *const uart, unsigned val, int len);
void put_hexadecimal(Uart *const uart, const unsigned val, int len);
void put_octal(Uart *const uart, const unsigned val, int len);
void put_string(Uart *const, const char str[]);
void put_string_bogus(Uart *const, const char str[]);
void print(Uart *const uart, const char *fmt, ...);

//
// Strings.
//

int compare_strings(const char *left, const char *right);

//
// Numeric.
//

unsigned xorshift(void);
unsigned next_xorshift(unsigned state);

//
// Counters
//

extern void spin_cycles(int n);
extern unsigned long long read_cycle(void);
extern unsigned long long read_time(void);
extern unsigned long long read_instret(void);

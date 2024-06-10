#include <stdarg.h>

#include "u.h"

static const char DIGITS[] = {
	'0', '1', '2', '3',
	'4', '5', '6', '7',
	'8', '9', 'A', 'B',
	'C', 'D', 'E', 'F',
};

int
init(void)
{
	ICELINK->divisor = 77500000U / BAUDS;
	spin_cycles(100);

	return 0;
}

void *
copy_memory(
	const void *const restrict from,
	void *const restrict to,
	unsigned len
)
{
	const char *from_as_char = (const char *)from;
	char *to_as_char = (char *)to;

	while (len--)
		*to_as_char++ = *from_as_char++;

	return to;
}

void *
set_memory(void *const mem, char val, unsigned len)
{
	char *mem_as_char = (char *)mem;

	while (len--)
		*mem_as_char++ = val;

	return mem;
}

char
get_char(Uart *const uart)
{
	while (!uart->full) {}
	return uart->data;
}

void
put_char(Uart *const uart, const char chr)
{
	while (uart->busy) {}
	uart->data = chr;
}

void
put_decimal(Uart *const uart, unsigned val, int len)
{
	len = MAX(len, 1 +
		(val >         9) +
		(val >        99) +
		(val >       999) +
		(val >      9999) +
		(val >     99999) +
		(val >    999999) +
		(val >   9999999) +
		(val >  99999999) +
		(val > 999999999));

	int pos = len-1;

	unsigned powers[] = {
		1, 10, 100, 1000, 10000, 100000,
		1000000, 10000000, 100000000, 1000000000
	};

	// Pad zeros beyond the integer length limit.
	for (; pos > 9; --pos)
		put_char(uart, '0');

	for (; pos >= 0; --pos) {
		unsigned n = 0;

		while (val >= powers[pos]) {
			val -= powers[pos];
			n++;
		}

		put_char(uart, DIGITS[n]);
	}
}

void
put_hexadecimal(Uart *const uart, const unsigned val, int len)
{
	len = MAX(len, 1 +
		(val >       0xF) +
		(val >      0xFF) +
		(val >     0xFFF) +
		(val >    0xFFFF) +
		(val >   0xFFFFF) +
		(val >  0xFFFFFF) +
		(val > 0xFFFFFFF));

	int pos = len-1;

	// Pad zeros beyond the integer length limit.
	for (; pos > 4 + 8*(int)sizeof(val) / 4; --pos)
		put_char(uart, '0');

	for (; pos >= 0; --pos) {
		unsigned copy = val;
		copy >>= pos;
		copy >>= pos;
		copy >>= pos;
		copy >>= pos;

		char digit = DIGITS[copy & 0xF];
		put_char(uart, digit);
	}
}

void
put_octal(Uart *const uart, const unsigned val, int len)
{
	len = MAX(len, 1 +
		(val >          07) +
		(val >         077) +
		(val >        0777) +
		(val >       07777) +
		(val >      077777) +
		(val >     0777777) +
		(val >    07777777) +
		(val >   077777777) +
		(val >  0777777777) +
		(val > 07777777777));

	int pos = len-1;

	// Pad zeros beyond the integer length limit.
	for (; pos > 3 + 8*(int)sizeof(val) / 3; --pos)
		put_char(uart, '0');

	for (; pos >= 0; --pos) {
		unsigned copy = val;
		copy >>= pos;
		copy >>= pos;
		copy >>= pos;

		char digit = DIGITS[copy & 07];
		put_char(uart, digit);
	}
}

void
put_string(Uart *const uart, const char str[])
{
	while (*str)
		put_char(uart, *str++);
}

void
print(Uart *const uart, const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);

	while (*fmt) {
		// Pass regular characters through.
		if (*fmt != '%') {
			put_char(uart, *fmt++);
			continue;
		}

		// Interpret print sequences.
		switch (*++fmt) {
		case 'c': {
			const unsigned arg = va_arg(args, const unsigned);
			put_char(uart, (char)arg);
			break;
		}

		case 'd': {
			const unsigned arg = va_arg(args, const unsigned);
			put_decimal(uart, arg, 0);
			break;
		}

		case 'o': {
			const unsigned arg = va_arg(args, const unsigned);
			put_octal(uart, arg, 0);
			break;
		}

		case 'x': {
			const unsigned arg = va_arg(args, const unsigned);
			put_hexadecimal(uart, arg, 0);
			break;
		}

		case 's': {
			const char *const arg = va_arg(args, const char *const);
			put_string(uart, arg);
			break;
		}

		case '\0':
			goto End;

		default:
			put_char(uart, *fmt);
			break;
		}

		fmt++;
	}

End:
	va_end(args);
}

int
compare_strings(const char *left, const char *right)
{
	while (*left && *left == *right) {
		++left;
		++right;
	}

	return (int)*left - (int)*right;
}

unsigned
xorshift(void)
{
	static unsigned state = 0xDEADBEEFU;
	state = next_xorshift(state);

	return state;
}

unsigned
next_xorshift(unsigned state)
{
	state ^= state << 13U;
	state ^= state >> 17U;
	state ^= state << 5U;

	return state;
}

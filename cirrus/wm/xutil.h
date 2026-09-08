// See LICENSE file for copyright and license details.

#ifndef XUTIL_H
#define XUTIL_H

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static inline int16_t
i16_from_i32(int32_t v)
{
	return (int16_t)v;
}

static inline uint16_t
u16_from_i32(int32_t v)
{
	return (uint16_t)v;
}

static inline uint16_t
u16_from_u32(uint32_t v)
{
	return (uint16_t)v;
}

#define u32_from_i32(v) u32_from_i32_impl((v), __FILE__, __LINE__, #v)

static inline uint32_t
u32_from_i32_impl(int32_t v,
	const char *file,
	int line,
	const char *expr)
{
	if (v < 0) {
		fprintf(stderr,
			"%s:%d  %s = %d\n",
			file, line, expr, v);
		abort();
	}
	return (uint32_t)v;
}

#endif

// See LICENSE file for copyright and license details.

#ifndef MONITOR_H
#define MONITOR_H

#include <stdint.h>
#include <xcb/randr.h>

#include "types.h"
#include "list.h"

extern int randr_base;

// static struct monitor *add_monitor(xcb_randr_output_t, char *, int16_t, int16_t, uint16_t, uint16_t);
// static struct monitor *find_clones(xcb_randr_output_t, int16_t, int16_t);
struct monitor *find_monitor_by_coord(int16_t, int16_t);
struct monitor *find_monitor(xcb_randr_output_t);

// static void arrange_by_monitor(struct monitor *);
// static void free_monitor(struct monitor *);
void get_monitor_size(struct client *, int16_t *, int16_t *, uint16_t *, uint16_t *);
// static void get_outputs(xcb_randr_output_t *, int len, xcb_timestamp_t);
void get_randr(void);

#endif

// See LICENSE file for copyright and license details.

#ifndef RANDR_H
#define RANDR_H

extern int randr_base;
extern struct list_item *mon_list;

struct monitor *find_monitor_by_coord(int16_t, int16_t);

void get_randr(void);
void get_monitor_size(struct client *, int16_t *, int16_t *, uint16_t *, uint16_t *);

#endif

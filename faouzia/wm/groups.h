// See LICENSE file for copyright and license details.

#ifndef GROUPS_H
#define GROUPS_H

#include <stdint.h>

#include "types.h"

extern bool *group_in_use;

void change_nr_of_groups(uint32_t);
void group_activate(uint32_t);
void group_activate_specific(uint32_t);
void group_add_window(struct client *, uint32_t);
void group_deactivate(uint32_t);
void group_remove_all_windows(uint32_t);
void group_remove_window(struct client *);
void group_toggle(uint32_t);
void update_group_list(void);

#endif

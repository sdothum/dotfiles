// See LICENSE file for copyright and license details.

#ifndef LIST_H
#define LIST_H

#include <stdbool.h>

struct list_item {
	void *data;
	struct list_item *next;
	struct list_item *prev;
};

struct list_item *list_add_item(struct list_item **);

void list_delete_all_items(struct list_item **, bool);
void list_delete_item(struct list_item **, struct list_item *);
void list_move_to_head(struct list_item **, struct list_item *);

#endif

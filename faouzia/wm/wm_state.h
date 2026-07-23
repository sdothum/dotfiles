// See LICENSE file for copyright and license details.

#ifndef WM_STATE_H
#define WM_STATE_H

#include <xcb/xcb.h>
#include <xcb/xcb_ewmh.h>

#include "atoms.h"
#include "config.h"
#include "list.h"
#include "types.h"

#define EVENT_MASK(ev) (((ev) & ~0x80))
#define NULL_GROUP 0xffffffff

extern bool halt;
extern int  exit_code;
extern int last_group;

extern struct conf conf;
extern xcb_connection_t *conn;
extern xcb_screen_t *scr;

extern struct client *focused_win;
extern struct list_item *focus_list;
extern struct list_item *mon_list;
extern struct list_item *win_list;

/* XCB event with the biggest value */
#define LAST_XCB_EVENT XCB_GET_MODIFIER_MAPPING
extern void (*events[LAST_XCB_EVENT + 1])(xcb_generic_event_t *);

extern xcb_atom_t ATOMS[NR_ATOMS];
extern xcb_ewmh_connection_t *ewmh;

#endif

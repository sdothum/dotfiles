// See LICENSE file for copyright and license details.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xcb/randr.h>
#include <xcb/xcb.h>

#include "helpers.h"
#include "list.h"
#include "monitor.h"
#include "window.h"
#include "wm_state.h"

/*
 * Add a monitor to the global monitor list.
 */

static struct monitor *
add_monitor(xcb_randr_output_t mon, char *name, int16_t x, int16_t y, uint16_t width, uint16_t height)
{
	struct list_item *item;
	struct monitor *monitor = malloc(sizeof(struct monitor));

	if (monitor == NULL)
		return NULL;

	item = list_add_item(&mon_list);
	if (item == NULL) {
		free(monitor);
		return NULL;
	}

	item->data = monitor;
	monitor->item = item;
	monitor->monitor = mon;
	monitor->name = name;
	monitor->x = x;
	monitor->y = y;
	monitor->width = width;
	monitor->height = height;

	return monitor;
}

/*
 * Find cloned (mirrored) outputs.
 */

static struct monitor *
find_clones(xcb_randr_output_t mon, int16_t x, int16_t y)
{
	struct monitor *clonemon;
	struct list_item *item;

	item = mon_list;
	while (item != NULL && ((clonemon = item->data)->monitor == mon
			|| clonemon->x != x
			|| clonemon->y != y)) {
		item = item->next;
	}

	if (item == NULL)
		return NULL;
	else
		return clonemon;
}

/*
 * Find a monitor in the list by its coordinates.
 */

struct monitor *
find_monitor_by_coord(int16_t x, int16_t y)
{
	struct list_item *item;
	struct monitor *m, *ret;

	m = ret = NULL;
	item = mon_list;
	while (item != NULL) {
		m = item->data;
		if (x >= m->x && x <= m->x + m->width
			&& y >= m->y && y <= m->y + m->height)
			ret = m;

		item = item->next;
	}

	return ret;
}

/*
 * Finds a monitor in the list.
 */

struct monitor *
find_monitor(xcb_randr_output_t mon)
{
	struct list_item *item;
	struct monitor *m;

	item = mon_list;
	while (item != NULL && (m = item->data)->monitor != mon)
		item = item->next;

	if (item == NULL)
		return NULL;
	else
		return item->data;
}

/*
 * Arrange clients on a monitor.
 */

static void
arrange_by_monitor(struct monitor *mon)
{
	struct client *client;
	struct list_item *item;

	for (item = win_list; item != NULL; item = item->next) {
		client = item->data;

		if (client->monitor == mon)
			fit_on_screen(client);
	}
}

/*
 * Free a monitor from the global monitor list.
 */

static void
free_monitor(struct monitor *mon)
{
	struct list_item *item = mon->item;

	free(mon);
	list_delete_item(&mon_list, item);
}

/*
 * Get information about a certain monitor situated in a window: coordinates and size.
 */

void
get_monitor_size(struct client *client, int16_t *mon_x, int16_t *mon_y, uint16_t *mon_width, uint16_t *mon_height)
{
	if (client == NULL || client->monitor == NULL) {
		if (mon_x != NULL && mon_y != NULL)
			*mon_x = *mon_y = 0;
		if (mon_width != NULL)
			*mon_width = scr->width_in_pixels;
		if (mon_height != NULL)
			*mon_height = scr->height_in_pixels;
	} else {
		if (mon_x != NULL)
			*mon_x = client->monitor->x;
		if (mon_y != NULL)
			*mon_y = client->monitor->y;
		if (mon_width != NULL)
			*mon_width = client->monitor->width;
		if (mon_height != NULL)
			*mon_height = client->monitor->height;
	}
}

/*
 * Gets information about connected outputs.
 */

static void
get_outputs(xcb_randr_output_t *outputs, int len, xcb_timestamp_t timestamp)
{
	int name_len;
	char *name;
	xcb_randr_get_crtc_info_cookie_t info_c;
	xcb_randr_get_crtc_info_reply_t *crtc;
	xcb_randr_get_output_info_reply_t *output;
	struct monitor *mon, *clonemon;
	struct list_item *item;
	xcb_randr_get_output_info_cookie_t out_cookie[len];

	for (int i = 0; i < len; i++)
		out_cookie[i] = xcb_randr_get_output_info(conn, outputs[i],
				timestamp);

	for (int i = 0; i < len; i++) {
		output = xcb_randr_get_output_info_reply(conn, out_cookie[i], NULL);
		if (output == NULL)
			continue;

		name_len = xcb_randr_get_output_info_name_length(output);
		if (16 < name_len)
			name_len = 16;

		/* +1 for the null character */
		name = malloc(name_len + 1);
		/* make sure the name is at most name_len + 1 length
		 * or we may run into problems. */
		snprintf(name, name_len + 1, "%.*s", name_len,
				xcb_randr_get_output_info_name(output));

		if (output->crtc != XCB_NONE) {
			info_c = xcb_randr_get_crtc_info(conn, output->crtc,
					timestamp);
			crtc = xcb_randr_get_crtc_info_reply(conn, info_c, NULL);

			if (crtc == NULL)
				return;

			clonemon = find_clones(outputs[i], crtc->x, crtc->y);
			if (clonemon != NULL)
				continue;

			mon = find_monitor(outputs[i]);
			if (mon == NULL) {
				add_monitor(outputs[i], name, crtc->x, crtc->y,
						crtc->width, crtc->height);
			} else {
				mon->x = crtc->x;
				mon->y = crtc->y;
				mon->width = crtc->width;
				mon->height = crtc->height;

				arrange_by_monitor(mon);
			}

			free(crtc);
		} else {
			/* Check if the monitor was used before
			 * becoming disabled. */
			mon = find_monitor(outputs[i]);
			if (mon) {
				struct client *client;
				for (item = win_list; item != NULL; item = item->next) {
					/* Move window from this monitor to either the next one or the first one. */
					client = item->data;

					if (client->monitor == mon) {
						if (client->monitor->item->next)
							/* If at end, take from the beginning */
							if (mon_list == NULL)
								client->monitor = NULL;
							else
								client->monitor = mon_list->data;
						else
							client->monitor = client->monitor->item->next->data;
						fit_on_screen(client);
					}
				}

				/* Monitor not active. Delete it. */
				free_monitor(mon);
			}
		}

		if (output != NULL)
			free(output);
		free(name);
	}
}

/*
 * Get information regarding randr.
 */

void
get_randr(void)
{
	int len;
	xcb_randr_get_screen_resources_current_cookie_t c
		= xcb_randr_get_screen_resources_current(conn, scr->root);
	xcb_randr_get_screen_resources_current_reply_t *r
		= xcb_randr_get_screen_resources_current_reply(conn, c, NULL);

	if (r == NULL)
		return;

	xcb_timestamp_t timestamp = r->config_timestamp;
	len = xcb_randr_get_screen_resources_current_outputs_length(r);
	xcb_randr_output_t *outputs
		= xcb_randr_get_screen_resources_current_outputs(r);

	/* Request information for all outputs */
	get_outputs(outputs, len, timestamp);
	free(r);
}


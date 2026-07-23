// See LICENSE file for copyright and license details.

#include <err.h>
#include <getopt.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include "common.h"
#include "ewmh.h"
#include "events.h"
#include "groups.h"
#include "ipc_handlers.h"
#include "randr.h"
#include "setup.h"
#include "types.h"
#include "wm_state.h"
#include "xutil.h"

/* connection to the X server */
xcb_connection_t *conn;
xcb_ewmh_connection_t *ewmh;
xcb_screen_t *scr;

xcb_visualtype_t *argb_visual;
xcb_colormap_t argb_colormap;
xcb_render_pictformat_t argb_format;

struct client *focused_win;
struct conf conf;

int scrno;       // number of screens
int randr_base;  // base for checking randr events

bool halt;
int  exit_code;

uint16_t num_lock, caps_lock, scroll_lock;  // keyboard modifiers (for mouse support)
const xcb_button_index_t mouse_buttons[] = {
	XCB_BUTTON_INDEX_1,
	XCB_BUTTON_INDEX_2,
	XCB_BUTTON_INDEX_3,
};

/* list of all windows. NULL is the empty list */
struct list_item *win_list   = NULL;
struct list_item *mon_list   = NULL;
struct list_item *focus_list = NULL;

bool *group_in_use = NULL;
int  last_group = 0;

xcb_atom_t ATOMS[NR_ATOMS];

/* function handlers for ipc commands */
void (*ipc_handlers[NR_IPC_COMMANDS])(uint32_t *);
/* function handlers for events received from the X server */
void (*events[LAST_XCB_EVENT + 1])(xcb_generic_event_t *);

static void
run(void)
{
	xcb_generic_event_t *ev;

	update_group_list();
	halt = false;
	exit_code = EXIT_SUCCESS;
	while (!halt) {
		xcb_flush(conn);
		ev = xcb_wait_for_event(conn);
		if (ev) {
			DMSG("X Event %d\n", ev->response_type & ~0x80);
			if (ev->response_type == randr_base + XCB_RANDR_SCREEN_CHANGE_NOTIFY) {
				get_randr();
				DMSG("Screen layout changed\n");
			}
			if (events[EVENT_MASK(ev->response_type)] != NULL)
				(events[EVENT_MASK(ev->response_type)])(ev);
			free(ev);
		}
	}
}

static void
usage(char *name)
{
	fprintf(stderr, "Usage: %s [-h|-v|-c CONFIG_PATH]\n", name);

	exit(EXIT_SUCCESS);
}

static void version(void)
{
	fprintf(stderr, "%s %s\n", __NAME__, __THIS_VERSION__);
	fprintf(stderr, "Copyright (c) 2016-2019 Tudor Ioan Roman\n");
	fprintf(stderr, "Released under the ISC License\n");

	exit(EXIT_SUCCESS);
}

void
handle_child(int sig)
{
	if (sig == SIGCHLD) {
		wait(NULL);
	}
}

int main(int argc, char *argv[])
{
	int opt;
	char *config_path = malloc(MAXLEN * sizeof(char));
	config_path[0] = '\0';
	while ((opt = getopt(argc, argv, "hvc:")) != -1) {
		switch (opt) {
			case 'h':
				usage(argv[0]);
				break;
			case 'c':
				snprintf(config_path, MAXLEN * sizeof(char), "%s", optarg);
				break;
			case 'v':
				version();
				break;
		}
	}
	atexit(cleanup);

	register_event_handlers();
	register_ipc_handlers();
	load_defaults();

	if (setup() < 0)
		errx(EXIT_FAILURE, "error connecting to X");
	/* if not set, get path of the rc file */
	if (config_path[0] == '\0') {
		char *xdg_home = getenv("XDG_CONFIG_HOME");
		if (xdg_home != NULL)
			snprintf(config_path, MAXLEN * sizeof(char), "%s/%s/%s", xdg_home, __NAME__, __CONFIG_NAME__);
		else
			snprintf(config_path, MAXLEN * sizeof(char), "%s/%s/%s/%s", getenv("HOME"), ".config",
					__NAME__, __CONFIG_NAME__);
	}

	signal(SIGCHLD, handle_child);

	/* execute config file */
	load_config(config_path);
	run();

	free(config_path);

	return exit_code;
}


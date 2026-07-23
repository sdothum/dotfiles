// See LICENSE file for copyright and license details.

#ifndef IPC_HANDLERS_H
#define IPC_HANDLERS_H

#include <stdint.h>

#include "ipc.h"

extern void (*ipc_handlers[NR_IPC_COMMANDS])(uint32_t *);

void register_ipc_handlers(void);

#endif

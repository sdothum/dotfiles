/* Copyright (c) 2016-2019 Tudor Ioan Roman. All rights reserved. */
/* Licensed under the ISC License. See the LICENSE file in the project root for full license information. */

#ifndef WM_COMMON_H
#define WM_COMMON_H

#ifdef D
#define DMSG(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)
#else
#define DMSG(fmt, ...)
#endif

#ifndef __NAME__
#define __NAME__ "wm"
#endif

#ifndef __NAME_CLIENT__
#define __NAME_CLIENT__ "wmc"
#endif

#ifndef __CONFIG_NAME__
#define __CONFIG_NAME__ "wmrc"
#endif

#ifndef __THIS_VERSION__
#define __THIS_VERSION__ ""
#endif

#define MAXLEN 256

#endif

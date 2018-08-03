/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

#ifndef WIREGUARD_H
#define WIREGUARD_H

#include <sys/types.h>

typedef struct { const char *p; size_t n; } gostring_t;
typedef ssize_t(*read_write_fn_t)(const void *ctx, const unsigned char *buf, size_t len);
typedef void(*logger_fn_t)(int level, const char *tag, const char *msg);
extern void wgSetLogger(logger_fn_t logger_fn);
extern int wgTurnOn(gostring_t ifname, gostring_t settings, read_write_fn_t read_fn, read_write_fn_t write_fn, void *ctx);
extern void wgTurnOff(int handle);
extern char *wgVersion(void);

#endif

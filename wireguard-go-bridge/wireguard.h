/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 WireGuard LLC. All Rights Reserved.
 */

#ifndef WIREGUARD_H
#define WIREGUARD_H

#include <sys/types.h>
#include <stdint.h>

typedef struct { const char *p; size_t n; } gostring_t;
typedef ssize_t(*read_write_fn_t)(void *ctx, unsigned char *buf, size_t len);
typedef void(*logger_fn_t)(int level, const char *msg);
extern void wgSetLogger(logger_fn_t logger_fn);
extern int wgTurnOn(gostring_t ifname, gostring_t settings, uint16_t mtu, read_write_fn_t read_fn, read_write_fn_t write_fn, void *ctx);
extern void wgTurnOff(int handle);
extern char *wgVersion();

#endif

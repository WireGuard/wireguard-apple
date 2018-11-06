/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 WireGuard LLC. All Rights Reserved.
 */

#ifndef WIREGUARD_H
#define WIREGUARD_H

#include <sys/types.h>
#include <stdint.h>

typedef struct { const char *p; size_t n; } gostring_t;
typedef void(*logger_fn_t)(int level, const char *msg);
extern void wgSetLogger(logger_fn_t logger_fn);
extern int wgTurnOn(gostring_t ifname, gostring_t settings, int32_t tun_fd);
extern void wgTurnOff(int handle);
extern char *wgVersion();

#endif

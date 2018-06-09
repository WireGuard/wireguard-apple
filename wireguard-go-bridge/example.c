/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

#include "wireguard.h"
#include <stdio.h>
#include <stdbool.h>
#include <unistd.h>

static struct {
	int something;
} ctx;

static bool is_closed = false;

ssize_t do_read(const void *ctx, const unsigned char *buf, size_t len)
{
	printf("Reading from instance with ctx %p into buffer %p of length %zu\n", ctx, buf, len);
	sleep(1);
	return is_closed ? -1 : 0;
}

ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len)
{
	printf("Writing from instance with ctx %p into buffer %p of length %zu\n", ctx, buf, len);
	return len;
}

void do_log(int level, const char *tag, const char *msg)
{
	printf("Log level %d for %s: %s", level, tag, msg);
}

int main(int argc, char *argv[])
{
	int handle;

	printf("WireGuard Go Version %s\n", wgVersion());
	wgSetLogger(do_log);
	handle = wgTurnOn((gostring_t){ .p = "test", .n = 4 }, (gostring_t){ .p = "", .n = 0 }, do_read, do_write, &ctx);
	sleep(5);
	is_closed = true;
	wgTurnOff(handle);
	return 0;
}

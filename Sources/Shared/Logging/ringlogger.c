/* SPDX-License-Identifier: MIT
 *
 * Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.
 */

#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <time.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/mman.h>
#include "ringlogger.h"

enum {
	MAX_LOG_LINE_LENGTH = 512,
	MAX_LINES = 2048,
	MAGIC = 0xabadbeefU
};

struct log_line {
	atomic_uint_fast64_t time_ns;
	char line[MAX_LOG_LINE_LENGTH];
};

struct log {
	atomic_uint_fast32_t next_index;
	struct log_line lines[MAX_LINES];
	uint32_t magic;
};

void write_msg_to_log(struct log *log, const char *tag, const char *msg)
{
	uint32_t index;
	struct log_line *line;
	struct timespec ts;

	// Race: This isn't synchronized with the fetch_add below, so items might be slightly out of order.
	clock_gettime(CLOCK_REALTIME, &ts);

	// Race: More than MAX_LINES writers and this will clash.
	index = atomic_fetch_add(&log->next_index, 1);
	line = &log->lines[index % MAX_LINES];

	// Race: Before this line executes, we'll display old data after new data.
	atomic_store(&line->time_ns, 0);
	memset(line->line, 0, MAX_LOG_LINE_LENGTH);

	snprintf(line->line, MAX_LOG_LINE_LENGTH, "[%s] %s", tag, msg);
	atomic_store(&line->time_ns, ts.tv_sec * 1000000000ULL + ts.tv_nsec);

	msync(&log->next_index, sizeof(log->next_index), MS_ASYNC);
	msync(line, sizeof(*line), MS_ASYNC);
}

int write_log_to_file(const char *file_name, const struct log *input_log)
{
	struct log *log;
	uint32_t l, i;
	FILE *file;
	int ret;

	log = malloc(sizeof(*log));
	if (!log)
		return -errno;
	memcpy(log, input_log, sizeof(*log));

	file = fopen(file_name, "w");
	if (!file) {
		free(log);
		return -errno;
	}

	for (l = 0, i = log->next_index; l < MAX_LINES; ++l, ++i) {
		const struct log_line *line = &log->lines[i % MAX_LINES];
		time_t seconds = line->time_ns / 1000000000ULL;
		uint32_t useconds = (line->time_ns % 1000000000ULL) / 1000ULL;
		struct tm tm;

		if (!line->time_ns)
			continue;

		if (!localtime_r(&seconds, &tm))
			goto err;

		if (fprintf(file, "%04d-%02d-%02d %02d:%02d:%02d.%06d: %s\n",
				  tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
				  tm.tm_hour, tm.tm_min, tm.tm_sec, useconds,
				  line->line) < 0)
			goto err;


	}
	errno = 0;

err:
	ret = -errno;
	fclose(file);
	free(log);
	return ret;
}

uint32_t view_lines_from_cursor(const struct log *input_log, uint32_t cursor, void *ctx, void(*cb)(const char *, uint64_t, void *))
{
	struct log *log;
	uint32_t l, i = cursor;

	log = malloc(sizeof(*log));
	if (!log)
		return cursor;
	memcpy(log, input_log, sizeof(*log));

	if (i == -1)
		i = log->next_index;

	for (l = 0; l < MAX_LINES; ++l, ++i) {
		const struct log_line *line = &log->lines[i % MAX_LINES];

		if (cursor != -1 && i % MAX_LINES == log->next_index % MAX_LINES)
			break;

		if (!line->time_ns) {
			if (cursor == -1)
				continue;
			else
				break;
		}
		cb(line->line, line->time_ns, ctx);
		cursor = (i + 1) % MAX_LINES;
	}
	free(log);
	return cursor;
}

struct log *open_log(const char *file_name)
{
	int fd;
	struct log *log;

	fd = open(file_name, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
	if (fd < 0)
		return NULL;
	if (ftruncate(fd, sizeof(*log)))
		goto err;
	log = mmap(NULL, sizeof(*log), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (log == MAP_FAILED)
		goto err;
	close(fd);

	if (log->magic != MAGIC) {
		memset(log, 0, sizeof(*log));
		log->magic = MAGIC;
		msync(log, sizeof(*log), MS_ASYNC);
	}

	return log;

err:
	close(fd);
	return NULL;
}

void close_log(struct log *log)
{
	munmap(log, sizeof(*log));
}

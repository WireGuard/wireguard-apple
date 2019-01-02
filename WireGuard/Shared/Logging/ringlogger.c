/* SPDX-License-Identifier: MIT
 *
 * Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.
 */

#include <string.h>
#include <stdio.h>
#include <stdint.h>
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
	MAX_LINES = 1024,
	MAGIC = 0xbeefbabeU
};

struct log_line {
	struct timeval tv;
	char line[MAX_LOG_LINE_LENGTH];
};

struct log {
	struct { uint32_t first, len; } header;
	struct log_line lines[MAX_LINES];
	uint32_t magic;
};

void write_msg_to_log(struct log *log, const char *msg)
{
	struct log_line *line = &log->lines[(log->header.first + log->header.len) % MAX_LINES];

	if (log->header.len == MAX_LINES)
		log->header.first = (log->header.first + 1) % MAX_LINES;
	else
		++log->header.len;

	gettimeofday(&line->tv, NULL);
	strncpy(line->line, msg, MAX_LOG_LINE_LENGTH - 1);
	line->line[MAX_LOG_LINE_LENGTH - 1] = '\0';

	msync(&log->header, sizeof(log->header), MS_ASYNC);
	msync(line, sizeof(*line), MS_ASYNC);
}

static bool first_before_second(const struct log_line *line1, const struct log_line *line2)
{
	if (line1->tv.tv_sec <= line2->tv.tv_sec)
		return true;
	if (line1->tv.tv_sec == line2->tv.tv_sec)
		return line1->tv.tv_usec <= line2->tv.tv_usec;
	return false;
}

int write_logs_to_file(const char *file_name, const struct log *log1, const char *tag1, const struct log *log2, const char *tag2)
{
	uint32_t i1, i2, len1 = log1->header.len, len2 = log2->header.len;
	FILE *file;
	int ret;

	if (len1 > MAX_LINES)
		len1 = MAX_LINES;
	if (len2 > MAX_LINES)
		len2 = MAX_LINES;

	file = fopen(file_name, "w");
	if (!file)
		return -errno;

	for (i1 = 0, i2 = 0;;) {
		struct tm tm;
		char buf[MAX_LOG_LINE_LENGTH];
		const struct log_line *line1 = &log1->lines[(log1->header.first + i1) % MAX_LINES];
		const struct log_line *line2 = &log2->lines[(log2->header.first + i2) % MAX_LINES];
		const struct log_line *line;
		const char *tag;

		if (i1 < len1 && (i2 >= len2 || first_before_second(line1, line2))) {
			line = line1;
			tag = tag1;
			++i1;
		} else if (i2 < len2 && (i1 >= len1 || first_before_second(line2, line1))) {
			line = line2;
			tag = tag2;
			++i2;
		} else {
			break;
		}

		memcpy(buf, line->line, MAX_LOG_LINE_LENGTH);
		buf[MAX_LOG_LINE_LENGTH - 1] = '\0';
		if (!localtime_r(&line->tv.tv_sec, &tm))
			goto err;
		if (fprintf(file, "%04d-%02d-%02d %02d:%02d:%02d.%06d: [%s] %s\n",
				  tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
				  tm.tm_hour, tm.tm_min, tm.tm_sec, line->tv.tv_usec,
				  tag, buf) < 0)
			goto err;
	}
	errno = 0;

err:
	ret = -errno;
	fclose(file);
	return ret;
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

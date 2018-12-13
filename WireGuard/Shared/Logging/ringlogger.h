/* SPDX-License-Identifier: MIT
 *
 * Copyright © 2018 WireGuard LLC. All Rights Reserved.
 */

#ifndef RINGLOGGER_H
#define RINGLOGGER_H

enum {
    MAX_LOG_LINE_LENGTH = 512,
    MAX_LINES = 1024,
    MAGIC = 0xdeadbeefU
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

void write_msg_to_log(struct log *log, const char *msg);
int write_logs_to_file(const char *file_name, const char *tag1, const struct log *log1, const char *tag2, const struct log *log2);
struct log *open_log(const char *file_name);

#endif

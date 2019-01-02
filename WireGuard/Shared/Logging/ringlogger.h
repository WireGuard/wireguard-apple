/* SPDX-License-Identifier: MIT
 *
 * Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.
 */

#ifndef RINGLOGGER_H
#define RINGLOGGER_H

struct log;
void write_msg_to_log(struct log *log, const char *msg);
int write_logs_to_file(const char *file_name, const struct log *log1, const char *tag1, const struct log *log2, const char *tag2);
struct log *open_log(const char *file_name);
void close_log(struct log *log);

#endif

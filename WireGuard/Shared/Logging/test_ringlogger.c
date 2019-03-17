#include "ringlogger.h"
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <inttypes.h>
#include <sys/wait.h>

static void forkwrite(void)
{
	struct log *log = open_log("/tmp/test_log");
	char c[512];
	int i, base;
	bool in_fork = !fork();

	base = 10000 * in_fork;
	for (i = 0; i < 1024; ++i) {
		snprintf(c, 512, "bla bla bla %d", base + i);
		write_msg_to_log(log, "HMM", c);
	}


	if (in_fork)
		_exit(0);
	wait(NULL);

	write_log_to_file("/dev/stdout", log);
	close_log(log);
}

static void writetext(const char *text)
{
	struct log *log = open_log("/tmp/test_log");
	write_msg_to_log(log, "TXT", text);
	close_log(log);
}

static void show_line(const char *line, uint64_t time_ns)
{
	printf("%" PRIu64 ": %s\n", time_ns, line);
}

static void follow(void)
{
	uint32_t cursor = -1;
	struct log *log = open_log("/tmp/test_log");

	for (;;) {
		cursor = view_lines_from_cursor(log, cursor, show_line);
		usleep(1000 * 300);
	}
}

int main(int argc, char *argv[])
{
	if (!strcmp(argv[1], "fork"))
		forkwrite();
	else if (!strcmp(argv[1], "write"))
		writetext(argv[2]);
	else if (!strcmp(argv[1], "follow"))
		follow();
	return 0;
}

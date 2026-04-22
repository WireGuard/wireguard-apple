// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

#include <stdint.h>

#include "key.h"
#include "x25519.h"

/* From <sys/kern_control.h> */
#define CTLIOCGINFO 0xc0644e03UL
struct ctl_info {
    uint32_t    ctl_id;
    char        ctl_name[96];
};
struct sockaddr_ctl {
    uint8_t     sc_len;
    uint8_t     sc_family;
    uint16_t    ss_sysaddr;
    uint32_t    sc_id;
    uint32_t    sc_unit;
    uint32_t    sc_reserved[5];
};

/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2017-2019 WireGuard LLC. All Rights Reserved.
 */

package main

/* Fit within memory limits for iOS */

const (
	QueueOutboundSize          = 1024
	QueueInboundSize           = 1024
	QueueHandshakeSize         = 1024
	MaxSegmentSize             = 1700
	PreallocatedBuffersPerPool = 1024
)

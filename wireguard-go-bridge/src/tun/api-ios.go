/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2017-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

package tun

import (
	"golang.org/x/sys/unix"
	"net"
	"os"
)

func CreateTUNFromFD(tunFd int) (TUNDevice, string, error) {
	err := unix.SetNonblock(tunFd, true)
	if err != nil {
		return nil, "", err
	}
	file := os.NewFile(uintptr(tunFd), "/dev/tun")
	tun := &nativeTun{
		tunFile: file,
		events:  make(chan TUNEvent, 5),
		errors:  make(chan error, 5),
	}
	name, err := tun.Name()
	if err != nil {
		return nil, "", err
	}
	tunIfindex, err := func() (int, error) {
		iface, err := net.InterfaceByName(name)
		if err != nil {
			return -1, err
		}
		return iface.Index, nil
	}()
	if err != nil {
		return nil, "", err
	}
	tun.routeSocket, err = unix.Socket(unix.AF_ROUTE, unix.SOCK_RAW, unix.AF_UNSPEC)
	if err != nil {
		return nil, "", err
	}
	go tun.routineRouteListener(tunIfindex)

	return tun, name, nil
}

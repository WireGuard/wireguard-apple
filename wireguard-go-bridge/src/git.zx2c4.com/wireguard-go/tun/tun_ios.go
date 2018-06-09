/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

package tun

// #include <sys/types.h>
// static ssize_t callFnWithCtx(const void *func, const void *ctx, const void *buffer, size_t len)
// {
// 	return ((ssize_t(*)(const void *, const unsigned char *, size_t))func)(ctx, buffer, len);
// }
import "C"

import (
	"os"
	"syscall"
	"unsafe"
)

type nativeTun struct {
	events  chan TUNEvent
	mtu     int
	readFn  unsafe.Pointer
	writeFn unsafe.Pointer
	ctx     unsafe.Pointer
}

func CreateTUN(mtu int, readFn unsafe.Pointer, writeFn unsafe.Pointer, ctx unsafe.Pointer) TUNDevice {
	tun := &nativeTun{
		events:  make(chan TUNEvent, 10),
		mtu:     mtu,
		readFn:  readFn,
		writeFn: writeFn,
		ctx:     ctx,
	}
	tun.events <- TUNEventUp
	return tun
}

func (tun *nativeTun) Name() (string, error) {
	return "tun", nil
}

func (tun *nativeTun) File() *os.File {
	return nil
}

func (tun *nativeTun) Events() chan TUNEvent {
	return tun.events
}

func (tun *nativeTun) Read(buff []byte, offset int) (int, error) {
	buff = buff[offset:]
	ret := C.callFnWithCtx(tun.readFn, tun.ctx, unsafe.Pointer(&buff[0]), C.size_t(len(buff)))
	if ret < 0 {
		return 0, syscall.Errno(-ret)
	}
	return int(ret), nil
}

func (tun *nativeTun) Write(buff []byte, offset int) (int, error) {
	buff = buff[offset:]
	ret := C.callFnWithCtx(tun.writeFn, tun.ctx, unsafe.Pointer(&buff[0]), C.size_t(len(buff)))
	if ret < 0 {
		return 0, syscall.Errno(-ret)
	}
	return int(ret), nil
}

func (tun *nativeTun) Close() error {
	if tun.events != nil {
		close(tun.events)
	}
	return nil
}

func (tun *nativeTun) setMTU(n int) error {
	tun.mtu = n
	return nil
}

func (tun *nativeTun) MTU() (int, error) {
	return tun.mtu, nil
}

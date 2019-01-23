/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018-2019 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

package main

// #include <stdlib.h>
// #include <sys/types.h>
// static void callLogger(void *func, int level, const char *msg)
// {
// 	((void(*)(int, const char *))func)(level, msg);
// }
import "C"

import (
	"bufio"
	"bytes"
	"errors"
	"git.zx2c4.com/wireguard-go/tun"
	"golang.org/x/sys/unix"
	"log"
	"math"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"unsafe"
)

var loggerFunc unsafe.Pointer
var versionString *C.char

type CLogger struct {
	level C.int
}

func (l *CLogger) Write(p []byte) (int, error) {
	if uintptr(loggerFunc) == 0 {
		return 0, errors.New("No logger initialized")
	}
	message := C.CString(string(p))
	C.callLogger(loggerFunc, l.level, message)
	C.free(unsafe.Pointer(message))
	return len(p), nil
}

var tunnelHandles map[int32]*Device

func init() {
	versionString = C.CString(WireGuardGoVersion)
	roamingDisabled = true
	tunnelHandles = make(map[int32]*Device)
	signals := make(chan os.Signal)
	signal.Notify(signals, unix.SIGUSR2)
	go func() {
		buf := make([]byte, os.Getpagesize())
		for {
			select {
			case <-signals:
				n := runtime.Stack(buf, true)
				buf[n] = 0
				if uintptr(loggerFunc) != 0 {
					C.callLogger(loggerFunc, 0, (*_Ctype_char)(unsafe.Pointer(&buf[0])))
				}
			}
		}
	}()
}

//export wgEnableRoaming
func wgEnableRoaming(enabled bool) {
	roamingDisabled = !enabled
}

//export wgSetLogger
func wgSetLogger(loggerFn uintptr) {
	loggerFunc = unsafe.Pointer(loggerFn)
}

//export wgTurnOn
func wgTurnOn(settings string, tunFd int32) int32 {
	logger := &Logger{
		Debug: log.New(&CLogger{level: 0}, "", 0),
		Info:  log.New(&CLogger{level: 1}, "", 0),
		Error: log.New(&CLogger{level: 2}, "", 0),
	}

	tun, _, err := tun.CreateTUNFromFD(int(tunFd))
	if err != nil {
		logger.Error.Println(err)
		return -1
	}
	logger.Info.Println("Attaching to interface")
	device := NewDevice(tun, logger)

	setError := ipcSetOperation(device, bufio.NewReader(strings.NewReader(settings)))
	if setError != nil {
		logger.Error.Println(setError)
		return -1
	}

	device.Up()
	logger.Info.Println("Device started")

	var i int32
	for i = 0; i < math.MaxInt32; i++ {
		if _, exists := tunnelHandles[i]; !exists {
			break
		}
	}
	if i == math.MaxInt32 {
		return -1
	}
	tunnelHandles[i] = device
	return i
}

//export wgTurnOff
func wgTurnOff(tunnelHandle int32) {
	device, ok := tunnelHandles[tunnelHandle]
	if !ok {
		return
	}
	delete(tunnelHandles, tunnelHandle)
	device.Close()
}

//export wgSetConfig
func wgSetConfig(tunnelHandle int32, settings string) int64 {
	device, ok := tunnelHandles[tunnelHandle]
	if !ok {
		return 0
	}
	err := ipcSetOperation(device, bufio.NewReader(strings.NewReader(settings)))
	if err != nil {
		device.log.Error.Println(err)
		return err.int64
	}
	return 0
}

//export wgGetConfig
func wgGetConfig(tunnelHandle int32) *C.char {
	device, ok := tunnelHandles[tunnelHandle]
	if !ok {
		return nil
	}
	settings := new(bytes.Buffer)
	writer := bufio.NewWriter(settings)
	err := ipcGetOperation(device, writer)
	if err != nil {
		return nil
	}
	writer.Flush()
	return C.CString(settings.String())
}

//export wgBindInterfaceScope
func wgBindInterfaceScope(tunnelHandle int32, ifscope int32) {
	var operr error
	device, ok := tunnelHandles[tunnelHandle]
	if !ok {
		return
	}
	device.log.Info.Printf("Binding sockets to interface %d\n", ifscope)
	bind := device.net.bind.(*NativeBind)
	for bind.ipv4 != nil {
		fd, err := bind.ipv4.SyscallConn()
		if err != nil {
			device.log.Error.Printf("Unable to bind v4 socket to interface:", err)
			break
		}
		err = fd.Control(func(fd uintptr) {
			operr = unix.SetsockoptInt(int(fd), unix.IPPROTO_IP, unix.IP_BOUND_IF, int(ifscope))
		})
		if err == nil {
			err = operr
		}
		if err != nil {
			device.log.Error.Printf("Unable to bind v4 socket to interface:", err)
		}
		break
	}
	for bind.ipv6 != nil {
		fd, err := bind.ipv6.SyscallConn()
		if err != nil {
			device.log.Error.Printf("Unable to bind v6 socket to interface:", err)
			break
		}
		err = fd.Control(func(fd uintptr) {
			operr = unix.SetsockoptInt(int(fd), unix.IPPROTO_IPV6, unix.IPV6_BOUND_IF, int(ifscope))
		})
		if err == nil {
			err = operr
		}
		if err != nil {
			device.log.Error.Printf("Unable to bind v6 socket to interface:", err)
		}
		break
	}
}

//export wgVersion
func wgVersion() *C.char {
	return versionString
}

func main() {}

/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
 */

package main

// #include <sys/types.h>
// static void callLogger(void *func, int level, const char *tag, const char *msg)
// {
// 	((void(*)(int, const char *, const char *))func)(level, tag, msg);
// }
import "C"

import (
	"bufio"
	"git.zx2c4.com/wireguard-go/tun"
	"golang.org/x/sys/unix"
	"io/ioutil"
	"log"
	"math"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"unsafe"
	"errors"
)

var loggerFunc unsafe.Pointer
var versionString *C.char

type CLogger struct {
	level         C.int
	interfaceName string
}

func (l *CLogger) Write(p []byte) (int, error) {
	if uintptr(loggerFunc) == 0 {
		return 0, errors.New("No logger initialized")
	}
	tag := C.CString("WireGuard/GoBackend/"+l.interfaceName)
	message := C.CString(string(p))
	C.callLogger(loggerFunc, l.level, tag, message)
	C.free(unsafe.Pointer(tag))
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
					tag := C.CString("WireGuard/GoBackend/Stacktrace")
					C.callLogger(loggerFunc, 0, tag, (*_Ctype_char)(unsafe.Pointer(&buf[0])))
					C.free(unsafe.Pointer(tag))
				}
			}
		}
	}()
}

//export wgSetLogger
func wgSetLogger(loggerFn uintptr) {
	loggerFunc = unsafe.Pointer(loggerFn)
}

//export wgTurnOn
func wgTurnOn(ifnameRef string, settings string, readFn uintptr, writeFn uintptr, ctx uintptr) int32 {
	interfaceName := string([]byte(ifnameRef))

	logger := &Logger{
		Debug: log.New(&CLogger{level: 0, interfaceName: interfaceName}, "", 0),
		Info:  log.New(&CLogger{level: 1, interfaceName: interfaceName}, "", 0),
		Error: log.New(&CLogger{level: 2, interfaceName: interfaceName}, "", 0),
	}

	logger.Debug.Println("Debug log enabled")

	tun := tun.CreateTUN(1280, unsafe.Pointer(readFn), unsafe.Pointer(writeFn), unsafe.Pointer(ctx))
	logger.Info.Println("Attaching to interface")
	device := NewDevice(tun, logger)

	logger.Debug.Println("Interface has MTU", device.tun.mtu)

	bufferedSettings := bufio.NewReadWriter(bufio.NewReader(strings.NewReader(settings)), bufio.NewWriter(ioutil.Discard))
	setError := ipcSetOperation(device, bufferedSettings)
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

//export wgVersion
func wgVersion() *C.char {
	return versionString
}

func main() {}

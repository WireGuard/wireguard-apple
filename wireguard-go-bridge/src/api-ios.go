/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
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
	"errors"
	"git.zx2c4.com/wireguard-go/tun"
	"golang.org/x/sys/unix"
	"io/ioutil"
	"log"
	"math"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"syscall"
	"time"
	"unsafe"
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
	message := C.CString(l.interfaceName + ": " + string(p))
	C.callLogger(loggerFunc, l.level, message)
	C.free(unsafe.Pointer(message))
	return len(p), nil
}

type DeviceState struct {
	device            *Device
	logger            *Logger
	endpointsTimer    *time.Timer
	endpointsSettings string
}

var tunnelHandles map[int32]*DeviceState

func listenForRouteChanges() {
	//TODO: replace with NWPathMonitor
	data := make([]byte, os.Getpagesize())
	routeSocket, err := unix.Socket(unix.AF_ROUTE, unix.SOCK_RAW, unix.AF_UNSPEC)
	if err != nil {
		return
	}
	for {
		n, err := unix.Read(routeSocket, data)
		if err != nil {
			if errno, ok := err.(syscall.Errno); ok && errno == syscall.EINTR {
				continue
			}
			return
		}

		if n < 4 {
			continue
		}
		for _, deviceState := range tunnelHandles {
			if deviceState.endpointsTimer == nil {
				deviceState.endpointsTimer = time.AfterFunc(time.Second, func() {
					deviceState.endpointsTimer = nil
					bufferedSettings := bufio.NewReadWriter(bufio.NewReader(strings.NewReader(deviceState.endpointsSettings)), bufio.NewWriter(ioutil.Discard))
					deviceState.logger.Info.Println("Setting endpoints for re-resolution due to network change")
					err := ipcSetOperation(deviceState.device, bufferedSettings)
					if err != nil {
						deviceState.logger.Error.Println(err)
					}
				})
			}
		}
	}
}

func init() {
	versionString = C.CString(WireGuardGoVersion)
	roamingDisabled = true
	tunnelHandles = make(map[int32]*DeviceState)
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
	go listenForRouteChanges()
}

//export wgSetLogger
func wgSetLogger(loggerFn uintptr) {
	loggerFunc = unsafe.Pointer(loggerFn)
}

func extractEndpointFromSettings(settings string) string {
	var b strings.Builder
	pubkey := ""
	endpoint := ""
	listenPort := "listen_port=0"
	for _, line := range strings.Split(settings, "\n") {
		if strings.HasPrefix(line, "listen_port=") {
			listenPort = line
		} else if strings.HasPrefix(line, "public_key=") {
			if pubkey != "" && endpoint != "" {
				b.WriteString(pubkey + "\n" + endpoint + "\n")
			}
			pubkey = line
		} else if strings.HasPrefix(line, "endpoint=") {
			endpoint = line
		} else if line == "remove=true" {
			pubkey = ""
			endpoint = ""
		}
	}
	if pubkey != "" && endpoint != "" {
		b.WriteString(pubkey + "\n" + endpoint + "\n")
	}
	return listenPort + "\n" + b.String()
}

//export wgTurnOn
func wgTurnOn(ifnameRef string, settings string, tunFd int32) int32 {
	interfaceName := string([]byte(ifnameRef))

	logger := &Logger{
		Debug: log.New(&CLogger{level: 0, interfaceName: interfaceName}, "", 0),
		Info:  log.New(&CLogger{level: 1, interfaceName: interfaceName}, "", 0),
		Error: log.New(&CLogger{level: 2, interfaceName: interfaceName}, "", 0),
	}

	logger.Debug.Println("Debug log enabled")

	tun, _, err := tun.CreateTUNFromFD(int(tunFd))
	if err != nil {
		logger.Error.Println(err)
		return -1
	}
	logger.Info.Println("Attaching to interface")
	device := NewDevice(tun, logger)

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
	tunnelHandles[i] = &DeviceState{
		device:            device,
		logger:            logger,
		endpointsSettings: extractEndpointFromSettings(settings),
	}
	return i
}

//export wgTurnOff
func wgTurnOff(tunnelHandle int32) {
	deviceState, ok := tunnelHandles[tunnelHandle]
	if !ok {
		return
	}
	delete(tunnelHandles, tunnelHandle)
	t := deviceState.endpointsTimer
	if t != nil {
		deviceState.endpointsTimer = nil
		t.Stop()
	}
	deviceState.device.Close()
}

//export wgVersion
func wgVersion() *C.char {
	return versionString
}

func main() {}

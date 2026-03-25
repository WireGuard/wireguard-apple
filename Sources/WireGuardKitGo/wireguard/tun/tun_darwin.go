/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2023 WireGuard LLC. All Rights Reserved.
 */

package tun

import (
	"errors"
	"fmt"
	"net"
	"os"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/net/ipv4"
	"golang.org/x/net/ipv6"
	"golang.org/x/sys/unix"
)

const utunControlName = "com.apple.net.utun_control"

func isIPv4OrIPv6FirstByte(b byte) bool {
	v := b >> 4
	return v == ipv4.Version || v == ipv6.Version
}

// isDarwinUtunPI4 reports whether the first 4 bytes look like Apple's utun packet
// information header (see NativeTun.Write: 0,0,0,AF_* or LE host order on arm64).
func isDarwinUtunPI4(b0, b1, b2, b3 byte) bool {
	if b0 == 0 && b1 == 0 && b2 == 0 && (b3 == unix.AF_INET || b3 == unix.AF_INET6) {
		return true
	}
	if (b0 == unix.AF_INET || b0 == unix.AF_INET6) && b1 == 0 && b2 == 0 && b3 == 0 {
		return true
	}
	return false
}

type NativeTun struct {
	name        string
	tunFile     *os.File
	events      chan Event
	errors      chan error
	routeSocket int
	closeOnce   sync.Once
}

func retryInterfaceByIndex(index int) (iface *net.Interface, err error) {
	for i := 0; i < 20; i++ {
		iface, err = net.InterfaceByIndex(index)
		if err != nil && errors.Is(err, syscall.ENOMEM) {
			time.Sleep(time.Duration(i) * time.Second / 3)
			continue
		}
		return iface, err
	}
	return nil, err
}

func (tun *NativeTun) routineRouteListener(tunIfindex int) {
	var (
		statusUp  bool
		statusMTU int
	)

	defer close(tun.events)

	data := make([]byte, os.Getpagesize())
	for {
	retry:
		n, err := unix.Read(tun.routeSocket, data)
		if err != nil {
			if errno, ok := err.(syscall.Errno); ok && errno == syscall.EINTR {
				goto retry
			}
			tun.errors <- err
			return
		}

		if n < 14 {
			continue
		}

		if data[3 /* type */] != unix.RTM_IFINFO {
			continue
		}
		ifindex := int(*(*uint16)(unsafe.Pointer(&data[12 /* ifindex */])))
		if ifindex != tunIfindex {
			continue
		}

		iface, err := retryInterfaceByIndex(ifindex)
		if err != nil {
			tun.errors <- err
			return
		}

		// Up / Down event
		up := (iface.Flags & net.FlagUp) != 0
		if up != statusUp && up {
			tun.events <- EventUp
		}
		if up != statusUp && !up {
			tun.events <- EventDown
		}
		statusUp = up

		// MTU changes
		if iface.MTU != statusMTU {
			tun.events <- EventMTUUpdate
		}
		statusMTU = iface.MTU
	}
}

func CreateTUN(name string, mtu int) (Device, error) {
	ifIndex := -1
	if name != "utun" {
		_, err := fmt.Sscanf(name, "utun%d", &ifIndex)
		if err != nil || ifIndex < 0 {
			return nil, fmt.Errorf("Interface name must be utun[0-9]*")
		}
	}

	fd, err := socketCloexec(unix.AF_SYSTEM, unix.SOCK_DGRAM, 2)
	if err != nil {
		return nil, err
	}

	ctlInfo := &unix.CtlInfo{}
	copy(ctlInfo.Name[:], []byte(utunControlName))
	err = unix.IoctlCtlInfo(fd, ctlInfo)
	if err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("IoctlGetCtlInfo: %w", err)
	}

	sc := &unix.SockaddrCtl{
		ID:   ctlInfo.Id,
		Unit: uint32(ifIndex) + 1,
	}

	err = unix.Connect(fd, sc)
	if err != nil {
		unix.Close(fd)
		return nil, err
	}

	err = unix.SetNonblock(fd, true)
	if err != nil {
		unix.Close(fd)
		return nil, err
	}
	tun, err := CreateTUNFromFile(os.NewFile(uintptr(fd), ""), mtu)

	if err == nil && name == "utun" {
		fname := os.Getenv("WG_TUN_NAME_FILE")
		if fname != "" {
			os.WriteFile(fname, []byte(tun.(*NativeTun).name+"\n"), 0o400)
		}
	}

	return tun, err
}

func CreateTUNFromFile(file *os.File, mtu int) (Device, error) {
	tun := &NativeTun{
		tunFile: file,
		events:  make(chan Event, 10),
		errors:  make(chan error, 5),
	}

	name, err := tun.Name()
	if err != nil {
		tun.tunFile.Close()
		return nil, err
	}

	tunIfindex, err := func() (int, error) {
		iface, err := net.InterfaceByName(name)
		if err != nil {
			return -1, err
		}
		return iface.Index, nil
	}()
	if err != nil {
		tun.tunFile.Close()
		return nil, err
	}

	tun.routeSocket, err = socketCloexec(unix.AF_ROUTE, unix.SOCK_RAW, unix.AF_UNSPEC)
	if err != nil {
		tun.tunFile.Close()
		return nil, err
	}

	go tun.routineRouteListener(tunIfindex)

	if mtu > 0 {
		err = tun.setMTU(mtu)
		if err != nil {
			tun.Close()
			return nil, err
		}
	}

	return tun, nil
}

func (tun *NativeTun) Name() (string, error) {
	var err error
	tun.operateOnFd(func(fd uintptr) {
		tun.name, err = unix.GetsockoptString(
			int(fd),
			2, /* #define SYSPROTO_CONTROL 2 */
			2, /* #define UTUN_OPT_IFNAME 2 */
		)
	})

	if err != nil {
		return "", fmt.Errorf("GetSockoptString: %w", err)
	}

	return tun.name, nil
}

func (tun *NativeTun) File() *os.File {
	return tun.tunFile
}

func (tun *NativeTun) Events() <-chan Event {
	return tun.events
}

func (tun *NativeTun) Read(buff []byte, offset int) (int, error) {
	select {
	case err := <-tun.errors:
		return 0, err
	default:
		buff := buff[offset-4:]
		n, err := tun.tunFile.Read(buff[:])
		readN := n
		if n < 4 {
			return 0, err
		}
		// wireguard-go's RoutineReadFromTUN sets elem.packet = buffer[offset:offset+size]
		// with offset=16, so the IP always starts at buff[4] in this slice. The kernel may
		// prepend a 4-byte PI header, an 8-byte PI (seen on some iOS / per-app paths), or
		// deliver raw IP starting at buff[0]. Mis-detecting the PI length makes buff[4] look
		// like a bogus "IP version" and triggers "Received packet with unknown IP version".

		// 1) Known 4-byte PI (e.g. 00 00 00 02 = AF_INET BE). IP normally follows at buff[4].
		// On some iOS paths the kernel still inserts padding after the PI; buff[4] is then not
		// an IP version byte — do not strip only 4 bytes (that produced ip_version_nibble=0).
		if isDarwinUtunPI4(buff[0], buff[1], buff[2], buff[3]) {
			if n >= 8 && isIPv4OrIPv6FirstByte(buff[4]) {
				return n - 4, err
			}
			// padded / extended framing — fall through
		}
		// 2) Raw IP at buff[0] (no PI): align payload to buff[4] for the device layer.
		if isIPv4OrIPv6FirstByte(buff[0]) {
			if n+4 > len(buff) {
				return 0, err
			}
			for i := n - 1; i >= 0; i-- {
				buff[4+i] = buff[i]
			}
			return n, err
		}
		// 3) Unknown 4-byte prefix but a normal IP header at buff[4] (common with non-canonical PI).
		if n >= 8 && isIPv4OrIPv6FirstByte(buff[4]) {
			return n - 4, err
		}
		// 4) Longer PI (e.g. 8 bytes): IP starts at buff[8].
		if n >= 12 && isIPv4OrIPv6FirstByte(buff[8]) {
			ipLen := n - 8
			if ipLen+4 > len(buff) {
				return 0, err
			}
			for i := 0; i < ipLen; i++ {
				buff[4+i] = buff[8+i]
			}
			return ipLen, err
		}
		// 4b) iOS may prepend additional zero padding after PI. Your logs show:
		// 00000002 + 16 bytes of zeros + 45..., meaning the IPv4 header starts at buff[20].
		if n >= 24 && isIPv4OrIPv6FirstByte(buff[20]) {
			ipLen := n - 20
			if ipLen+4 > len(buff) {
				return 0, err
			}
			for i := 0; i < ipLen; i++ {
				buff[4+i] = buff[20+i]
			}
			return ipLen, err
		}
		// 5) Legacy fallback (4-byte PI) — last resort.
		if os.Getenv("WG_TUN_DEBUG") == "1" {
			pl := readN
			if pl > 48 {
				pl = 48
			}
			_, _ = fmt.Fprintf(os.Stderr, "wireguard tun_darwin: fallback 4-byte PI strip read_len=%d first_bytes=%x\n", readN, buff[:pl])
		}
		return readN - 4, err
	}
}

func (tun *NativeTun) Write(buff []byte, offset int) (int, error) {
	// reserve space for header

	buff = buff[offset-4:]

	// add packet information header

	buff[0] = 0x00
	buff[1] = 0x00
	buff[2] = 0x00

	if buff[4]>>4 == ipv6.Version {
		buff[3] = unix.AF_INET6
	} else {
		buff[3] = unix.AF_INET
	}

	// write

	return tun.tunFile.Write(buff)
}

func (tun *NativeTun) Flush() error {
	// TODO: can flushing be implemented by buffering and using sendmmsg?
	return nil
}

func (tun *NativeTun) Close() error {
	var err1, err2 error
	tun.closeOnce.Do(func() {
		err1 = tun.tunFile.Close()
		if tun.routeSocket != -1 {
			unix.Shutdown(tun.routeSocket, unix.SHUT_RDWR)
			err2 = unix.Close(tun.routeSocket)
		} else if tun.events != nil {
			close(tun.events)
		}
	})
	if err1 != nil {
		return err1
	}
	return err2
}

func (tun *NativeTun) setMTU(n int) error {
	fd, err := socketCloexec(
		unix.AF_INET,
		unix.SOCK_DGRAM,
		0,
	)
	if err != nil {
		return err
	}

	defer unix.Close(fd)

	var ifr unix.IfreqMTU
	copy(ifr.Name[:], tun.name)
	ifr.MTU = int32(n)
	err = unix.IoctlSetIfreqMTU(fd, &ifr)
	if err != nil {
		return fmt.Errorf("failed to set MTU on %s: %w", tun.name, err)
	}

	return nil
}

func (tun *NativeTun) MTU() (int, error) {
	fd, err := socketCloexec(
		unix.AF_INET,
		unix.SOCK_DGRAM,
		0,
	)
	if err != nil {
		return 0, err
	}

	defer unix.Close(fd)

	ifr, err := unix.IoctlGetIfreqMTU(fd, tun.name)
	if err != nil {
		return 0, fmt.Errorf("failed to get MTU on %s: %w", tun.name, err)
	}

	return int(ifr.MTU), nil
}

func socketCloexec(family, sotype, proto int) (fd int, err error) {
	// See go/src/net/sys_cloexec.go for background.
	syscall.ForkLock.RLock()
	defer syscall.ForkLock.RUnlock()

	fd, err = unix.Socket(family, sotype, proto)
	if err == nil {
		unix.CloseOnExec(fd)
	}
	return
}

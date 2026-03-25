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

// tunDebugLevel: 0=off, 1=drop/unframed + context, 2=also log each successful framing path (very noisy).
func tunDebugLevel() int {
	switch os.Getenv("WG_TUN_DEBUG") {
	case "2", "verbose", "all":
		return 2
	case "1":
		return 1
	default:
		return 0
	}
}

func tunDebugLogSuccess(format string, args ...interface{}) {
	if tunDebugLevel() >= 2 {
		_, _ = fmt.Fprintf(os.Stderr, "wireguard tun_darwin: "+format, args...)
	}
}

func tunDebugLogDrop(format string, args ...interface{}) {
	if tunDebugLevel() >= 1 {
		_, _ = fmt.Fprintf(os.Stderr, "wireguard tun_darwin: "+format, args...)
	}
}

func getBuffOrZero(buff []byte, i int) byte {
	if i < len(buff) {
		return buff[i]
	}
	return 0
}

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

// maxUtunPrefixScan is how far we search for an IPv4/IPv6 header after a utun PI or padding.
const maxUtunPrefixScan = 128

// validatedIPv4PacketLen returns the IPv4 total length field if [i, n) contains a plausible IPv4 packet.
func validatedIPv4PacketLen(buff []byte, n, i int) (int, bool) {
	if i+20 > n {
		return 0, false
	}
	if buff[i]>>4 != ipv4.Version {
		return 0, false
	}
	ihl := int(buff[i]&0x0f) * 4
	if ihl < ipv4.HeaderLen || ihl > 60 {
		return 0, false
	}
	if i+ihl > n {
		return 0, false
	}
	totalLen := int(uint16(buff[i+2])<<8 | uint16(buff[i+3]))
	if totalLen < ihl || i+totalLen > n {
		return 0, false
	}
	return totalLen, true
}

// validatedIPv6PacketLen returns the IPv6 payload + 40 if [i, n) contains a plausible IPv6 packet.
func validatedIPv6PacketLen(buff []byte, n, i int) (int, bool) {
	if i+ipv6.HeaderLen > n {
		return 0, false
	}
	if buff[i]>>4 != ipv6.Version {
		return 0, false
	}
	plen := int(uint16(buff[i+4])<<8 | uint16(buff[i+5]))
	total := ipv6.HeaderLen + plen
	if total < ipv6.HeaderLen || i+total > n {
		return 0, false
	}
	return total, true
}

// scanAndAlignIPToBuff4 finds the first validated IPv4 or IPv6 datagram in buff[:n], copies it to
// buff[4:], and returns its length and start offset. Used when utun delivers PI + variable padding before the IP.
func scanAndAlignIPToBuff4(buff []byte, n int) (ipLen int, ipStart int, ok bool) {
	end := maxUtunPrefixScan
	if n < end {
		end = n
	}
	for i := 4; i < end; i++ {
		if totalLen, valid := validatedIPv4PacketLen(buff, n, i); valid {
			if 4+totalLen > len(buff) {
				return 0, -1, false
			}
			for j := 0; j < totalLen; j++ {
				buff[4+j] = buff[i+j]
			}
			return totalLen, i, true
		}
		if totalLen, valid := validatedIPv6PacketLen(buff, n, i); valid {
			if 4+totalLen > len(buff) {
				return 0, -1, false
			}
			for j := 0; j < totalLen; j++ {
				buff[4+j] = buff[i+j]
			}
			return totalLen, i, true
		}
	}
	return 0, -1, false
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
		// On some iOS paths the kernel inserts padding after the PI; buff[4] is then not an IP
		// version byte — never use "strip 4 bytes" alone (that yields ip_version_nibble=0 and
		// ip_len=readN-4, e.g. 76 for an 80-byte frame).
		if isDarwinUtunPI4(buff[0], buff[1], buff[2], buff[3]) {
			// Never use isIPv4OrIPv6FirstByte(buff[4]) && return n-4: 0x45 in padding or junk can
			// false-match; padding-only at buff[4] must not strip 4 bytes (gives ip_len=n-4, nibble 0).
			if ipLen, ipStart, ok := scanAndAlignIPToBuff4(buff, n); ok {
				tunDebugLogSuccess("read path=pi_scan readN=%d ip_len=%d ip_start=%d wg_offset=%d pi=%02x%02x%02x%02x b4=%02x\n",
					readN, ipLen, ipStart, offset, buff[0], buff[1], buff[2], buff[3], buff[4])
				return ipLen, err
			}
			// PI + IP immediately at buff[4] (no leading padding): use header length, not n-4 (kernel may pad past IP).
			if tl, ok := validatedIPv4PacketLen(buff, n, 4); ok {
				tunDebugLogSuccess("read path=pi_ipv4@4 readN=%d ip_len=%d wg_offset=%d\n", readN, tl, offset)
				return tl, err
			}
			if tl, ok := validatedIPv6PacketLen(buff, n, 4); ok {
				tunDebugLogSuccess("read path=pi_ipv6@4 readN=%d ip_len=%d wg_offset=%d\n", readN, tl, offset)
				return tl, err
			}
		}
		// 2) Raw IP at buff[0] (no PI): align payload to buff[4] for the device layer.
		if isIPv4OrIPv6FirstByte(buff[0]) {
			if n+4 > len(buff) {
				return 0, err
			}
			for i := n - 1; i >= 0; i-- {
				buff[4+i] = buff[i]
			}
			tunDebugLogSuccess("read path=raw_ip0 readN=%d out_len=%d wg_offset=%d\n", readN, n, offset)
			return n, err
		}
		// 3) Unknown 4-byte prefix but IP at buff[4]: strip PI using declared IP length only.
		if n >= 8 {
			if tl, ok := validatedIPv4PacketLen(buff, n, 4); ok {
				tunDebugLogSuccess("read path=prefixed_ipv4@4 readN=%d ip_len=%d wg_offset=%d\n", readN, tl, offset)
				return tl, err
			}
			if tl, ok := validatedIPv6PacketLen(buff, n, 4); ok {
				tunDebugLogSuccess("read path=prefixed_ipv6@4 readN=%d ip_len=%d wg_offset=%d\n", readN, tl, offset)
				return tl, err
			}
		}
		// 4) PI not recognized at buff[0:4]; scan for a validated IP header (padding / odd offsets).
		if ipLen, ipStart, ok := scanAndAlignIPToBuff4(buff, n); ok {
			tunDebugLogSuccess("read path=scan_no_pi readN=%d ip_len=%d ip_start=%d wg_offset=%d\n", readN, ipLen, ipStart, offset)
			return ipLen, err
		}
		pl := readN
		if pl > 96 {
			pl = 96
		}
		tunDebugLogDrop("could not frame IP: readN=%d wg_offset=%d pi4=%v first4=%02x%02x%02x%02x b4_b7=%02x%02x%02x%02x b20_23=%02x%02x%02x%02x prefix_hex=%x\n",
			readN, offset,
			isDarwinUtunPI4(buff[0], buff[1], buff[2], buff[3]),
			buff[0], buff[1], buff[2], buff[3],
			buff[4], buff[5], buff[6], buff[7],
			getBuffOrZero(buff, 20), getBuffOrZero(buff, 21), getBuffOrZero(buff, 22), getBuffOrZero(buff, 23),
			buff[:pl])
		return 0, nil
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

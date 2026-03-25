//go:build darwin

/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2017-2023 WireGuard LLC. All Rights Reserved.
 */

package tun

import (
	"errors"
	"fmt"
	"log"
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

// tunIngressLog is always-on stderr logging for utun framing (drops and NativeTun.Read failures).
// Device-layer ingress also logs via Logger.Infof in wireguard/device/send.go.
var tunIngressLog = log.New(os.Stderr, "wireguard/tun: ", log.LstdFlags|log.Lmicroseconds)

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

// processDarwinUtunBuff processes raw kernel bytes in buff[:n] (buff is the slice starting at buffer[offset-4]).
// On success, IPv4/IPv6 is aligned to buff[4] (device IP starts at buffer[offset]). readN is for logging only.
func processDarwinUtunBuff(buff []byte, n int, offset int, readN int) (outLen int, ok bool) {
	if n < 4 {
		return 0, false
	}
	// 1) Known 4-byte PI (e.g. 00 00 00 02 = AF_INET BE).
	if isDarwinUtunPI4(buff[0], buff[1], buff[2], buff[3]) {
		if ipLen, _, ok := scanAndAlignIPToBuff4(buff, n); ok {
			return ipLen, true
		}
		if tl, ok := validatedIPv4PacketLen(buff, n, 4); ok {
			return tl, true
		}
		if tl, ok := validatedIPv6PacketLen(buff, n, 4); ok {
			return tl, true
		}
	}
	// 2) Raw IP at buff[0] (no PI): align payload to buff[4] for the device layer.
	if isIPv4OrIPv6FirstByte(buff[0]) {
		if n+4 > len(buff) {
			return 0, false
		}
		for i := n - 1; i >= 0; i-- {
			buff[4+i] = buff[i]
		}
		return n, true
	}
	// 3) Unknown 4-byte prefix but IP at buff[4]: strip PI using declared IP length only.
	if n >= 8 {
		if tl, ok := validatedIPv4PacketLen(buff, n, 4); ok {
			return tl, true
		}
		if tl, ok := validatedIPv6PacketLen(buff, n, 4); ok {
			return tl, true
		}
	}
	// 4) PI not recognized at buff[0:4]; scan for a validated IP header (padding / odd offsets).
	if ipLen, _, ok := scanAndAlignIPToBuff4(buff, n); ok {
		return ipLen, true
	}
	pl := readN
	if pl > 128 {
		pl = 128
	}
	tunIngressLog.Printf(
		"could not frame IP: readN=%d wg_offset=%d pi4=%v first4=%02x%02x%02x%02x b4_b7=%02x%02x%02x%02x b20_23=%02x%02x%02x%02x prefix_hex=%x",
		readN, offset,
		isDarwinUtunPI4(buff[0], buff[1], buff[2], buff[3]),
		buff[0], buff[1], buff[2], buff[3],
		buff[4], buff[5], buff[6], buff[7],
		getBuffOrZero(buff, 20), getBuffOrZero(buff, 21), getBuffOrZero(buff, 22), getBuffOrZero(buff, 23),
		buff[:pl],
	)
	return 0, false
}

// DarwinFixMisframedIngress reapplies utun PI/padding/scan when NativeTun.Read returned a wrong length
// (typically size == kernelBytes-4) so elem.packet starts on padding. The kernel still wrote size+4 bytes
// into buffer[offset-4:]. Call from device.RoutineReadFromTUN when the first byte is not IPv4/IPv6.
func DarwinFixMisframedIngress(buffer []byte, offset int, size int) (newSize int, ok bool) {
	if offset < 4 {
		return 0, false
	}
	buff := buffer[offset-4:]
	maxN := len(buff)
	// Try several logical lengths: +4 (classic PI miscount), +20 (4-byte PI + 16-byte padding before IPv4),
	// then full slice. iOS per-app utun often delivers 00000002 + 16 zero bytes + IPv4; the device slice
	// may start on padding so size alone under-reports bytes needed for PI-path framing.
	attempts := []int{
		size + 4,
		size + 16,
		size + 20,
		size + 32,
		maxN,
	}
	seen := make(map[int]struct{})
	for _, n := range attempts {
		if n < 4 {
			continue
		}
		if n > maxN {
			n = maxN
		}
		if _, dup := seen[n]; dup {
			continue
		}
		seen[n] = struct{}{}
		if out, ok := processDarwinUtunBuff(buff, n, offset, n); ok {
			return out, true
		}
	}
	return 0, false
}

// DarwinReframePacketContent searches buffer[offset:offset+size] for the first validated IPv4 or IPv6
// datagram (e.g. leading padding then 0x45). Use when elem.packet starts on utun padding but the PI
// bytes are not present in buffer[offset-4:] (or PI-path framing failed). Copies the IP packet to
// buffer[offset:] so elem.packet[0] is the IP version nibble.
func DarwinReframePacketContent(buffer []byte, offset int, size int) (newSize int, ok bool) {
	if offset < 0 || size < 1 || offset+size > len(buffer) {
		return 0, false
	}
	pkt := buffer[offset : offset+size]
	end := maxUtunPrefixScan
	if len(pkt) < end {
		end = len(pkt)
	}
	for i := 0; i < end; i++ {
		if totalLen, ok := validatedIPv4PacketLen(pkt, len(pkt), i); ok {
			s := pkt[i : i+totalLen]
			tmp := make([]byte, totalLen)
			copy(tmp, s)
			copy(buffer[offset:], tmp)
			return totalLen, true
		}
		if totalLen, ok := validatedIPv6PacketLen(pkt, len(pkt), i); ok {
			s := pkt[i : i+totalLen]
			tmp := make([]byte, totalLen)
			copy(tmp, s)
			copy(buffer[offset:], tmp)
			return totalLen, true
		}
	}
	return 0, false
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

		outLen, ok := processDarwinUtunBuff(buff, n, offset, readN)
		if !ok {
			return 0, nil
		}
		return outLen, err
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

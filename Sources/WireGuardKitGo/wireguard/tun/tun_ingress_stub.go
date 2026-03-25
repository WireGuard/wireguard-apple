//go:build !darwin

package tun

// DarwinFixMisframedIngress is a no-op on non-Darwin platforms (utun is Apple-only).
func DarwinFixMisframedIngress(buffer []byte, offset int, size int) (newSize int, ok bool) {
	return 0, false
}

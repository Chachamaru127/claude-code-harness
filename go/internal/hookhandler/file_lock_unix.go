//go:build !windows

package hookhandler

import (
	"errors"
	"syscall"
)

const (
	fileLockExclusive = syscall.LOCK_EX
	fileLockNonblock  = syscall.LOCK_NB
	fileLockUnlock    = syscall.LOCK_UN
)

func fileLock(fd int, how int) error {
	return syscall.Flock(fd, how)
}

func fileLockBusy(err error) bool {
	return errors.Is(err, syscall.EWOULDBLOCK) || errors.Is(err, syscall.EAGAIN)
}

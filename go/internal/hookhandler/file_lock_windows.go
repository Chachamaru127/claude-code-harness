//go:build windows

package hookhandler

import "errors"

const (
	fileLockExclusive = 1 << iota
	fileLockNonblock
	fileLockUnlock
)

var errFileLockUnsupported = errors.New("file lock unsupported on windows")

func fileLock(_ int, _ int) error {
	return errFileLockUnsupported
}

func fileLockBusy(_ error) bool {
	return false
}

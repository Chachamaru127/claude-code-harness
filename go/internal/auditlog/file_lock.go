package auditlog

import "os"

// WithFileLock runs fn while holding an exclusive OS lock on lockPath.
// It returns without running fn when the lock file cannot be opened or locked.
func WithFileLock(lockPath string, fn func() error) error {
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()

	if err := fileLock(lock); err != nil {
		return err
	}
	defer func() {
		_ = fileUnlock(lock)
	}()

	return fn()
}

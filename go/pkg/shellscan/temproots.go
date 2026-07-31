package shellscan

import (
	"os"
	"path/filepath"
	"strings"
)

// IsAllowlistedTempPath reports whether path is inside an OS-managed scratch
// root. Callers that accept user-controlled paths must resolve symlinks before
// calling this function. Allowlisted roots are compared in both their original
// and symlink-resolved forms.
func IsAllowlistedTempPath(path string) bool {
	cleanPath := filepath.Clean(path)
	for _, root := range allowlistedTempRoots() {
		cleanRoot := filepath.Clean(root)
		if cleanPath == cleanRoot ||
			strings.HasPrefix(cleanPath, cleanRoot+string(filepath.Separator)) {
			return true
		}
	}
	return false
}

func allowlistedTempRoots() []string {
	roots := []string{
		"/tmp",
		"/var/tmp",
		"/private/tmp",
		"/private/var/tmp",
	}
	if tempDir := strings.TrimSpace(os.Getenv("TMPDIR")); tempDir != "" {
		if abs, err := filepath.Abs(tempDir); err == nil {
			roots = append(roots, filepath.Clean(abs))
		} else {
			roots = append(roots, filepath.Clean(tempDir))
		}
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		roots = append(roots, filepath.Join(home, ".cache"))
		roots = append(roots, filepath.Join(home, "Library", "Caches"))
	}

	resolvedRoots := make([]string, 0, len(roots)*2)
	for _, root := range roots {
		cleanRoot := filepath.Clean(root)
		resolvedRoots = append(resolvedRoots, cleanRoot)
		if resolvedRoot, err := filepath.EvalSymlinks(cleanRoot); err == nil {
			resolvedRoots = append(resolvedRoots, filepath.Clean(resolvedRoot))
		}
	}
	return resolvedRoots
}

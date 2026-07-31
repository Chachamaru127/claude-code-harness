package shellscan

import (
	"reflect"
	"strings"
	"testing"
)

func TestDangerousRemoval_UnifiedCorpus(t *testing.T) {
	cases := []struct {
		name      string
		command   string
		dangerous bool
		targets   []string
	}{
		{name: "short recursive", command: "rm -r /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "short uppercase recursive", command: "rm -R /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "combined rf", command: "rm -rf /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "combined fr", command: "rm -fr /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "separate short flags", command: "rm -r -f /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "long recursive force", command: "rm --recursive --force /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "long force recursive", command: "rm --force --recursive /outside", dangerous: true, targets: []string{"/outside"}},
		{name: "find delete", command: "find /outside -name '*.tmp' -delete", dangerous: true, targets: []string{"/outside"}},
		{name: "find option before path", command: "find -H /outside -delete", dangerous: true, targets: []string{"/outside"}},
		{name: "bsd find regex option before path", command: "find -E /outside -delete", dangerous: true, targets: []string{"/outside"}},
		{name: "bsd find combined options before path", command: "find -EXdsx /outside -delete", dangerous: true, targets: []string{"/outside"}},
		{name: "bsd find combined symlink option before path", command: "find -EL /outside -delete", dangerous: true, targets: []string{"/outside"}},
		{name: "bsd find file root", command: "find -f /outside . -delete", dangerous: true, targets: []string{"/outside", "."}},
		{name: "bsd find attached file root", command: "find -f/outside . -delete", dangerous: true, targets: []string{"/outside", "."}},
		{name: "bsd find combined attached file root", command: "find -Ef/outside . -delete", dangerous: true, targets: []string{"/outside", "."}},
		{name: "bsd find combined separate file root", command: "find -Ef /outside . -delete", dangerous: true, targets: []string{"/outside", "."}},
		{name: "find exec rm", command: `find /outside -type f -exec rm -rf {} \;`, dangerous: true, targets: []string{"/outside"}},
		{name: "macOS system path without recursion", command: "rm -f /System/Library/test", dangerous: true, targets: []string{"/System/Library/test"}},
		{name: "macOS user library without recursion", command: "rm -f ~/Library/Messages", dangerous: true, targets: []string{"~/Library/Messages"}},
		{name: "shell command string", command: "bash -c 'rm -rf /outside'", dangerous: true, targets: []string{"/outside"}},
		{name: "command substitution", command: "echo $(rm -rf /outside)", dangerous: true, targets: []string{"/outside"}},
		{name: "force only", command: "rm -f /ordinary", dangerous: false},
		{name: "end of options recursive-looking target", command: "rm -- -r", dangerous: false},
		{name: "find print", command: "find /outside -name '*.tmp' -print", dangerous: false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dangerous, targets := DangerousRemoval(tc.command)
			if dangerous != tc.dangerous {
				t.Fatalf("DangerousRemoval(%q).dangerous = %v, want %v",
					tc.command, dangerous, tc.dangerous)
			}
			if !reflect.DeepEqual(targets, tc.targets) {
				t.Fatalf("DangerousRemoval(%q).targets = %#v, want %#v",
					tc.command, targets, tc.targets)
			}
		})
	}
}

func TestDangerousRemoval_TargetsStayWithinCommandSegment(t *testing.T) {
	cases := []struct {
		name    string
		command string
		targets []string
	}{
		{
			name:    "leading command",
			command: "cd /tmp && rm -rf ./build",
			targets: []string{"./build"},
		},
		{
			name:    "trailing command",
			command: "rm -rf /worktree/build && printf /",
			targets: []string{"/worktree/build"},
		},
		{
			name:    "semicolon",
			command: "printf / ; rm -rf /worktree/build",
			targets: []string{"/worktree/build"},
		},
		{
			name:    "or operator",
			command: "rm -rf /worktree/build || printf /",
			targets: []string{"/worktree/build"},
		},
		{
			name:    "pipeline",
			command: "rm -rf /worktree/build | tee /outside/log",
			targets: []string{"/worktree/build"},
		},
		{
			name:    "newline",
			command: "rm -rf /worktree/build\nprintf /",
			targets: []string{"/worktree/build"},
		},
		{
			name:    "escaped newline continues command",
			command: "rm -rf \\\n/outside",
			targets: []string{"/outside"},
		},
		{
			name:    "end of options",
			command: "rm -r -- -target",
			targets: []string{"-target"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dangerous, targets := DangerousRemoval(tc.command)
			if !dangerous {
				t.Fatalf("DangerousRemoval(%q).dangerous = false, want true", tc.command)
			}
			if !reflect.DeepEqual(targets, tc.targets) {
				t.Fatalf("DangerousRemoval(%q).targets = %#v, want %#v",
					tc.command, targets, tc.targets)
			}
		})
	}
}

func TestRemovalContextIndeterminate(t *testing.T) {
	cases := []struct {
		name          string
		command       string
		targets       []string
		indeterminate bool
	}{
		{
			name:          "static relative removal",
			command:       "rm -rf ./build",
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "directory change before relative removal",
			command:       "c'd' /tmp && rm -rf ./build",
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "preceding directory change before absolute removal",
			command:       "cd /tmp && rm -rf /worktree/build",
			targets:       []string{"/worktree/build"},
			indeterminate: true,
		},
		{
			name:          "interpreter directory change before relative removal",
			command:       `python -c "import os; os.chdir('/tmp'); os.system('rm -rf ./build')"`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "interpreter subprocess cwd",
			command:       `python -c "import subprocess; subprocess.run('rm -rf ./build', shell=True, cwd='/tmp')"`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "interpreter behind env options",
			command:       `env -u PYTHONPATH python -c "import subprocess; subprocess.run('rm -rf ./build', shell=True, cwd='/tmp')"`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "version suffixed interpreter",
			command:       `python3.12 -c "import subprocess; subprocess.run('rm -rf ./build', shell=True, cwd='/tmp')"`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "interpreter behind arbitrary launcher",
			command:       `timeout 10 python -c "import subprocess; subprocess.run('rm -rf ./build', shell=True, cwd='/tmp')"`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "preceding segment can replace missing ancestor with symlink",
			command:       `ln -sfn /outside ./r05-link && rm -rf ./r05-link/victim`,
			targets:       []string{"./r05-link/victim"},
			indeterminate: true,
		},
		{
			name:          "preceding segment also blocks absolute target proof",
			command:       `ln -sfn /outside /worktree/r05-link && rm -rf /worktree/r05-link/victim`,
			targets:       []string{"/worktree/r05-link/victim"},
			indeterminate: true,
		},
		{
			name:          "arbitrary launcher before direct rm",
			command:       `timeout 10 rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "external executable named rm",
			command:       `/private/tmp/rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "external executable named find",
			command:       `/private/tmp/find . -delete`,
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "path override before rm",
			command:       `PATH=/private/tmp/evil-bin rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "path append before rm",
			command:       `PATH+=:/private/tmp/evil-bin rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "env path override before rm",
			command:       `env PATH=/private/tmp/evil-bin rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "loader override before rm",
			command:       `LD_PRELOAD=/private/tmp/evil.so rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "path override in preceding assignment segment",
			command:       `PATH=/private/tmp/evil-bin; rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "background removal races trailing path mutation",
			command:       `rm -rf ./r05-link/victim & ln -sfn /outside ./r05-link`,
			targets:       []string{"./r05-link/victim"},
			indeterminate: true,
		},
		{
			name:          "pipeline segments execute concurrently",
			command:       `rm -rf ./build | printf done`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "process substitution executes concurrently",
			command:       `rm -rf ./r05-link/victim < <(ln -sfn /outside ./r05-link)`,
			targets:       []string{"./r05-link/victim"},
			indeterminate: true,
		},
		{
			name:          "trailing segment cannot change earlier removal resolution",
			command:       `rm -rf ./build && printf done`,
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "combined output redirection is not a background operator",
			command:       `rm -rf ./build &> /tmp/r05.log`,
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "fd duplication is not a background operator",
			command:       `rm -rf ./build 2>&1`,
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "fd close is not a background operator",
			command:       `rm -rf ./build 2>&-`,
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "stdout fd duplication is not a background operator",
			command:       `rm -rf ./build >&2`,
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "stdin fd duplication is not a background operator",
			command:       `rm -rf ./build <&0`,
			targets:       []string{"./build"},
			indeterminate: false,
		},
		{
			name:          "quoted ampersand is not a background operator",
			command:       `rm -rf './a&b'`,
			targets:       []string{"./a&b"},
			indeterminate: false,
		},
		{
			name:          "multiple direct removals have no path creating segment",
			command:       `rm -rf ./build && rm -rf ./dist`,
			targets:       []string{"./build", "./dist"},
			indeterminate: false,
		},
		{
			name:          "interpreter name is only a direct rm target",
			command:       "rm -rf ./python",
			targets:       []string{"./python"},
			indeterminate: false,
		},
		{
			name:          "argument producer",
			command:       "printf /outside | x'args' rm -rf ./build",
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "find follows symlinks",
			command:       "f'ind' -L . -delete",
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "bsd combined find option follows symlinks",
			command:       "find -EL . -delete",
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "bsd combined file root option follows symlinks",
			command:       "find -Lf/outside . -delete",
			targets:       []string{"/outside", "."},
			indeterminate: true,
		},
		{
			name:          "find follows symlinks after line continuation",
			command:       "find -L\\\n . -delete",
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "default find",
			command:       "find . -delete",
			targets:       []string{"."},
			indeterminate: false,
		},
		{
			name:          "find exec bare rm",
			command:       `find . -maxdepth 0 -exec rm -rf ./build \;`,
			targets:       []string{".", "./build"},
			indeterminate: false,
		},
		{
			name:          "find exec external rm",
			command:       `find . -maxdepth 0 -exec /private/tmp/rm -rf ./build \;`,
			targets:       []string{".", "./build"},
			indeterminate: true,
		},
		{
			name:          "find exec path override",
			command:       `find . -maxdepth 0 -exec env PATH=/private/tmp/evil-bin rm -rf ./build \;`,
			targets:       []string{".", "./build"},
			indeterminate: true,
		},
		{
			name:          "find delete with arbitrary exec action",
			command:       `find . -maxdepth 0 -exec /private/tmp/evil \; -delete`,
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "find exec nested find removal",
			command:       `find . -maxdepth 0 -exec find /outside -delete \;`,
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "dynamic command wrapper",
			command:       `"$RUNNER" rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "dynamic find option",
			command:       `find "-$FOLLOW" . -delete`,
			targets:       []string{"."},
			indeterminate: true,
		},
		{
			name:          "dynamic argument producer command",
			command:       `producer=xargs; printf /outside | "$producer" rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "ansi-c quoted argument producer",
			command:       `printf /outside | $'xargs' rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "dynamic directory changer",
			command:       `changer=cd; "$changer" /tmp && rm -rf ./build`,
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "backtick target substitution",
			command:       "rm -rf ./build `printf /outside`",
			targets:       []string{"./build"},
			indeterminate: true,
		},
		{
			name:          "find roots from file",
			command:       "find -files0-from /tmp/removal-targets -delete",
			targets:       []string{"."},
			indeterminate: true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := RemovalContextIndeterminate(tc.command, tc.targets); got != tc.indeterminate {
				t.Fatalf("RemovalContextIndeterminate(%q, %#v) = %v, want %v",
					tc.command, tc.targets, got, tc.indeterminate)
			}
		})
	}
}

func TestStripNonExecutableText_RemovesDocumentHeredocAndComments(t *testing.T) {
	command := "cat >> notes.md <<'EOF'\n" +
		"rm -rf /\n" +
		"cat /project/.env\n" +
		"EOF\n" +
		"printf done # rm -rf /opt/data"

	scannable := StripNonExecutableText(command)
	for _, removed := range []string{"rm -rf /", "cat /project/.env", "rm -rf /opt/data"} {
		if strings.Contains(scannable, removed) {
			t.Fatalf("StripNonExecutableText retained non-executable text %q in %q", removed, scannable)
		}
	}
	if !strings.Contains(scannable, "cat >> notes.md") || !strings.Contains(scannable, "printf done") {
		t.Fatalf("StripNonExecutableText removed executable opener/command: %q", scannable)
	}
}

func TestStripNonExecutableText_KeepsInterpreterHeredocBodies(t *testing.T) {
	interpreters := []string{
		"bash",
		"sh",
		"zsh",
		"dash",
		"ksh",
		"python",
		"python3",
		"perl",
		"ruby",
		"node",
	}

	for _, interpreter := range interpreters {
		t.Run(interpreter, func(t *testing.T) {
			command := interpreter + " <<EOF\nEXECUTABLE_BODY_MARKER\nEOF"
			scannable := StripNonExecutableText(command)
			if !strings.Contains(scannable, "EXECUTABLE_BODY_MARKER") {
				t.Fatalf("%s heredoc body was removed: %q", interpreter, scannable)
			}
		})
	}
}

func TestStripNonExecutableText_KeepsBodyPipedToInterpreter(t *testing.T) {
	command := "cat <<EOF | bash\nrm -rf /outside\nEOF"
	scannable := StripNonExecutableText(command)
	if !strings.Contains(scannable, "rm -rf /outside") {
		t.Fatalf("body piped to bash was removed: %q", scannable)
	}
}

func TestStripNonExecutableText_QuotedHeredocMarkerDoesNotHideCommands(t *testing.T) {
	for _, command := range []string{
		"printf '<<EOF'\nrm -rf /outside",
		"printf \"<<EOF\"\nrm -rf /outside",
	} {
		t.Run(command, func(t *testing.T) {
			scannable := StripNonExecutableText(command)
			if !strings.Contains(scannable, "rm -rf /outside") {
				t.Fatalf("quoted heredoc marker hid executable command: %q", scannable)
			}
		})
	}
}

package hookhandler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"
	"testing"
)

// TestConflictFeedback_DenyOnHeld verifies the core Phase 85.1.5 contract:
// when a peer session already holds the lease for the file the current
// session just wrote, PostToolUseFileLease emits a deny+continueOnBlock
// response carrying the holder's identity and the repo-relative path. The
// holder identifier is intentionally truncated so a long session id never
// floods the model's context.
func TestConflictFeedback_DenyOnHeld(t *testing.T) {
	cfgA, repoRoot := newLeaseCfg(t, "session-A")

	if res, err := AcquireLease("go/foo.go", cfgA); err != nil || res.Status != StatusAcquired {
		t.Fatalf("setup acquire: status=%v err=%v", res.Status, err)
	}

	absPath := filepath.Join(repoRoot, "go/foo.go")
	payload, err := json.Marshal(map[string]any{
		"session_id": "session-B",
		"cwd":        repoRoot,
		"tool_name":  "Write",
		"tool_input": map[string]any{"file_path": absPath},
	})
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	out := &bytes.Buffer{}
	if err := HandlePostToolUseFileLease(bytes.NewReader(payload), out); err != nil {
		t.Fatalf("handler error: %v", err)
	}

	body := out.String()
	for _, want := range []string{
		`"permissionDecision":"deny"`,
		`"continueOnBlock":true`,
		`"hookEventName":"PostToolUse"`,
		// 8-char prefix of "session-A" is "session-"
		"session-",
		"go/foo.go",
	} {
		if !strings.Contains(body, want) {
			t.Errorf("response missing %q\nfull body: %s", want, body)
		}
	}
}

// TestConflictFeedback_FailOpenOnUnavailable verifies that when the lease
// store cannot be resolved (cwd outside any git repo), the handler stays
// silent so the tool result is not blocked. fail-open is required by Phase
// 85.1.5 (b): "lease 機構不達時は fail-open(allow、警告なし)".
func TestConflictFeedback_FailOpenOnUnavailable(t *testing.T) {
	// t.TempDir() is not inside a git repo (no .git ancestor in $TMPDIR
	// under sandbox-allowed paths). leaseHookRepoFromCWD will walk up and
	// return false, so the handler must emit nothing.
	dir := t.TempDir()
	absPath := filepath.Join(dir, "foo.go")
	payload, err := json.Marshal(map[string]any{
		"session_id": "session-X",
		"cwd":        dir,
		"tool_name":  "Write",
		"tool_input": map[string]any{"file_path": absPath},
	})
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	out := &bytes.Buffer{}
	if err := HandlePostToolUseFileLease(bytes.NewReader(payload), out); err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected silent allow (empty body), got: %q", out.String())
	}
}

// TestConflictFeedback_AllowOnSelfHeld covers the inverse of DenyOnHeld:
// when the current session is the lease holder (PreToolUse already
// acquired), PostToolUse must stay silent. Otherwise a self-write would
// loop forever as the model retries on its own continueOnBlock feedback.
func TestConflictFeedback_AllowOnSelfHeld(t *testing.T) {
	cfg, repoRoot := newLeaseCfg(t, "session-self")
	if res, err := AcquireLease("go/bar.go", cfg); err != nil || res.Status != StatusAcquired {
		t.Fatalf("setup acquire: status=%v err=%v", res.Status, err)
	}
	absPath := filepath.Join(repoRoot, "go/bar.go")
	payload, _ := json.Marshal(map[string]any{
		"session_id": "session-self",
		"cwd":        repoRoot,
		"tool_name":  "Edit",
		"tool_input": map[string]any{"file_path": absPath},
	})
	out := &bytes.Buffer{}
	if err := HandlePostToolUseFileLease(bytes.NewReader(payload), out); err != nil {
		t.Fatalf("handler: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("self-held should be silent, got: %s", out.String())
	}
}

// TestPreToolUseFileLease_SilentAcquire covers Phase 85.1.5 (d): PreToolUse
// must silently acquire and never emit a decision body. Verified by
// checking that the on-disk lease store now records the caller as holder.
func TestPreToolUseFileLease_SilentAcquire(t *testing.T) {
	_, repoRoot := newLeaseCfg(t, "ignored-config")
	absPath := filepath.Join(repoRoot, "go/baz.go")
	payload, _ := json.Marshal(map[string]any{
		"session_id": "session-pre",
		"cwd":        repoRoot,
		"tool_name":  "Write",
		"tool_input": map[string]any{"file_path": absPath},
	})
	out := &bytes.Buffer{}
	if err := HandlePreToolUseFileLease(bytes.NewReader(payload), out); err != nil {
		t.Fatalf("handler: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("PreToolUse should be silent, got: %s", out.String())
	}

	// The lease store should now show session-pre as the holder. Reuse the
	// peer's perspective (CheckLease from a different session) to confirm.
	peerCfg, _ := newLeaseCfg(t, "peer")
	// Override RepoRoot/GitCommonDir to point at the same store as the
	// PreToolUse handler (it walked up from absPath).
	peerCfg.RepoRoot = repoRoot
	peerCfg.GitCommonDir = filepath.Join(repoRoot, ".git")
	res := CheckLease("go/baz.go", peerCfg)
	if res.Status != StatusHeldByOther {
		t.Fatalf("PreToolUse did not acquire: status=%v", res.Status)
	}
	if res.Holder == nil || res.Holder.SessionID != "session-pre" {
		t.Fatalf("holder mismatch: %+v", res.Holder)
	}
}

// TestFileLease_PathTraversalIsRejected proves the containment check: a
// file_path that escapes the repo via .. produces no output (silent allow)
// and never reaches the lease layer. Defense-in-depth: leaseKey already
// uses sha256 so the on-disk key is safe, but we still refuse to record a
// lease for an off-repo path.
func TestFileLease_PathTraversalIsRejected(t *testing.T) {
	_, repoRoot := newLeaseCfg(t, "session-trav")
	escaped := filepath.Join(repoRoot, "..", "outside.go")
	payload, _ := json.Marshal(map[string]any{
		"session_id": "session-trav",
		"cwd":        repoRoot,
		"tool_name":  "Write",
		"tool_input": map[string]any{"file_path": escaped},
	})

	// PreToolUse: silent
	out := &bytes.Buffer{}
	if err := HandlePreToolUseFileLease(bytes.NewReader(payload), out); err != nil {
		t.Fatalf("pre handler: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("traversal pre should be silent: %s", out.String())
	}
	// PostToolUse: silent too (no lease record exists for an off-repo path)
	out.Reset()
	if err := HandlePostToolUseFileLease(bytes.NewReader(payload), out); err != nil {
		t.Fatalf("post handler: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("traversal post should be silent: %s", out.String())
	}
}

// TestFileLease_MissingSessionIDIsSilent guards against a malformed hook
// payload (e.g. cosmic ray, partial parser bug). Handler must not panic
// and must not emit a decision.
func TestFileLease_MissingSessionIDIsSilent(t *testing.T) {
	_, repoRoot := newLeaseCfg(t, "irrelevant")
	absPath := filepath.Join(repoRoot, "foo.go")
	payload := fmt.Sprintf(`{"cwd":%q,"tool_name":"Write","tool_input":{"file_path":%q}}`, repoRoot, absPath)
	out := &bytes.Buffer{}
	if err := HandlePostToolUseFileLease(strings.NewReader(payload), out); err != nil {
		t.Fatalf("handler: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("missing session_id should be silent: %s", out.String())
	}
}

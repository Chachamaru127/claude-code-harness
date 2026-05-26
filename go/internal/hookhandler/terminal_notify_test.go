package hookhandler

import (
	"strings"
	"testing"
)

func TestBuildTerminalSequence_Unset(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "")
	if got := BuildTerminalSequence("title", "body"); got != "" {
		t.Errorf("unset env should return empty, got %q", got)
	}
}

func TestBuildTerminalSequence_Zero(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "0")
	if got := BuildTerminalSequence("title", "body"); got != "" {
		t.Errorf("HARNESS_TERMINAL_NOTIFY=0 should return empty, got %q", got)
	}
}

func TestBuildTerminalSequence_Bell(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "bell")
	got := BuildTerminalSequence("title", "body")
	if got != "\x07" {
		t.Errorf("bell mode should return BEL (\\x07), got %q", got)
	}
}

func TestBuildTerminalSequence_BellEmptyTitle(t *testing.T) {
	// bell mode does not require a title → contract: BEL is emitted even when title is empty
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "bell")
	got := BuildTerminalSequence("", "")
	if got != "\x07" {
		t.Errorf("bell mode with empty title should still emit BEL, got %q", got)
	}
}

func TestBuildTerminalSequence_OSC9(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")
	got := BuildTerminalSequence("Build complete", "ignored")
	expected := "\x1b]9;Build complete\x07"
	if got != expected {
		t.Errorf("osc9 mode mismatch:\n  got:    %q\n  expect: %q", got, expected)
	}
}

func TestBuildTerminalSequence_OSC9EmptyTitle(t *testing.T) {
	// osc9 requires a title → silent when title is empty
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")
	if got := BuildTerminalSequence("", "body"); got != "" {
		t.Errorf("osc9 with empty title should return empty, got %q", got)
	}
}

func TestBuildTerminalSequence_Title(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "title")
	got := BuildTerminalSequence("My Session", "")
	expected := "\x1b]0;My Session\x07"
	if got != expected {
		t.Errorf("title mode mismatch:\n  got:    %q\n  expect: %q", got, expected)
	}
}

func TestBuildTerminalSequence_NotifyWithBody(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "notify")
	got := BuildTerminalSequence("Build complete", "all tests pass")
	expected := "\x1b]777;notify;Build complete;all tests pass\x07"
	if got != expected {
		t.Errorf("notify (with body) mismatch:\n  got:    %q\n  expect: %q", got, expected)
	}
}

func TestBuildTerminalSequence_NotifyNoBody(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "notify")
	got := BuildTerminalSequence("Build complete", "")
	expected := "\x1b]777;notify;Build complete\x07"
	if got != expected {
		t.Errorf("notify (no body) mismatch:\n  got:    %q\n  expect: %q", got, expected)
	}
}

func TestBuildTerminalSequence_UnknownMode(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "potato")
	if got := BuildTerminalSequence("title", "body"); got != "" {
		t.Errorf("unknown mode should silently return empty, got %q", got)
	}
}

func TestBuildTerminalSequence_AliasOne(t *testing.T) {
	// "1" is an alias for bell
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "1")
	got := BuildTerminalSequence("", "")
	if got != "\x07" {
		t.Errorf("alias '1' should emit BEL, got %q", got)
	}
}

func TestBuildTerminalSequence_ControlCharsStripped(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")
	// A title containing control characters (\n, ESC, BEL, NUL) is sanitized
	dirty := "bad\ntitle\x1b\x07evil\x00here"
	got := BuildTerminalSequence(dirty, "")
	// expect "badtitleevilhere" cleaned
	expected := "\x1b]9;badtitleevilhere\x07"
	if got != expected {
		t.Errorf("control char sanitization failed:\n  got:    %q\n  expect: %q", got, expected)
	}
	// Verify that no control characters leaked into the output
	if strings.ContainsAny(got[3:len(got)-1], "\x00\x01\x02\x03\x04\x05\x06\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1c\x1d\x1e\x1f\x7f") {
		t.Errorf("control chars leaked into output: %q", got)
	}
}

func TestBuildTerminalSequence_NonASCIIPreserved(t *testing.T) {
	// Printable non-ASCII characters (Japanese, etc.) are preserved
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")
	got := BuildTerminalSequence("ビルド完了", "")
	expected := "\x1b]9;ビルド完了\x07"
	if got != expected {
		t.Errorf("non-ASCII preservation failed:\n  got:    %q\n  expect: %q", got, expected)
	}
}

func TestAugmentWithTerminalSequence_Adds(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")
	resp := map[string]interface{}{"decision": "approve"}
	AugmentWithTerminalSequence(resp, "Build", "")
	if seq, ok := resp["terminalSequence"]; !ok {
		t.Errorf("expected terminalSequence in response, got %+v", resp)
	} else if seq != "\x1b]9;Build\x07" {
		t.Errorf("unexpected terminalSequence value: %q", seq)
	}
}

func TestAugmentWithTerminalSequence_NoEnv(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "")
	resp := map[string]interface{}{"decision": "approve"}
	AugmentWithTerminalSequence(resp, "Build", "")
	if _, ok := resp["terminalSequence"]; ok {
		t.Errorf("env unset should NOT add terminalSequence, got %+v", resp)
	}
}

func TestAugmentWithTerminalSequence_NilMap(t *testing.T) {
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")
	// nil でも panic しないこと
	AugmentWithTerminalSequence(nil, "Build", "")
}

func TestResolveTerminalNotifyMode_Whitespace(t *testing.T) {
	// Leading/trailing whitespace and case differences are tolerated
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "  OSC9  ")
	if got := resolveTerminalNotifyMode(); got != notifyOSC9 {
		t.Errorf("whitespace/case tolerance failed, got mode %d", got)
	}
}

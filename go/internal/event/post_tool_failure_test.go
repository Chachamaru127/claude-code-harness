package event

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestPostToolFailureHandler_EmptyInput(t *testing.T) {
	dir := t.TempDir()
	h := &PostToolFailureHandler{StateDir: dir}

	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(""), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Even with empty output, should be valid JSON
	if buf.Len() == 0 {
		t.Error("expected some output")
	}
}

func TestPostToolFailureHandler_FirstFailure(t *testing.T) {
	dir := t.TempDir()
	h := &PostToolFailureHandler{StateDir: dir}

	input := `{"tool_name":"Bash","error":"command not found"}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp SystemMessageResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !strings.Contains(resp.SystemMessage, "failure #1/3") {
		t.Errorf("expected failure #1/3 message, got: %s", resp.SystemMessage)
	}
	if !strings.Contains(resp.SystemMessage, "Bash") {
		t.Errorf("expected tool name in message, got: %s", resp.SystemMessage)
	}
}

func TestPostToolFailureHandler_SecondFailure(t *testing.T) {
	dir := t.TempDir()
	now := time.Now()
	h := &PostToolFailureHandler{
		StateDir: dir,
		nowFunc:  func() time.Time { return now },
	}

	input := `{"tool_name":"Read","error":"file not found"}`

	var buf bytes.Buffer
	// 1st call
	_ = h.Handle(strings.NewReader(input), &buf)
	buf.Reset()
	// 2nd call
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp SystemMessageResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !strings.Contains(resp.SystemMessage, "failure #2/3") {
		t.Errorf("expected failure #2/3 message, got: %s", resp.SystemMessage)
	}
}

func TestPostToolFailureHandler_ThirdFailureEscalates(t *testing.T) {
	dir := t.TempDir()
	now := time.Now()
	h := &PostToolFailureHandler{
		StateDir: dir,
		nowFunc:  func() time.Time { return now },
	}

	input := `{"tool_name":"Write","error":"permission denied"}`
	var buf bytes.Buffer

	for i := 0; i < 3; i++ {
		buf.Reset()
		if err := h.Handle(strings.NewReader(input), &buf); err != nil {
			t.Fatalf("iteration %d: unexpected error: %v", i+1, err)
		}
	}

	var resp SystemMessageResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !strings.Contains(resp.SystemMessage, "WARNING") {
		t.Errorf("expected WARNING escalation, got: %s", resp.SystemMessage)
	}
	if !strings.Contains(resp.SystemMessage, "3 consecutive") {
		t.Errorf("expected consecutive count in message, got: %s", resp.SystemMessage)
	}
	if !strings.Contains(resp.SystemMessage, "Write") {
		t.Errorf("expected tool name in escalation message, got: %s", resp.SystemMessage)
	}
}

func TestPostToolFailureHandler_ResetAfterEscalation(t *testing.T) {
	dir := t.TempDir()
	now := time.Now()
	h := &PostToolFailureHandler{
		StateDir: dir,
		nowFunc:  func() time.Time { return now },
	}

	input := `{"tool_name":"Bash","error":"error"}`
	var buf bytes.Buffer

	// Escalation after 3 failures
	for i := 0; i < 3; i++ {
		buf.Reset()
		_ = h.Handle(strings.NewReader(input), &buf)
	}

	// 4th call is the 1st after reset
	buf.Reset()
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp SystemMessageResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !strings.Contains(resp.SystemMessage, "failure #1/3") {
		t.Errorf("expected reset to failure #1/3, got: %s", resp.SystemMessage)
	}
}

func TestPostToolFailureHandler_StalenessReset(t *testing.T) {
	dir := t.TempDir()
	pastTime := time.Now().Add(-2 * time.Minute) // 2 minutes ago
	futureTime := time.Now()

	callCount := 0
	h := &PostToolFailureHandler{
		StateDir: dir,
		nowFunc: func() time.Time {
			callCount++
			if callCount <= 1 {
				return pastTime
			}
			return futureTime
		},
	}

	input := `{"tool_name":"Bash","error":"error"}`
	var buf bytes.Buffer

	// 1st call: 2 minutes ago
	_ = h.Handle(strings.NewReader(input), &buf)
	buf.Reset()

	// 2nd call: now (2 minutes elapsed > StalenessThreshold=60s) → count reset
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp SystemMessageResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !strings.Contains(resp.SystemMessage, "failure #1/3") {
		t.Errorf("expected staleness reset to #1/3, got: %s", resp.SystemMessage)
	}
}

func TestPostToolFailureHandler_ToolNameFallback(t *testing.T) {
	dir := t.TempDir()
	h := &PostToolFailureHandler{StateDir: dir}

	// Use the toolName (camelCase) field
	input := `{"toolName":"Edit","error":"write error"}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp SystemMessageResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !strings.Contains(resp.SystemMessage, "Edit") {
		t.Errorf("expected tool name 'Edit', got: %s", resp.SystemMessage)
	}
}

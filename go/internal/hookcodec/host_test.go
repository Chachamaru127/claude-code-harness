package hookcodec

import (
	"reflect"
	"testing"
)

func TestNormalize_PropagatesResolvedHostIntoHookInput(t *testing.T) {
	input, host, err := Normalize([]byte(`{
		"session_id":"session-host-audit",
		"tool_name":"Bash",
		"tool_input":{"command":"sudo printf host-audit"}
	}`), HostCodex)
	if err != nil {
		t.Fatalf("Normalize: %v", err)
	}
	if host != HostCodex {
		t.Fatalf("resolved host = %q, want %q", host, HostCodex)
	}

	field := reflect.ValueOf(input).FieldByName("Host")
	if !field.IsValid() {
		t.Fatal("HookInput does not expose a Host field")
	}
	if field.Kind() != reflect.String {
		t.Fatalf("HookInput.Host kind = %s, want string", field.Kind())
	}
	if got := field.String(); got != HostCodex {
		t.Fatalf("HookInput.Host = %q, want %q", got, HostCodex)
	}
}

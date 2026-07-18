package hostgen

import (
	"bytes"
	"encoding/json"
	"fmt"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/runtimefloor"
)

func TestFloorPolicyFragment_HasFiveCategories(t *testing.T) {
	frag := FloorPolicyFragment()
	if len(frag.Categories) != 5 {
		t.Fatalf("len(Categories) = %d, want 5", len(frag.Categories))
	}
}

func TestFloorPolicyFragment_CategoryIDsMatchRuntimefloor(t *testing.T) {
	want := []runtimefloor.Category{
		runtimefloor.CategoryMoneyBilling,
		runtimefloor.CategoryEgress,
		runtimefloor.CategorySecretRead,
		runtimefloor.CategoryProdDeploy,
		runtimefloor.CategoryWorktreeEscape,
	}
	frag := FloorPolicyFragment()
	if len(frag.Categories) != len(want) {
		t.Fatalf("len(Categories) = %d, want %d", len(frag.Categories), len(want))
	}
	for i, cat := range want {
		if frag.Categories[i].ID != string(cat) {
			t.Errorf("Categories[%d].ID = %q, want %q", i, frag.Categories[i].ID, cat)
		}
	}
}

func TestFloorPolicyFragment_DeterministicOrder(t *testing.T) {
	a, err := marshalStable(FloorPolicyFragment())
	if err != nil {
		t.Fatalf("marshal first: %v", err)
	}
	b, err := marshalStable(FloorPolicyFragment())
	if err != nil {
		t.Fatalf("marshal second: %v", err)
	}
	if !bytes.Equal(a, b) {
		t.Errorf("FloorPolicyFragment marshal not deterministic:\nfirst:\n%s\nsecond:\n%s", a, b)
	}
}

func TestFloorPolicyFragment_IDsAreCanonical(t *testing.T) {
	want := map[string]bool{
		"money-billing":   false,
		"egress":          false,
		"secret-read":     false,
		"prod-deploy":     false,
		"worktree-escape": false,
	}
	for _, row := range FloorPolicyFragment().Categories {
		if _, ok := want[row.ID]; ok {
			want[row.ID] = true
		}
	}
	for id, seen := range want {
		if !seen {
			t.Errorf("missing canonical category id %q", id)
		}
	}
}

func TestGenerateHooksJSON_UsesOnlyVendorSchemaTopLevelKeys(t *testing.T) {
	hosts, err := Load(writeSampleHosts(t))
	if err != nil {
		t.Fatal(err)
	}
	allowed := map[string]map[string]bool{
		"claude": {"hooks": true},
		"codex":  {"hooks": true},
		"cursor": {"version": true, "hooks": true},
	}
	for _, name := range []string{"claude", "codex", "cursor"} {
		out, err := GenerateHooksJSON(hosts[name])
		if err != nil {
			t.Fatalf("GenerateHooksJSON(%s): %v", name, err)
		}
		var doc map[string]json.RawMessage
		if err := json.Unmarshal(out, &doc); err != nil {
			t.Fatalf("%s: invalid JSON: %v", name, err)
		}
		for key := range doc {
			if !allowed[name][key] {
				t.Errorf("%s generated hooks.json contains vendor-unsupported top-level key %q", name, key)
			}
		}
	}
}

func TestGenerateHooksJSON_HooksBlockMatchesHostSchema(t *testing.T) {
	hosts, err := Load(writeSampleHosts(t))
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"claude", "codex", "cursor"} {
		h := hosts[name]
		want, err := baselineHooksRaw(h)
		if err != nil {
			t.Fatalf("%s baseline hooks: %v", name, err)
		}
		out, err := GenerateHooksJSON(h)
		if err != nil {
			t.Fatalf("GenerateHooksJSON(%s): %v", name, err)
		}
		got, err := extractHooksRaw(out)
		if err != nil {
			t.Fatalf("%s extract hooks: %v", name, err)
		}
		if !bytes.Equal(want, got) {
			t.Errorf("%s hooks block does not match host schema\nwant:\n%s\ngot:\n%s", name, want, got)
		}
	}
}

func baselineHooksRaw(h Host) (json.RawMessage, error) {
	var doc map[string]interface{}
	switch h.Name {
	case "claude":
		doc = claudeDoc(h)
	case "codex":
		doc = codexDoc(h)
	case "cursor":
		doc = cursorDoc(h)
	default:
		return nil, fmt.Errorf("unknown host %q", h.Name)
	}
	b, err := marshalStable(doc)
	if err != nil {
		return nil, err
	}
	return extractHooksRaw(b)
}

func extractHooksRaw(doc []byte) (json.RawMessage, error) {
	var parsed struct {
		Hooks json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal(doc, &parsed); err != nil {
		return nil, fmt.Errorf("parse hooks json: %w", err)
	}
	if parsed.Hooks == nil {
		return nil, fmt.Errorf("missing hooks key")
	}
	return parsed.Hooks, nil
}

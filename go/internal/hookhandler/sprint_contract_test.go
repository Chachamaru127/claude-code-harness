package hookhandler

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestSprintContractGenerator_RuntimeContract(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	packageJSONPath := filepath.Join(dir, "package.json")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 32.1.1 | contract を作る | runtime validation を contract に載せる | 32.0.1 | cc:TODO |
`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(packageJSONPath, []byte(`{"scripts":{"test":"vitest run","test:e2e":"playwright test"},"devDependencies":{"@playwright/test":"^1.52.0"}}`), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{
		ProjectRoot: dir,
		PlansFile:   plansPath,
		Now:         func() string { return "2026-04-16T00:00:00Z" },
	}
	doc, err := g.Generate("32.1.1")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}

	if doc.SchemaVersion != "sprint-contract.v1" {
		t.Fatalf("unexpected schema version: %s", doc.SchemaVersion)
	}
	if doc.Review.ReviewerProfile != "runtime" {
		t.Fatalf("expected runtime profile, got %s", doc.Review.ReviewerProfile)
	}
	if len(doc.Contract.RuntimeValidation) == 0 || doc.Contract.RuntimeValidation[0].Command != "CI=true npm test" {
		t.Fatalf("unexpected runtime validation: %+v", doc.Contract.RuntimeValidation)
	}
	if !doc.Advisor.Enabled || doc.Advisor.Mode != "on-demand" {
		t.Fatalf("unexpected advisor defaults: %+v", doc.Advisor)
	}
	if doc.Advisor.MaxConsults != 3 || doc.Advisor.RetryThreshold != 2 || !doc.Advisor.PreEscalationConsult {
		t.Fatalf("unexpected advisor thresholds: %+v", doc.Advisor)
	}
	if doc.Advisor.ModelPolicy.ClaudeDefault != "opus" || doc.Advisor.ModelPolicy.CodexDefault != "gpt-5.4" {
		t.Fatalf("unexpected advisor model policy: %+v", doc.Advisor.ModelPolicy)
	}
	if len(doc.Advisor.Triggers) != 0 {
		t.Fatalf("expected no advisor triggers, got %+v", doc.Advisor.Triggers)
	}

	data, err := json.Marshal(doc)
	if err != nil {
		t.Fatalf("marshal runtime contract: %v", err)
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("unmarshal runtime contract: %v", err)
	}
	review, ok := raw["review"].(map[string]any)
	if !ok {
		t.Fatalf("review block missing from marshaled contract: %s", data)
	}
	if _, exists := review["rubric_target"]; exists {
		t.Fatalf("runtime contracts must omit rubric_target unless ui-rubric is active: %s", data)
	}
}

func TestSprintContractGenerator_DeclaredScope(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 134.5 | scope leash 配線を `+"`go/internal/guardrail/pre_tool.go`"+` に実装 | (a) `+"`go/internal/hookhandler/sprint_contract.go`"+` で declared_scope を焼き込む | - | cc:todo |
`), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{
		ProjectRoot: dir,
		PlansFile:   plansPath,
		Now:         func() string { return "2026-08-15T00:00:00Z" },
	}
	doc, err := g.Generate("134.5")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}

	want := []string{
		"go/internal/guardrail/pre_tool.go",
		"go/internal/hookhandler/sprint_contract.go",
	}
	if len(doc.Task.DeclaredScope) != len(want) {
		t.Fatalf("declared_scope = %v, want %v", doc.Task.DeclaredScope, want)
	}
	for i, p := range want {
		if doc.Task.DeclaredScope[i] != p {
			t.Fatalf("declared_scope[%d] = %q, want %q (full: %v)", i, doc.Task.DeclaredScope[i], p, doc.Task.DeclaredScope)
		}
	}

	data, err := json.Marshal(doc)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	task, ok := raw["task"].(map[string]any)
	if !ok {
		t.Fatalf("task block missing: %s", data)
	}
	if _, exists := task["declared_scope"]; !exists {
		t.Fatalf("declared_scope key missing from marshaled contract: %s", data)
	}
}

func TestSprintContractGenerator_UIRubricDefaults(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 41.3.1 | design-heavy task | design と styling と aesthetic を見ながら UI layout を磨く | 41.2.1 | cc:TODO |
`), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}
	doc, err := g.Generate("41.3.1")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if doc.Review.ReviewerProfile != "ui-rubric" {
		t.Fatalf("expected ui-rubric, got %s", doc.Review.ReviewerProfile)
	}
	if doc.Review.MaxIterations != 10 {
		t.Fatalf("expected max_iterations=10, got %d", doc.Review.MaxIterations)
	}
	if doc.Review.RubricTarget == nil || doc.Review.RubricTarget.Design != 6 || doc.Review.RubricTarget.Functionality != 6 {
		t.Fatalf("unexpected rubric target: %+v", doc.Review.RubricTarget)
	}
}

func TestSprintContractGenerator_MaxIterationsHTMLOverride(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| T-html-comment | HTML コメントタスク | <!-- max_iterations: 15 --> を DoD に記載 | - | cc:TODO |
`), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}
	doc, err := g.Generate("T-html-comment")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if doc.Review.MaxIterations != 15 {
		t.Fatalf("expected max_iterations=15, got %d", doc.Review.MaxIterations)
	}
}

func TestSprintContractGenerator_BrowserRouteRules(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	packageJSONPath := filepath.Join(dir, "package.json")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| scripted | browser evaluator を追加する | browser で UI フローを確認する | 32.2.1 | cc:TODO |
| exploratory | browser_mode: exploratory を扱う | exploratory mode で AgentBrowser を優先する | 32.2.2 | cc:TODO |
`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(packageJSONPath, []byte(`{"scripts":{"test:e2e":"playwright test"},"devDependencies":{"@playwright/test":"^1.52.0"}}`), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}

	scripted, err := g.Generate("scripted")
	if err != nil {
		t.Fatalf("Generate scripted: %v", err)
	}
	if scripted.Review.ReviewerProfile != "browser" {
		t.Fatalf("expected browser profile, got %s", scripted.Review.ReviewerProfile)
	}
	if scripted.Review.Route == nil || *scripted.Review.Route != "playwright" {
		t.Fatalf("expected scripted route=playwright, got %+v", scripted.Review.Route)
	}

	exploratory, err := g.Generate("exploratory")
	if err != nil {
		t.Fatalf("Generate exploratory: %v", err)
	}
	if exploratory.Review.BrowserMode == nil || *exploratory.Review.BrowserMode != "exploratory" {
		t.Fatalf("expected exploratory browser mode, got %+v", exploratory.Review.BrowserMode)
	}
	if exploratory.Review.Route != nil {
		t.Fatalf("expected exploratory route=nil, got %+v", exploratory.Review.Route)
	}
}

func TestSprintContractGenerator_AdvisorTriggers(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 43.1.1 | [needs-spike] security migration contract | state migration の guard を確認する <!-- advisor:required --> | - | cc:TODO |
`), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}
	doc, err := g.Generate("43.1.1")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}

	expected := []string{"needs-spike", "security-sensitive", "state-migration", "<!-- advisor:required -->"}
	if len(doc.Advisor.Triggers) != len(expected) {
		t.Fatalf("unexpected advisor triggers length: got=%v want=%v", doc.Advisor.Triggers, expected)
	}
	for i, trigger := range expected {
		if doc.Advisor.Triggers[i] != trigger {
			t.Fatalf("unexpected advisor trigger order: got=%v want=%v", doc.Advisor.Triggers, expected)
		}
	}
}

func TestSprintContractGenerator_HeadingTask(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("# Plans\n\n"+
		"#### 6G-6: Mount Mode 音声ルーティング UI / 構成チェック `cc:TODO`\n\n"+
		"- [ ] 自分にも音を聞かせるための出力先を UI で選べるようにする\n"+
		"- [ ] 起動前チェックで AI が聞ける / 自分が聞ける / LINE に返せるを判定する\n"+
		"Depends: 6G-1, 6G-2\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}
	doc, err := g.Generate("6G-6")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if doc.Task.ID != "6G-6" {
		t.Fatalf("unexpected task id: %s", doc.Task.ID)
	}
	if doc.Task.Title != "Mount Mode 音声ルーティング UI / 構成チェック" {
		t.Fatalf("unexpected heading title: %q", doc.Task.Title)
	}
	if len(doc.Task.DependsOn) != 2 || doc.Task.DependsOn[0] != "6G-1" || doc.Task.DependsOn[1] != "6G-2" {
		t.Fatalf("unexpected depends: %+v", doc.Task.DependsOn)
	}
	if doc.Task.StatusAtGeneration != "cc:TODO" {
		t.Fatalf("unexpected status: %s", doc.Task.StatusAtGeneration)
	}
	if doc.Task.DefinitionOfDone == "" || doc.Task.DefinitionOfDone == doc.Task.Title {
		t.Fatalf("expected checklist-derived DoD, got %q", doc.Task.DefinitionOfDone)
	}
}

func TestSprintContractGenerator_StatusMarkerAliases(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("# Plans\n\n"+
		"#### H-1: Requested alias `pm:requested`\n\n"+
		"- [ ] Requested aliases are accepted.\n\n"+
		"#### H-2: Done alias `cc:done`\n\n"+
		"- [x] Done aliases are accepted.\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}

	requested, err := g.Generate("H-1")
	if err != nil {
		t.Fatalf("Generate requested alias: %v", err)
	}
	if requested.Task.StatusAtGeneration != "pm:requested" {
		t.Fatalf("expected pm:requested, got %s", requested.Task.StatusAtGeneration)
	}
	if requested.Task.Title != "Requested alias" {
		t.Fatalf("expected status marker to be removed from title, got %q", requested.Task.Title)
	}

	done, err := g.Generate("H-2")
	if err != nil {
		t.Fatalf("Generate done alias: %v", err)
	}
	if done.Task.StatusAtGeneration != "cc:done" {
		t.Fatalf("expected cc:done, got %s", done.Task.StatusAtGeneration)
	}
	if done.Task.Title != "Done alias" {
		t.Fatalf("expected status marker to be removed from title, got %q", done.Task.Title)
	}
}

func TestSprintContractGenerator_TDDHybridInference(t *testing.T) {
	cases := []struct {
		name          string
		title         string
		dod           string
		setup         func(t *testing.T, dir string)
		wantRequired  bool
		wantFramework string
		wantReason    *string
	}{
		{
			name:          "required tag wins without framework",
			title:         "[tdd:required] docs-only note",
			dod:           "Update `docs/tdd.md` and keep the explicit tag authoritative.",
			wantRequired:  true,
			wantFramework: "none",
		},
		{
			name:  "skip tag records reason over source inference",
			title: "[tdd:skip:legacy-migration] touch Go source",
			dod:   "Update `go/internal/hookhandler/sprint_contract.go` safely.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "go.mod"), "module example.com/harness\n")
			},
			wantRequired:  false,
			wantFramework: "go",
			wantReason:    strPtr("legacy-migration"),
		},
		{
			name:  "go source path with framework requires tdd",
			title: "Go source contract",
			dod:   "Change `go/internal/hookhandler/sprint_contract.go`.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "go.mod"), "module example.com/harness\n")
			},
			wantRequired:  true,
			wantFramework: "go",
		},
		{
			name:  "top-level cmd path with framework requires tdd",
			title: "Go command source contract",
			dod:   "Change `cmd/harness/main.go`.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "go.mod"), "module example.com/harness\n")
			},
			wantRequired:  true,
			wantFramework: "go",
		},
		{
			name:  "top-level pkg path with framework requires tdd",
			title: "Go package source contract",
			dod:   "Change `pkg/runtime/options.go`.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "go.mod"), "module example.com/harness\n")
			},
			wantRequired:  true,
			wantFramework: "go",
		},
		{
			name:  "src path with vitest requires tdd",
			title: "Node app source",
			dod:   "Change `src/contract.ts`.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "package.json"), `{"scripts":{"test":"vitest run"}}`)
			},
			wantRequired:  true,
			wantFramework: "vitest",
		},
		{
			name:  "docs scripts claude only skips as docs-only",
			title: "Docs-only wiring",
			dod:   "Update `docs/tdd.md`, `scripts/log-tdd-red.sh`, and `.claude/rules/tdd-paths.yaml`.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "go.mod"), "module example.com/harness\n")
			},
			wantRequired:  false,
			wantFramework: "go",
			wantReason:    strPtr("docs-only"),
		},
		{
			name:          "source path without framework skips with no-framework reason",
			title:         "Source without tests",
			dod:           "Change `src/no_framework.ts`.",
			wantRequired:  false,
			wantFramework: "none",
			wantReason:    strPtr("no-test-framework-detected"),
		},
		{
			name:  "default no path is off",
			title: "Generic planning task",
			dod:   "Clarify acceptance wording without file scope.",
			setup: func(t *testing.T, dir string) {
				t.Helper()
				writeFile(t, filepath.Join(dir, "go.mod"), "module example.com/harness\n")
			},
			wantRequired:  false,
			wantFramework: "go",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			if tc.setup != nil {
				tc.setup(t, dir)
			}
			plansPath := filepath.Join(dir, "Plans.md")
			writeFile(t, plansPath, "| Task | 内容 | DoD | Depends | Status |\n"+
				"|------|------|-----|---------|--------|\n"+
				"| TDD-1 | "+tc.title+" | "+tc.dod+" | - | cc:TODO |\n")

			g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath}
			doc, err := g.Generate("TDD-1")
			if err != nil {
				t.Fatalf("Generate: %v", err)
			}

			if doc.Contract.TDDRequired != tc.wantRequired {
				t.Fatalf("unexpected tdd_required: got=%v want=%v", doc.Contract.TDDRequired, tc.wantRequired)
			}
			if doc.Contract.TestFramework != tc.wantFramework {
				t.Fatalf("unexpected test_framework: got=%q want=%q", doc.Contract.TestFramework, tc.wantFramework)
			}
			if tc.wantReason == nil {
				if doc.Contract.SkipTDDReason != nil {
					t.Fatalf("expected skip_tdd_reason=nil, got %q", *doc.Contract.SkipTDDReason)
				}
			} else if doc.Contract.SkipTDDReason == nil || *doc.Contract.SkipTDDReason != *tc.wantReason {
				t.Fatalf("unexpected skip_tdd_reason: got=%v want=%q", doc.Contract.SkipTDDReason, *tc.wantReason)
			}
			if tc.wantRequired {
				if got := doc.Contract.TestTodoList; len(got) != 3 || got[0] != "normal" || got[1] != "boundary" || got[2] != "error" {
					t.Fatalf("unexpected test_todo_list: %+v", got)
				}
			} else if len(doc.Contract.TestTodoList) != 0 {
				t.Fatalf("expected empty test_todo_list for skipped/default task, got %+v", doc.Contract.TestTodoList)
			}
		})
	}
}

func writeFile(t *testing.T, path, contents string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func strPtr(value string) *string {
	return &value
}

func TestSprintContractGenerator_WriteRoundTrip(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(`| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 32.1.1 | contract を作る | runtime validation を contract に載せる | 32.0.1 | cc:TODO |
`), 0o600); err != nil {
		t.Fatal(err)
	}
	outputPath := filepath.Join(dir, "out", "32.1.1.sprint-contract.json")
	g := &SprintContractGenerator{ProjectRoot: dir, PlansFile: plansPath, OutputFile: outputPath}
	written, err := g.Write("32.1.1")
	if err != nil {
		t.Fatalf("Write: %v", err)
	}
	if written != outputPath {
		t.Fatalf("unexpected output path: %s", written)
	}
	data, err := os.ReadFile(outputPath)
	if err != nil {
		t.Fatalf("read output: %v", err)
	}
	var doc sprintContractDoc
	if err := json.Unmarshal(data, &doc); err != nil {
		t.Fatalf("invalid JSON output: %v", err)
	}
	if doc.Task.ID != "32.1.1" {
		t.Fatalf("unexpected task id: %s", doc.Task.ID)
	}
}

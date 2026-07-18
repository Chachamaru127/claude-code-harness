package hookhandler

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// SprintContractGenerator は Plans.md から sprint-contract を生成する。
type SprintContractGenerator struct {
	ProjectRoot string
	PlansFile   string
	OutputFile  string
	Now         func() string
}

type sprintTaskRow struct {
	TaskID  string
	Title   string
	DoD     string
	Depends string
	Status  string
}

type sprintContractDoc struct {
	SchemaVersion string                `json:"schema_version"`
	GeneratedAt   string                `json:"generated_at"`
	Source        sprintContractSource  `json:"source"`
	Task          sprintContractTask    `json:"task"`
	Contract      sprintContractBody    `json:"contract"`
	Advisor       sprintContractAdvisor `json:"advisor"`
	Review        sprintContractReview  `json:"review"`
}

type sprintContractSource struct {
	PlansFile string `json:"plans_file"`
	TaskID    string `json:"task_id"`
}

type sprintContractTask struct {
	ID                 string   `json:"id"`
	Title              string   `json:"title"`
	DefinitionOfDone   string   `json:"definition_of_done"`
	DependsOn          []string `json:"depends_on"`
	StatusAtGeneration string   `json:"status_at_generation"`
}

type sprintContractBody struct {
	Checks            []sprintCheck      `json:"checks"`
	NonGoals          []string           `json:"non_goals"`
	RuntimeValidation []sprintValidation `json:"runtime_validation"`
	BrowserValidation []sprintValidation `json:"browser_validation"`
	RiskFlags         []string           `json:"risk_flags"`
	TDDRequired       bool               `json:"tdd_required"`
	TestFramework     string             `json:"test_framework"`
	TestTodoList      []string           `json:"test_todo_list"`
	SkipTDDReason     *string            `json:"skip_tdd_reason"`
}

type sprintContractAdvisor struct {
	Enabled              bool                     `json:"enabled"`
	Mode                 string                   `json:"mode"`
	MaxConsults          int                      `json:"max_consults"`
	RetryThreshold       int                      `json:"retry_threshold"`
	PreEscalationConsult bool                     `json:"pre_escalation_consult"`
	Triggers             []string                 `json:"triggers"`
	ModelPolicy          sprintAdvisorModelPolicy `json:"model_policy"`
}

type sprintAdvisorModelPolicy struct {
	ClaudeDefault string `json:"claude_default"`
	CodexDefault  string `json:"codex_default"`
}

type sprintCheck struct {
	ID          string `json:"id"`
	Source      string `json:"source"`
	Description string `json:"description"`
}

type sprintValidation struct {
	ID                string   `json:"id"`
	Label             string   `json:"label,omitempty"`
	Command           string   `json:"command,omitempty"`
	Description       string   `json:"description,omitempty"`
	RequiredArtifacts []string `json:"required_artifacts,omitempty"`
}

type sprintContractReview struct {
	Status          string          `json:"status"`
	ReviewerProfile string          `json:"reviewer_profile"`
	MaxIterations   int             `json:"max_iterations"`
	RubricTarget    *uiRubricTarget `json:"rubric_target,omitempty"`
	BrowserMode     *string         `json:"browser_mode,omitempty"`
	Route           *string         `json:"route,omitempty"`
	ReviewerNotes   []string        `json:"reviewer_notes"`
	ApprovedAt      *string         `json:"approved_at,omitempty"`
	Gaps            []string        `json:"gaps"`
	Followups       []string        `json:"followups"`
}

type uiRubricTarget struct {
	Design        int `json:"design"`
	Originality   int `json:"originality"`
	Craft         int `json:"craft"`
	Functionality int `json:"functionality"`
}

var (
	uiRubricRe         = regexp.MustCompile(`(?i)\bui-rubric\b|\bdesign\b|styling|aesthetic|visual polish|design-heavy|design quality|originality|craft|functionality|デザイン|見た目品質|意匠|質感|デザイン品質`)
	uiWithDesignRe     = regexp.MustCompile(`(?i)\bui\b`)
	layoutWithDesignRe = regexp.MustCompile(`(?i)\blayout\b`)
	uiDesignHintRe     = regexp.MustCompile(`(?i)design|styling|aesthetic|layout|visual|polish|デザイン|見た目`)
	browserProfileRe   = regexp.MustCompile(`(?i)browser|chrome|playwright|\bui\b|layout|responsive|スクリーンショット|画面|web アプリ|webアプリ`)
	runtimeProfileRe   = regexp.MustCompile(`(?i)runtime|typecheck|lint|test|api|probe|integration|e2e|検証コマンド`)
	maxIterationsRe    = regexp.MustCompile(`(?is)<!--\s*max_iterations:\s*(\d+)\s*-->`)
	exploratoryModeRe  = regexp.MustCompile(`(?i)(browser_mode\s*:\s*exploratory|\bexploratory\b|探索モード|探索的)`)
	scriptedModeRe     = regexp.MustCompile(`(?i)(browser_mode\s*:\s*scripted|\bscripted\b|定型|決め打ち)`)
	explicitRouteRe    = regexp.MustCompile(`(?i)(?:browser_)?route\s*:\s*(playwright|agent-browser|chrome-devtools)`)
	// Sprint contracts recognize literal Plans.md tags: [tdd:required] and [tdd:skip:<reason>].
	tddRequiredTagRe    = regexp.MustCompile(`(?i)\[tdd:required\]`)
	tddSkipTagRe        = regexp.MustCompile(`(?i)\[tdd:skip:([^\]]+)\]`)
	pathInBackticksRe   = regexp.MustCompile("`([^`]+)`")
	sprintPathTokenRe   = regexp.MustCompile(`(?:^|[\s(,])((?:\.claude|src|app|cmd|go|lib|pkg|internal|docs|scripts|tests|agents|skills|hooks|templates|frontend|mcp-server|harness-ui)(?:/[A-Za-z0-9._@+-]+)+)`)
	securitySensitiveRe = regexp.MustCompile(`(?i)security|auth|permission|secret|guardrail|セキュリティ|権限`)
	stateMigrationRe    = regexp.MustCompile(`(?i)migration|schema|state|resume|session|artifact|マイグレーション|セッション|再開`)
	uxRegressionRe      = regexp.MustCompile(`(?i)browser|ui|layout|responsive|playwright|chrome|画面|レイアウト`)
	advisorRequiredRe   = regexp.MustCompile(`(?is)<!--\s*advisor:required\s*-->`)
	headingTaskRe       = regexp.MustCompile(`^\s{0,3}(#{2,6})\s+([A-Za-z0-9][A-Za-z0-9_.-]*)(?:\s*[:：]\s*|\s+)(.*)$`)
	headingStatusRe     = regexp.MustCompile(`(?i)\b(?:cc:TODO|cc:WIP|cc:完了|pm:依頼中|pm:確認済|cursor:依頼中|cursor:確認済|cc:done|pm:requested|pm:approved|cc:blocked|blocked)(?:\s*\[[^\]]+\])?`)
	headingDependsRe    = regexp.MustCompile(`(?i)^\s*(?:depends|依存)\s*[:：]\s*(.+?)\s*$`)
)

var profileMaxIterations = map[string]int{
	"static":    3,
	"runtime":   3,
	"browser":   5,
	"ui-rubric": 10,
}

var defaultUIRubricTarget = &uiRubricTarget{
	Design:        6,
	Originality:   6,
	Craft:         6,
	Functionality: 6,
}

var defaultSprintAdvisor = sprintContractAdvisor{
	Enabled:              true,
	Mode:                 "on-demand",
	MaxConsults:          3,
	RetryThreshold:       2,
	PreEscalationConsult: true,
	ModelPolicy: sprintAdvisorModelPolicy{
		ClaudeDefault: "opus",
		CodexDefault:  "gpt-5.4",
	},
}

// Generate は指定タスクの sprint-contract を生成して返す。
func (g *SprintContractGenerator) Generate(taskID string) (*sprintContractDoc, error) {
	projectRoot := g.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}

	plansFile := g.PlansFile
	if plansFile == "" {
		plansFile = filepath.Join(projectRoot, "Plans.md")
		if _, err := os.Stat(plansFile); err != nil {
			if resolved := resolvePlansPath(projectRoot); resolved != "" {
				plansFile = resolved
			}
		}
	}

	if _, err := os.Stat(plansFile); err != nil {
		return nil, fmt.Errorf("Plans.md not found: %s", plansFile)
	}

	markdown, err := os.ReadFile(plansFile)
	if err != nil {
		return nil, fmt.Errorf("read plans file: %w", err)
	}

	row, err := parseSprintTaskRow(string(markdown), taskID)
	if err != nil {
		return nil, err
	}

	reviewerProfile := detectSprintProfile(row)
	maxIterations := detectSprintMaxIterations(reviewerProfile, row)
	runtimeValidation := pickRuntimeCommands(projectRoot)
	riskFlags := detectSprintRiskFlags(row)
	advisor := buildSprintAdvisor(row, riskFlags)
	tdd := detectSprintTDD(projectRoot, row)

	var browserMode *string
	var route *string
	if reviewerProfile == "browser" {
		mode := detectSprintBrowserMode(row)
		browserMode = &mode
		if detected := detectSprintBrowserRoute(row, projectRoot, mode); detected != nil {
			route = detected
		}
	}

	var rubricTarget *uiRubricTarget
	if reviewerProfile == "ui-rubric" {
		copy := *defaultUIRubricTarget
		rubricTarget = &copy
	}

	browserValidation := []sprintValidation{}
	if reviewerProfile == "browser" && browserMode != nil {
		requiredArtifacts := []string{"trace", "screenshot", "ui-flow-log"}
		if *browserMode == "exploratory" {
			requiredArtifacts = []string{"snapshot", "ui-flow-log"}
		}
		browserValidation = []sprintValidation{
			{
				ID:                "browser-smoke",
				Description:       row.DoD,
				RequiredArtifacts: requiredArtifacts,
			},
		}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	if g.Now != nil {
		now = g.Now()
	}

	relPlans := plansFile
	if rel, err := filepath.Rel(projectRoot, plansFile); err == nil && rel != "" {
		relPlans = rel
	}

	doc := &sprintContractDoc{
		SchemaVersion: "sprint-contract.v1",
		GeneratedAt:   now,
		Source: sprintContractSource{
			PlansFile: relPlans,
			TaskID:    row.TaskID,
		},
		Task: sprintContractTask{
			ID:                 row.TaskID,
			Title:              row.Title,
			DefinitionOfDone:   row.DoD,
			DependsOn:          sprintToList(row.Depends),
			StatusAtGeneration: row.Status,
		},
		Contract: sprintContractBody{
			Checks: []sprintCheck{
				{
					ID:          "dod-primary",
					Source:      "Plans.md.DoD",
					Description: row.DoD,
				},
			},
			NonGoals:          []string{},
			RuntimeValidation: runtimeValidation,
			BrowserValidation: browserValidation,
			RiskFlags:         riskFlags,
			TDDRequired:       tdd.Required,
			TestFramework:     tdd.TestFramework,
			TestTodoList:      tdd.TestTodoList,
			SkipTDDReason:     tdd.SkipReason,
		},
		Advisor: advisor,
		Review: sprintContractReview{
			Status:          "draft",
			ReviewerProfile: reviewerProfile,
			MaxIterations:   maxIterations,
			RubricTarget:    rubricTarget,
			BrowserMode:     browserMode,
			Route:           route,
			ReviewerNotes:   []string{},
			ApprovedAt:      nil,
			Gaps:            []string{},
			Followups:       []string{},
		},
	}

	return doc, nil
}

// Write は contract を JSON で出力ファイルへ保存する。
func (g *SprintContractGenerator) Write(taskID string) (string, error) {
	doc, err := g.Generate(taskID)
	if err != nil {
		return "", err
	}

	projectRoot := g.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}

	outputFile := g.OutputFile
	if outputFile == "" {
		outputFile = filepath.Join(projectRoot, ".claude", "state", "contracts", fmt.Sprintf("%s.sprint-contract.json", taskID))
	}

	if err := os.MkdirAll(filepath.Dir(outputFile), 0o755); err != nil {
		return "", fmt.Errorf("create output dir: %w", err)
	}

	data, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return "", fmt.Errorf("marshal contract: %w", err)
	}
	data = append(data, '\n')

	if err := os.WriteFile(outputFile, data, 0o644); err != nil {
		return "", fmt.Errorf("write contract: %w", err)
	}
	return outputFile, nil
}

func parseSprintTaskRow(markdown, targetTaskID string) (*sprintTaskRow, error) {
	lines := strings.Split(markdown, "\n")
	headerColCount := 5
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if matched, _ := regexp.MatchString(`^\|[\s-]+\|`, trimmed); matched {
			sepCols := []string{}
			for _, part := range strings.Split(trimmed, "|") {
				if strings.TrimSpace(part) != "" {
					sepCols = append(sepCols, part)
				}
			}
			if len(sepCols) >= 5 {
				headerColCount = len(sepCols)
			}
			break
		}
	}

	const pipePlaceholder = "\x00PIPE\x00"
	escapePipes := func(s string) string { return strings.ReplaceAll(s, `\|`, pipePlaceholder) }
	restorePipes := func(s string) string { return strings.ReplaceAll(s, pipePlaceholder, "|") }

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "|") {
			continue
		}
		if matched, _ := regexp.MatchString(`^\|[\s-]+\|`, trimmed); matched {
			continue
		}

		inner := strings.TrimSuffix(strings.TrimPrefix(escapePipes(trimmed), "|"), "|")
		parts := strings.Split(inner, "|")
		if len(parts) < 5 {
			continue
		}

		taskID := strings.TrimSpace(parts[0])
		if taskID != targetTaskID {
			continue
		}

		status := strings.TrimSpace(parts[len(parts)-1])
		depends := strings.TrimSpace(parts[len(parts)-2])
		middleParts := parts[1 : len(parts)-2]
		expectedMiddle := headerColCount - 3

		title := ""
		dod := ""
		if expectedMiddle <= 1 || len(middleParts) <= 1 {
			if len(middleParts) > 0 {
				title = strings.TrimSpace(middleParts[0])
			}
		} else {
			dod = strings.TrimSpace(middleParts[len(middleParts)-1])
			title = strings.TrimSpace(strings.Join(middleParts[:len(middleParts)-1], "|"))
		}

		return &sprintTaskRow{
			TaskID:  restorePipes(taskID),
			Title:   restorePipes(title),
			DoD:     restorePipes(dod),
			Depends: restorePipes(depends),
			Status:  restorePipes(status),
		}, nil
	}

	if row := parseSprintHeadingTaskRow(lines, targetTaskID); row != nil {
		return row, nil
	}

	return nil, fmt.Errorf("task row not found in Plans.md: %s", targetTaskID)
}

func parseSprintHeadingTaskRow(lines []string, targetTaskID string) *sprintTaskRow {
	for i, line := range lines {
		match := headingTaskRe.FindStringSubmatch(line)
		if len(match) < 4 || match[2] != targetTaskID {
			continue
		}

		level := len(match[1])
		title := cleanSprintHeadingText(match[3])
		status := headingStatusRe.FindString(line)
		depends := "-"
		body := []string{}

		for _, bodyLine := range lines[i+1:] {
			if next := headingTaskRe.FindStringSubmatch(bodyLine); len(next) >= 4 && len(next[1]) <= level {
				break
			}
			trimmed := strings.TrimSpace(bodyLine)
			if trimmed == "" {
				continue
			}
			if depMatch := headingDependsRe.FindStringSubmatch(trimmed); len(depMatch) >= 2 {
				depends = strings.TrimSpace(depMatch[1])
				continue
			}
			if strings.HasPrefix(trimmed, "- [ ]") || strings.HasPrefix(trimmed, "- [x]") || strings.HasPrefix(trimmed, "- [X]") {
				body = append(body, strings.TrimSpace(trimmed[5:]))
				continue
			}
			if strings.HasPrefix(trimmed, "- ") {
				body = append(body, strings.TrimSpace(trimmed[2:]))
			}
		}

		dod := strings.Join(body, "; ")
		if title == "" {
			title = targetTaskID
		}
		if status == "" {
			status = "cc:TODO"
		}
		if dod == "" {
			dod = title
		}

		return &sprintTaskRow{
			TaskID:  targetTaskID,
			Title:   title,
			DoD:     dod,
			Depends: depends,
			Status:  status,
		}
	}
	return nil
}

func cleanSprintHeadingText(value string) string {
	cleaned := headingStatusRe.ReplaceAllString(value, "")
	cleaned = strings.ReplaceAll(cleaned, "`", "")
	return strings.TrimSpace(cleaned)
}

func sprintToList(value string) []string {
	if value == "" || value == "-" {
		return []string{}
	}
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

func detectSprintProfile(task *sprintTaskRow) string {
	text := strings.ToLower(fmt.Sprintf("%s %s", task.Title, task.DoD))
	hasUIHints := uiRubricRe.MatchString(text) ||
		(uiWithDesignRe.MatchString(text) && uiDesignHintRe.MatchString(text)) ||
		(layoutWithDesignRe.MatchString(text) && uiDesignHintRe.MatchString(text))
	if hasUIHints {
		return "ui-rubric"
	}
	if browserProfileRe.MatchString(text) {
		return "browser"
	}
	if runtimeProfileRe.MatchString(text) {
		return "runtime"
	}
	return "static"
}

func detectSprintMaxIterations(profile string, task *sprintTaskRow) int {
	defaultValue := 3
	if value, ok := profileMaxIterations[profile]; ok {
		defaultValue = value
	}
	text := fmt.Sprintf("%s\n%s", task.Title, task.DoD)
	match := maxIterationsRe.FindStringSubmatch(text)
	if len(match) >= 2 {
		value, err := strconv.Atoi(match[1])
		if err == nil && value >= 1 && value <= 30 {
			return value
		}
		if err == nil {
			fmt.Fprintf(os.Stderr, "[warn] max_iterations=%d out of range (1-30), falling back to default %d\n", value, defaultValue)
		}
	}
	return defaultValue
}

func detectSprintBrowserMode(task *sprintTaskRow) string {
	text := strings.ToLower(fmt.Sprintf("%s %s", task.Title, task.DoD))
	if exploratoryModeRe.MatchString(text) {
		return "exploratory"
	}
	if scriptedModeRe.MatchString(text) {
		return "scripted"
	}
	return "scripted"
}

func detectSprintRiskFlags(task *sprintTaskRow) []string {
	text := strings.ToLower(fmt.Sprintf("%s %s", task.Title, task.DoD))
	flags := []string{}
	if strings.Contains(task.Title, "[needs-spike]") || strings.Contains(task.DoD, "[needs-spike]") {
		flags = append(flags, "needs-spike")
	}
	if securitySensitiveRe.MatchString(text) {
		flags = append(flags, "security-sensitive")
	}
	if stateMigrationRe.MatchString(text) {
		flags = append(flags, "state-migration")
	}
	if uxRegressionRe.MatchString(text) {
		flags = append(flags, "ux-regression")
	}
	seen := map[string]struct{}{}
	unique := make([]string, 0, len(flags))
	for _, flag := range flags {
		if _, ok := seen[flag]; ok {
			continue
		}
		seen[flag] = struct{}{}
		unique = append(unique, flag)
	}
	return unique
}

type sprintTDDContract struct {
	Required      bool
	TestFramework string
	TestTodoList  []string
	SkipReason    *string
}

func detectSprintTDD(root string, task *sprintTaskRow) sprintTDDContract {
	framework := detectSprintTestFramework(root)
	contract := sprintTDDContract{
		TestFramework: framework,
		TestTodoList:  []string{},
		SkipReason:    nil,
	}
	text := fmt.Sprintf("%s\n%s", task.Title, task.DoD)

	if tddRequiredTagRe.MatchString(text) {
		contract.Required = true
		contract.TestTodoList = defaultSprintTDDTodoList()
		return contract
	}

	if match := tddSkipTagRe.FindStringSubmatch(text); len(match) >= 2 {
		reason := strings.TrimSpace(match[1])
		if reason == "" {
			reason = "unspecified"
		}
		contract.SkipReason = &reason
		return contract
	}

	paths := extractSprintMentionedPaths(text)
	if len(paths) == 0 {
		return contract
	}

	if sprintPathsAreDocsOnly(paths) {
		reason := "docs-only"
		contract.SkipReason = &reason
		return contract
	}

	if sprintPathsContainSource(paths) {
		if framework == "none" {
			reason := "no-test-framework-detected"
			contract.SkipReason = &reason
			return contract
		}
		contract.Required = true
		contract.TestTodoList = defaultSprintTDDTodoList()
		return contract
	}

	if framework == "none" {
		reason := "no-test-framework-detected"
		contract.SkipReason = &reason
	}
	return contract
}

func defaultSprintTDDTodoList() []string {
	return []string{"normal", "boundary", "error"}
}

func extractSprintMentionedPaths(text string) []string {
	seen := map[string]struct{}{}
	paths := []string{}
	add := func(raw string) {
		path := cleanSprintMentionedPath(raw)
		if path == "" || strings.ContainsAny(path, " \t\r\n") {
			return
		}
		if !looksLikeSprintPath(path) {
			return
		}
		if _, ok := seen[path]; ok {
			return
		}
		seen[path] = struct{}{}
		paths = append(paths, path)
	}

	for _, match := range pathInBackticksRe.FindAllStringSubmatch(text, -1) {
		if len(match) >= 2 {
			add(match[1])
		}
	}
	for _, match := range sprintPathTokenRe.FindAllStringSubmatch(text, -1) {
		if len(match) >= 2 {
			add(match[1])
		}
	}

	return paths
}

func cleanSprintMentionedPath(path string) string {
	trimmed := strings.TrimSpace(path)
	trimmed = strings.Trim(trimmed, "`'\".,;:()[]{}<>")
	return strings.TrimPrefix(trimmed, "./")
}

func looksLikeSprintPath(path string) bool {
	prefixes := []string{
		".claude/",
		"src/",
		"app/",
		"cmd/",
		"go/",
		"lib/",
		"pkg/",
		"internal/",
		"docs/",
		"scripts/",
		"tests/",
		"agents/",
		"skills/",
		"hooks/",
		"templates/",
		"frontend/",
		"mcp-server/",
		"harness-ui/",
	}
	for _, prefix := range prefixes {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	return false
}

func sprintPathsAreDocsOnly(paths []string) bool {
	if len(paths) == 0 {
		return false
	}
	for _, path := range paths {
		if strings.HasPrefix(path, "docs/") || strings.HasPrefix(path, "scripts/") || strings.HasPrefix(path, ".claude/") {
			continue
		}
		return false
	}
	return true
}

func sprintPathsContainSource(paths []string) bool {
	for _, path := range paths {
		if isSprintTestPath(path) {
			continue
		}
		if strings.HasPrefix(path, "src/") ||
			strings.HasPrefix(path, "app/") ||
			strings.HasPrefix(path, "cmd/") ||
			strings.HasPrefix(path, "go/") ||
			strings.HasPrefix(path, "lib/") ||
			strings.HasPrefix(path, "pkg/") ||
			strings.HasPrefix(path, "internal/") {
			return true
		}
	}
	return false
}

func isSprintTestPath(path string) bool {
	return strings.HasPrefix(path, "tests/") ||
		strings.Contains(path, "/tests/") ||
		strings.Contains(path, "/__tests__/") ||
		strings.HasSuffix(path, "_test.go") ||
		strings.Contains(path, ".test.") ||
		strings.Contains(path, ".spec.")
}

func detectSprintTestFramework(root string) string {
	if hasAnyFile(root, "vitest.config.ts", "vitest.config.js", "vitest.config.mjs") {
		return "vitest"
	}
	if hasAnyFile(root, "jest.config.js", "jest.config.ts", "jest.config.mjs") {
		return "jest"
	}
	if framework := detectSprintPackageJSONFramework(filepath.Join(root, "package.json")); framework != "" {
		return framework
	}
	if _, err := os.Stat(filepath.Join(root, "go.mod")); err == nil {
		return "go"
	}
	if sprintPytestDetected(root) {
		return "pytest"
	}
	if _, err := os.Stat(filepath.Join(root, "Cargo.toml")); err == nil {
		return "cargo"
	}
	return "none"
}

func detectSprintPackageJSONFramework(packageJSONPath string) string {
	data, err := os.ReadFile(packageJSONPath)
	if err != nil {
		return ""
	}
	var pkg struct {
		Scripts         map[string]string `json:"scripts"`
		Dependencies    map[string]string `json:"dependencies"`
		DevDependencies map[string]string `json:"devDependencies"`
	}
	if err := json.Unmarshal(data, &pkg); err != nil {
		return ""
	}
	if testScript := strings.TrimSpace(pkg.Scripts["test"]); testScript != "" && testScript != `echo "Error: no test specified" && exit 1` {
		lower := strings.ToLower(testScript)
		switch {
		case strings.Contains(lower, "vitest"):
			return "vitest"
		case strings.Contains(lower, "jest"):
			return "jest"
		default:
			return "npm"
		}
	}
	if _, ok := pkg.DevDependencies["vitest"]; ok {
		return "vitest"
	}
	if _, ok := pkg.Dependencies["vitest"]; ok {
		return "vitest"
	}
	if _, ok := pkg.DevDependencies["jest"]; ok {
		return "jest"
	}
	if _, ok := pkg.Dependencies["jest"]; ok {
		return "jest"
	}
	return ""
}

func sprintPytestDetected(root string) bool {
	if _, err := os.Stat(filepath.Join(root, "pytest.ini")); err == nil {
		return true
	}
	if setupCfg, err := os.ReadFile(filepath.Join(root, "setup.cfg")); err == nil {
		text := string(setupCfg)
		if strings.Contains(text, "[tool:pytest]") || strings.Contains(text, "[pytest]") {
			return true
		}
	}
	if pyproject, err := os.ReadFile(filepath.Join(root, "pyproject.toml")); err == nil {
		if strings.Contains(strings.ToLower(string(pyproject)), "pytest") {
			return true
		}
	}
	return false
}

func hasAnyFile(root string, names ...string) bool {
	for _, name := range names {
		if _, err := os.Stat(filepath.Join(root, name)); err == nil {
			return true
		}
	}
	return false
}

func buildSprintAdvisor(task *sprintTaskRow, riskFlags []string) sprintContractAdvisor {
	advisor := defaultSprintAdvisor
	advisor.Triggers = detectSprintAdvisorTriggers(task, riskFlags)
	return advisor
}

func detectSprintAdvisorTriggers(task *sprintTaskRow, riskFlags []string) []string {
	riskSet := make(map[string]struct{}, len(riskFlags))
	for _, flag := range riskFlags {
		riskSet[flag] = struct{}{}
	}

	orderedTriggers := []string{}
	for _, candidate := range []string{"needs-spike", "security-sensitive", "state-migration"} {
		if _, ok := riskSet[candidate]; ok {
			orderedTriggers = append(orderedTriggers, candidate)
		}
	}

	text := fmt.Sprintf("%s\n%s", task.Title, task.DoD)
	if advisorRequiredRe.MatchString(text) {
		orderedTriggers = append(orderedTriggers, "<!-- advisor:required -->")
	}

	return orderedTriggers
}

func detectSprintBrowserRoute(task *sprintTaskRow, root, browserMode string) *string {
	text := fmt.Sprintf("%s\n%s", task.Title, task.DoD)
	match := explicitRouteRe.FindStringSubmatch(text)
	if len(match) >= 2 {
		value := strings.ToLower(match[1])
		return &value
	}
	if browserMode == "exploratory" {
		return nil
	}
	if hasPlaywrightBasis(root) {
		value := "playwright"
		return &value
	}
	return nil
}

func hasPlaywrightBasis(root string) bool {
	if os.Getenv("HARNESS_BROWSER_REVIEW_DISABLE_PLAYWRIGHT") != "" {
		return false
	}
	packageJSONPath := filepath.Join(root, "package.json")
	data, err := os.ReadFile(packageJSONPath)
	if err != nil {
		return false
	}

	var pkg struct {
		Scripts         map[string]string `json:"scripts"`
		Dependencies    map[string]string `json:"dependencies"`
		DevDependencies map[string]string `json:"devDependencies"`
	}
	if err := json.Unmarshal(data, &pkg); err != nil {
		return false
	}
	if _, ok := pkg.Scripts["test:e2e"]; ok {
		return true
	}
	if _, ok := pkg.Dependencies["playwright"]; ok {
		return true
	}
	if _, ok := pkg.DevDependencies["playwright"]; ok {
		return true
	}
	if _, ok := pkg.Dependencies["@playwright/test"]; ok {
		return true
	}
	if _, ok := pkg.DevDependencies["@playwright/test"]; ok {
		return true
	}
	return false
}

func pickRuntimeCommands(root string) []sprintValidation {
	commands := []sprintValidation{}

	packageJSONPath := filepath.Join(root, "package.json")
	if data, err := os.ReadFile(packageJSONPath); err == nil {
		var pkg struct {
			Scripts map[string]string `json:"scripts"`
		}
		if err := json.Unmarshal(data, &pkg); err == nil {
			if _, ok := pkg.Scripts["test"]; ok {
				commands = append(commands, sprintValidation{Label: "package-test", Command: "CI=true npm test"})
			}
			if _, ok := pkg.Scripts["lint"]; ok {
				commands = append(commands, sprintValidation{Label: "package-lint", Command: "npm run lint"})
			}
			if _, ok := pkg.Scripts["typecheck"]; ok {
				commands = append(commands, sprintValidation{Label: "package-typecheck", Command: "npm run typecheck"})
			}
			if _, ok := pkg.Scripts["test:e2e"]; ok {
				commands = append(commands, sprintValidation{Label: "package-e2e", Command: "npm run test:e2e"})
			}
		} else {
			commands = append(commands, sprintValidation{
				Label:   "package-parse-error",
				Command: fmt.Sprintf("echo \"ERROR: package.json parse failed: %s\" >&2; exit 1", strings.ReplaceAll(err.Error(), `"`, `\"`)),
			})
		}
	}

	if len(commands) == 0 {
		fallbacks := []struct {
			Marker  string
			Label   string
			Command string
		}{
			{Marker: "pnpm-lock.yaml", Label: "pnpm-test", Command: "pnpm test"},
			{Marker: "bun.lock", Label: "bun-test", Command: "bun test"},
			{Marker: "go.mod", Label: "go-test", Command: "go test ./..."},
			{Marker: "Cargo.toml", Label: "cargo-test", Command: "cargo test"},
		}
		for _, fallback := range fallbacks {
			if _, err := os.Stat(filepath.Join(root, fallback.Marker)); err == nil {
				commands = append(commands, sprintValidation{Label: fallback.Label, Command: fallback.Command})
				break
			}
		}
	}

	if len(commands) == 0 {
		shellFallbacks := []struct {
			Path    string
			Label   string
			Command string
		}{
			{Path: "tests/validate-plugin.sh", Label: "validate-plugin", Command: "./tests/validate-plugin.sh"},
			{Path: "scripts/ci/check-consistency.sh", Label: "check-consistency", Command: "./scripts/ci/check-consistency.sh"},
		}
		for _, fallback := range shellFallbacks {
			if _, err := os.Stat(filepath.Join(root, fallback.Path)); err == nil {
				commands = append(commands, sprintValidation{Label: fallback.Label, Command: fallback.Command})
			}
		}
	}

	return commands
}

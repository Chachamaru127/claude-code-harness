package guardrail

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/auditlog"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

const (
	planPreapprovalSchemaVersion  = "plan-preapproval.v2"
	defaultPlanPreapprovalMaxUses = 10
)

var planPreapprovalPlaceholderPattern = regexp.MustCompile(`<[^<>\s]+>`)
var planPreapprovalStateWriter = writePlanPreapprovalState

type activeTaskScope struct {
	Phase string `json:"phase"`
	Task  string `json:"task"`
}

type planPreapprovalState struct {
	SchemaVersion string                    `json:"schema_version"`
	ApprovedAt    string                    `json:"approved_at"`
	Approvals     []planPreapprovalApproval `json:"approvals"`
}

type planPreapprovalApproval struct {
	Item       string          `json:"item"`
	Reason     string          `json:"reason"`
	Scope      activeTaskScope `json:"scope"`
	Operations []string        `json:"operations"`
	Paths      *[]string       `json:"paths,omitempty"`
	Commands   *[]string       `json:"commands,omitempty"`
	Targets    *[]string       `json:"targets,omitempty"`
	Decision   string          `json:"decision"`
	ApprovedAt string          `json:"approved_at"`
	ExpiresAt  string          `json:"expires_at"`
	MaxUses    *int            `json:"max_uses,omitempty"`
	Uses       *int            `json:"uses,omitempty"`
	ApprovedBy *string         `json:"approved_by,omitempty"`
}

func (approval *planPreapprovalApproval) UnmarshalJSON(data []byte) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return err
	}
	if fields == nil {
		return errors.New("approval must be an object")
	}
	for _, name := range []string{
		"paths", "commands", "targets", "max_uses", "uses", "approved_by",
	} {
		if raw, present := fields[name]; present && bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
			return fmt.Errorf("%s must not be null", name)
		}
	}

	type plainApproval planPreapprovalApproval
	var decoded plainApproval
	if err := decodeStrictJSON(data, &decoded); err != nil {
		return err
	}
	*approval = planPreapprovalApproval(decoded)
	return nil
}

func newPlanPreapprovalConsumer(projectRoot string, input hookproto.HookInput) func(string, string) bool {
	return func(operation, command string) bool {
		allowed, writeErr := consumePlanPreapproval(projectRoot, operation, command)
		if writeErr != nil {
			// Usage persistence is observability/accounting only after a valid
			// scoped approval has been proven. Do not re-block the approved
			// operation, but leave a command-hash-only audit warning.
			auditlog.Record(projectRoot, input, hookproto.HookResult{
				Decision:      hookproto.DecisionApprove,
				SystemMessage: "plan-preapproval usage write failed",
				RuleID:        "R12:plan-preapproval-usage-write-failed",
			})
		}
		return allowed
	}
}

func consumePlanPreapproval(projectRoot, operation, command string) (bool, error) {
	scope, ok := resolveActiveTaskScope(projectRoot)
	if !ok {
		return false, nil
	}

	statePath := filepath.Join(projectRoot, ".claude", "state", "plan-preapprovals.json")
	if _, err := os.Stat(statePath); err != nil {
		return false, nil
	}

	allowed := false
	var writeErr error
	lockErr := auditlog.WithFileLock(statePath+".lock", func() error {
		data, err := os.ReadFile(statePath)
		if err != nil {
			return err
		}
		state, err := decodePlanPreapprovalState(data)
		if err != nil {
			return err
		}

		now := time.Now()
		for index := range state.Approvals {
			approval := &state.Approvals[index]
			if !approvalAllowsCommand(*approval, scope, operation, command, now) {
				continue
			}

			allowed = true
			uses := planPreapprovalUses(*approval) + 1
			approval.Uses = &uses
			if err := planPreapprovalStateWriter(statePath, state); err != nil {
				writeErr = err
			}
			return nil
		}
		return nil
	})
	if lockErr != nil {
		return false, nil
	}
	return allowed, writeErr
}

func resolveActiveTaskScope(projectRoot string) (activeTaskScope, bool) {
	activeTaskPath := filepath.Join(projectRoot, ".claude", "state", "active-task.json")
	data, err := os.ReadFile(activeTaskPath)
	switch {
	case err == nil:
		var scope activeTaskScope
		if err := decodeStrictJSON(data, &scope); err != nil {
			return activeTaskScope{}, false
		}
		scope.Phase = strings.TrimSpace(scope.Phase)
		scope.Task = strings.TrimSpace(scope.Task)
		if scope.Phase == "" || scope.Task == "" {
			return activeTaskScope{}, false
		}
		return scope, true
	case !errors.Is(err, os.ErrNotExist):
		return activeTaskScope{}, false
	}

	scope := activeTaskScope{
		Phase: strings.TrimSpace(os.Getenv("HARNESS_ACTIVE_PHASE")),
		Task:  strings.TrimSpace(os.Getenv("HARNESS_ACTIVE_TASK")),
	}
	if scope.Phase == "" || scope.Task == "" {
		return activeTaskScope{}, false
	}
	return scope, true
}

func decodePlanPreapprovalState(data []byte) (planPreapprovalState, error) {
	var state planPreapprovalState
	if err := decodeStrictJSON(data, &state); err != nil {
		return planPreapprovalState{}, err
	}

	var rootFields map[string]json.RawMessage
	if err := json.Unmarshal(data, &rootFields); err != nil {
		return planPreapprovalState{}, err
	}
	if raw, ok := rootFields["approvals"]; !ok || bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return planPreapprovalState{}, errors.New("approvals must be an array")
	}
	if state.SchemaVersion != planPreapprovalSchemaVersion {
		return planPreapprovalState{}, fmt.Errorf("unsupported schema_version %q", state.SchemaVersion)
	}
	if !isRFC3339(state.ApprovedAt) {
		return planPreapprovalState{}, errors.New("approved_at must be RFC3339")
	}
	for index := range state.Approvals {
		if err := validatePlanPreapprovalApproval(state.Approvals[index]); err != nil {
			return planPreapprovalState{}, fmt.Errorf("approvals[%d]: %w", index, err)
		}
	}
	return state, nil
}

func decodeStrictJSON(data []byte, target interface{}) error {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("multiple JSON values")
		}
		return err
	}
	return nil
}

func validatePlanPreapprovalApproval(approval planPreapprovalApproval) error {
	if approval.Item == "" || approval.Reason == "" {
		return errors.New("item and reason must be non-empty")
	}
	if approval.Scope.Phase == "" || approval.Scope.Task == "" {
		return errors.New("scope phase and task must be non-empty")
	}
	if len(approval.Operations) == 0 {
		return errors.New("operations must be non-empty")
	}
	seenOperations := make(map[string]struct{}, len(approval.Operations))
	for _, operation := range approval.Operations {
		switch operation {
		case "secret-read", "external-send", "destructive":
		default:
			return fmt.Errorf("unsupported operation %q", operation)
		}
		if _, duplicate := seenOperations[operation]; duplicate {
			return fmt.Errorf("duplicate operation %q", operation)
		}
		seenOperations[operation] = struct{}{}
	}
	if approval.Paths == nil && approval.Commands == nil && approval.Targets == nil {
		return errors.New("paths, commands, or targets is required")
	}
	for name, values := range map[string]*[]string{
		"paths": approval.Paths, "commands": approval.Commands, "targets": approval.Targets,
	} {
		if values == nil {
			continue
		}
		for _, value := range *values {
			if value == "" {
				return fmt.Errorf("%s values must be non-empty", name)
			}
		}
	}
	if approval.Decision != "approved" && approval.Decision != "denied" {
		return fmt.Errorf("invalid decision %q", approval.Decision)
	}
	if !isRFC3339(approval.ApprovedAt) || !isRFC3339(approval.ExpiresAt) {
		return errors.New("approved_at and expires_at must be RFC3339")
	}
	if approval.MaxUses != nil && *approval.MaxUses < 1 {
		return errors.New("max_uses must be at least 1")
	}
	if approval.Uses != nil && *approval.Uses < 0 {
		return errors.New("uses must be at least 0")
	}
	if approval.ApprovedBy != nil && *approval.ApprovedBy == "" {
		return errors.New("approved_by must be non-empty")
	}
	return nil
}

func isRFC3339(value string) bool {
	_, err := time.Parse(time.RFC3339, value)
	return err == nil
}

func approvalAllowsCommand(
	approval planPreapprovalApproval,
	scope activeTaskScope,
	operation string,
	command string,
	now time.Time,
) bool {
	if approval.Decision != "approved" {
		return false
	}
	if approval.Scope != scope {
		return false
	}
	if !containsString(approval.Operations, operation) {
		return false
	}
	if approval.Commands == nil {
		return false
	}
	expiresAt, err := time.Parse(time.RFC3339, approval.ExpiresAt)
	if err != nil || !now.Before(expiresAt) {
		return false
	}
	if planPreapprovalUses(approval) >= planPreapprovalMaxUses(approval) {
		return false
	}
	for _, pattern := range *approval.Commands {
		if matchesPlanPreapprovalCommand(pattern, command) {
			return true
		}
	}
	return false
}

func planPreapprovalMaxUses(approval planPreapprovalApproval) int {
	if approval.MaxUses == nil {
		return defaultPlanPreapprovalMaxUses
	}
	return *approval.MaxUses
}

func planPreapprovalUses(approval planPreapprovalApproval) int {
	if approval.Uses == nil {
		return 0
	}
	return *approval.Uses
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func matchesPlanPreapprovalCommand(pattern, command string) bool {
	normalizedPattern := strings.Join(strings.Fields(pattern), " ")
	normalizedCommand := strings.Join(strings.Fields(command), " ")
	if normalizedPattern == "" || normalizedCommand == "" {
		return false
	}

	var expression strings.Builder
	expression.WriteByte('^')
	cursor := 0
	for _, location := range planPreapprovalPlaceholderPattern.FindAllStringIndex(normalizedPattern, -1) {
		expression.WriteString(regexp.QuoteMeta(normalizedPattern[cursor:location[0]]))
		expression.WriteString(`\S+`)
		cursor = location[1]
	}
	expression.WriteString(regexp.QuoteMeta(normalizedPattern[cursor:]))
	expression.WriteByte('$')

	matcher, err := regexp.Compile(expression.String())
	if err != nil {
		return false
	}
	return matcher.MatchString(normalizedCommand)
}

func writePlanPreapprovalState(path string, state planPreapprovalState) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	tempFile, err := os.CreateTemp(filepath.Dir(path), ".plan-preapprovals-*.tmp")
	if err != nil {
		return err
	}
	tempPath := tempFile.Name()
	defer os.Remove(tempPath)

	if err := tempFile.Chmod(0o600); err != nil {
		tempFile.Close()
		return err
	}
	if _, err := tempFile.Write(data); err != nil {
		tempFile.Close()
		return err
	}
	if err := tempFile.Close(); err != nil {
		return err
	}
	return os.Rename(tempPath, path)
}

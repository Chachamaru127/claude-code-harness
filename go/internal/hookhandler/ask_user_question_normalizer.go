package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sort"
	"strings"
)

type askUserQuestionHookInput struct {
	SessionID string                 `json:"session_id,omitempty"`
	CWD       string                 `json:"cwd,omitempty"`
	ToolName  string                 `json:"tool_name"`
	ToolInput map[string]interface{} `json:"tool_input"`
}

type askUserQuestionPreToolOutput struct {
	HookSpecificOutput struct {
		HookEventName            string          `json:"hookEventName"`
		PermissionDecision       string          `json:"permissionDecision"`
		PermissionDecisionReason string          `json:"permissionDecisionReason,omitempty"`
		UpdatedInput             json.RawMessage `json:"updatedInput,omitempty"`
		AdditionalContext        string          `json:"additionalContext,omitempty"`
	} `json:"hookSpecificOutput"`
}

var askQuestionCanonicalValues = map[string]string{
	"solo":                "solo",
	"single":              "solo",
	"individual":          "solo",
	"個人":                  "solo",
	"単独":                  "solo",
	"team":                "team",
	"issue":               "team",
	"github issue":        "team",
	"github-issue":        "team",
	"github_issue":        "team",
	"チーム":                 "team",
	"exploratory":         "exploratory",
	"browser exploratory": "exploratory",
	"explore":             "exploratory",
	"探索":                  "exploratory",
	"触って確認":               "exploratory",
	"scripted":            "scripted",
	"browser scripted":    "scripted",
	"playwright":          "scripted",
	"手順固定":                "scripted",
	"patch":               "patch",
	"minor":               "minor",
	"major":               "major",
}

// HandleAskUserQuestionNormalize supplies AskUserQuestion answers only when an
// explicit answer source exists. It never invents approvals, yes/no decisions,
// or free-form values.
func HandleAskUserQuestionNormalize(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return nil
	}

	var input askUserQuestionHookInput
	if err := json.Unmarshal(data, &input); err != nil {
		return nil
	}
	if input.ToolName != "AskUserQuestion" || input.ToolInput == nil {
		return nil
	}

	questions := extractAskQuestionOptions(input.ToolInput["questions"])
	if len(questions) == 0 {
		return nil
	}

	rawAnswers, ok := collectAskQuestionAnswers(input.ToolInput)
	if !ok {
		return nil
	}

	normalized, changed, ok := normalizeAskQuestionAnswers(rawAnswers, questions)
	if !ok || len(normalized) == 0 {
		return nil
	}

	updatedInput := cloneMap(input.ToolInput)
	updatedInput["answers"] = normalized
	updatedBytes, err := json.Marshal(updatedInput)
	if err != nil {
		return nil
	}

	var outObj askUserQuestionPreToolOutput
	outObj.HookSpecificOutput.HookEventName = "PreToolUse"
	outObj.HookSpecificOutput.PermissionDecision = "allow"
	outObj.HookSpecificOutput.PermissionDecisionReason = "Harness supplied AskUserQuestion answers from an explicit source"
	outObj.HookSpecificOutput.UpdatedInput = updatedBytes
	outObj.HookSpecificOutput.AdditionalContext = askQuestionTraceContext(normalized, changed)

	outBytes, err := json.Marshal(outObj)
	if err != nil {
		return fmt.Errorf("marshaling ask user question output: %w", err)
	}
	_, err = fmt.Fprintf(out, "%s\n", outBytes)
	return err
}

type askQuestionOptionSet struct {
	labels       map[string]string
	canonicalMap map[string]string
	multiSelect  bool
}

func extractAskQuestionOptions(raw interface{}) map[string]askQuestionOptionSet {
	questions, ok := raw.([]interface{})
	if !ok {
		return nil
	}

	result := make(map[string]askQuestionOptionSet)
	for _, item := range questions {
		q, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		question, _ := q["question"].(string)
		if question == "" {
			continue
		}

		optionSet := askQuestionOptionSet{
			labels:       make(map[string]string),
			canonicalMap: make(map[string]string),
		}
		if ms, ok := q["multiSelect"].(bool); ok {
			optionSet.multiSelect = ms
		}
		if options, ok := q["options"].([]interface{}); ok {
			for _, opt := range options {
				label := askQuestionOptionLabel(opt)
				if label == "" {
					continue
				}
				optionSet.labels[label] = label
				if canonical, ok := canonicalAskQuestionValue(label); ok {
					optionSet.canonicalMap[canonical] = label
				}
			}
		}
		result[question] = optionSet
	}
	return result
}

func askQuestionOptionLabel(opt interface{}) string {
	switch v := opt.(type) {
	case string:
		return v
	case map[string]interface{}:
		if label, ok := v["label"].(string); ok {
			return label
		}
	}
	return ""
}

func collectAskQuestionAnswers(toolInput map[string]interface{}) (map[string]string, bool) {
	if answers, ok := mapStringAnswers(toolInput["answers"]); ok {
		return answers, true
	}

	env := strings.TrimSpace(os.Getenv("HARNESS_ASK_USER_QUESTION_ANSWERS"))
	if env == "" {
		return nil, false
	}
	var raw map[string]interface{}
	if err := json.Unmarshal([]byte(env), &raw); err != nil {
		return nil, false
	}
	return mapStringAnswers(raw)
}

func mapStringAnswers(raw interface{}) (map[string]string, bool) {
	obj, ok := raw.(map[string]interface{})
	if !ok {
		return nil, false
	}

	answers := make(map[string]string)
	for k, v := range obj {
		switch value := v.(type) {
		case string:
			if strings.TrimSpace(value) != "" {
				answers[k] = value
			}
		case []interface{}:
			parts := make([]string, 0, len(value))
			for _, item := range value {
				s, ok := item.(string)
				if !ok || strings.TrimSpace(s) == "" {
					return nil, false
				}
				parts = append(parts, s)
			}
			if len(parts) > 0 {
				answers[k] = strings.Join(parts, ", ")
			}
		default:
			return nil, false
		}
	}
	return answers, len(answers) > 0
}

func normalizeAskQuestionAnswers(rawAnswers map[string]string, questions map[string]askQuestionOptionSet) (map[string]string, bool, bool) {
	normalized := make(map[string]string)
	changed := false

	for question, rawAnswer := range rawAnswers {
		optionSet, ok := questions[question]
		if !ok {
			continue
		}
		answer, answerChanged, ok := normalizeAskQuestionAnswer(rawAnswer, optionSet)
		if !ok {
			return nil, false, false
		}
		normalized[question] = answer
		if answerChanged {
			changed = true
		}
	}

	return normalized, changed, true
}

func normalizeAskQuestionAnswer(raw string, options askQuestionOptionSet) (string, bool, bool) {
	parts := splitAnswerParts(raw)
	if len(parts) == 0 {
		return "", false, false
	}
	if len(parts) > 1 && !options.multiSelect {
		return "", false, false
	}
	normalizedParts := make([]string, 0, len(parts))
	changed := false

	for _, part := range parts {
		normalized, partChanged, ok := normalizeAskQuestionPart(part, options)
		if !ok {
			return "", false, false
		}
		normalizedParts = append(normalizedParts, normalized)
		if partChanged {
			changed = true
		}
	}

	return strings.Join(normalizedParts, ", "), changed, true
}

func splitAnswerParts(raw string) []string {
	candidates := strings.Split(raw, ",")
	parts := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		trimmed := strings.TrimSpace(candidate)
		if trimmed != "" {
			parts = append(parts, trimmed)
		}
	}
	return parts
}

func normalizeAskQuestionPart(raw string, options askQuestionOptionSet) (string, bool, bool) {
	if raw == "" {
		return "", false, false
	}
	if label, ok := options.labels[raw]; ok {
		return label, false, true
	}

	canonical, hasCanonical := canonicalAskQuestionValue(raw)
	if !hasCanonical {
		if len(options.labels) == 0 {
			return raw, false, true
		}
		return "", false, false
	}
	if label, ok := options.canonicalMap[canonical]; ok {
		return label, label != raw, true
	}
	if len(options.labels) == 0 {
		return canonical, canonical != raw, true
	}
	return "", false, false
}

func canonicalAskQuestionValue(raw string) (string, bool) {
	key := strings.ToLower(strings.TrimSpace(raw))
	key = strings.Join(strings.Fields(key), " ")
	canonical, ok := askQuestionCanonicalValues[key]
	return canonical, ok
}

func askQuestionTraceContext(answers map[string]string, changed bool) string {
	keys := make([]string, 0, len(answers))
	for question := range answers {
		keys = append(keys, question)
	}
	sort.Strings(keys)

	state := "without changes"
	if changed {
		state = "with canonical normalization"
	}
	return fmt.Sprintf("Harness supplied AskUserQuestion answers %s for %d question(s): %s", state, len(keys), strings.Join(keys, ", "))
}

func cloneMap(src map[string]interface{}) map[string]interface{} {
	dst := make(map[string]interface{}, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}

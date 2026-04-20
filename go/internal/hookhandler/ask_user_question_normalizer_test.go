package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestHandleAskUserQuestionNormalize_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output, got %s", out.String())
	}
}

func TestHandleAskUserQuestionNormalize_NoExplicitAnswers(t *testing.T) {
	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Execution mode?","header":"Mode","options":[{"label":"solo"},{"label":"team"}]}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output without explicit answers, got %s", out.String())
	}
}

func TestHandleAskUserQuestionNormalize_EnvAnswersCanonicalizedToOptionLabel(t *testing.T) {
	t.Setenv("HARNESS_ASK_USER_QUESTION_ANSWERS", `{"Execution mode?":"個人"}`)

	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Execution mode?","header":"Mode","options":[{"label":"solo"},{"label":"team"}],"multiSelect":false}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	hso := decodeAskQuestionHookSpecific(t, out.Bytes())
	if hso["permissionDecision"] != "allow" {
		t.Fatalf("permissionDecision = %v, want allow", hso["permissionDecision"])
	}
	updatedInput := hso["updatedInput"].(map[string]interface{})
	answers := updatedInput["answers"].(map[string]interface{})
	if answers["Execution mode?"] != "solo" {
		t.Fatalf("answer = %v, want solo", answers["Execution mode?"])
	}
	if _, ok := updatedInput["questions"].([]interface{}); !ok {
		t.Fatalf("questions must be echoed back in updatedInput")
	}
	if !strings.Contains(hso["additionalContext"].(string), "canonical normalization") {
		t.Fatalf("expected trace context to mention canonical normalization, got %v", hso["additionalContext"])
	}
}

func TestHandleAskUserQuestionNormalize_ExistingAnswerPreserved(t *testing.T) {
	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Release bump?","header":"Bump","options":[{"label":"patch"},{"label":"minor"},{"label":"major"}]}],
			"answers":{"Release bump?":"minor"}
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	hso := decodeAskQuestionHookSpecific(t, out.Bytes())
	updatedInput := hso["updatedInput"].(map[string]interface{})
	answers := updatedInput["answers"].(map[string]interface{})
	if answers["Release bump?"] != "minor" {
		t.Fatalf("answer = %v, want minor", answers["Release bump?"])
	}
	if !strings.Contains(hso["additionalContext"].(string), "without changes") {
		t.Fatalf("expected trace context to mention no changes, got %v", hso["additionalContext"])
	}
}

func TestHandleAskUserQuestionNormalize_InvalidAnswerDoesNotAutoAnswer(t *testing.T) {
	t.Setenv("HARNESS_ASK_USER_QUESTION_ANSWERS", `{"Execution mode?":"approve"}`)

	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Execution mode?","header":"Mode","options":[{"label":"solo"},{"label":"team"}]}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output for invalid answer, got %s", out.String())
	}
}

func TestHandleAskUserQuestionNormalize_MultiSelectAnswers(t *testing.T) {
	t.Setenv("HARNESS_ASK_USER_QUESTION_ANSWERS", `{"Workflow style?":["探索","playwright"]}`)

	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Workflow style?","header":"Style","options":[{"label":"exploratory"},{"label":"scripted"}],"multiSelect":true}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	hso := decodeAskQuestionHookSpecific(t, out.Bytes())
	updatedInput := hso["updatedInput"].(map[string]interface{})
	answers := updatedInput["answers"].(map[string]interface{})
	if answers["Workflow style?"] != "exploratory, scripted" {
		t.Fatalf("answer = %v, want exploratory, scripted", answers["Workflow style?"])
	}
}

func TestHandleAskUserQuestionNormalize_MultiValueRejectedForSingleSelect(t *testing.T) {
	t.Setenv("HARNESS_ASK_USER_QUESTION_ANSWERS", `{"Workflow style?":["探索","playwright"]}`)

	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Workflow style?","header":"Style","options":[{"label":"exploratory"},{"label":"scripted"}],"multiSelect":false}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output when single-select receives multi-value answer, got %s", out.String())
	}
}

func TestHandleAskUserQuestionNormalize_IgnoresStaleEnvAnswers(t *testing.T) {
	t.Setenv("HARNESS_ASK_USER_QUESTION_ANSWERS", `{"Other question?":"solo"}`)

	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Execution mode?","header":"Mode","options":[{"label":"solo"},{"label":"team"}]}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output for stale answer key, got %s", out.String())
	}
}

func TestHandleAskUserQuestionNormalize_MalformedEnvFailsOpen(t *testing.T) {
	os.Setenv("HARNESS_ASK_USER_QUESTION_ANSWERS", `{not-json`)
	t.Cleanup(func() { os.Unsetenv("HARNESS_ASK_USER_QUESTION_ANSWERS") })

	input := `{
		"tool_name":"AskUserQuestion",
		"tool_input":{
			"questions":[{"question":"Execution mode?","header":"Mode","options":[{"label":"solo"},{"label":"team"}]}]
		}
	}`

	var out bytes.Buffer
	if err := HandleAskUserQuestionNormalize(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output for malformed env, got %s", out.String())
	}
}

func decodeAskQuestionHookSpecific(t *testing.T, data []byte) map[string]interface{} {
	t.Helper()
	var decoded map[string]interface{}
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("output is not valid JSON: %v\n%s", err, string(data))
	}
	hso, ok := decoded["hookSpecificOutput"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing hookSpecificOutput in %s", string(data))
	}
	if hso["hookEventName"] != "PreToolUse" {
		t.Fatalf("hookEventName = %v, want PreToolUse", hso["hookEventName"])
	}
	return hso
}

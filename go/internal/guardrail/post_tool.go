package guardrail

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// ---------------------------------------------------------------------------
// Security risk patterns (ported from post-tool.ts detectSecurityRisks)
// ---------------------------------------------------------------------------

type securityPattern struct {
	Pattern *regexp.Regexp
	Message string
}

var securityPatterns = []securityPattern{
	{
		Pattern: regexp.MustCompile(`(?i)process\.env\.[A-Z_]+.*(?:password|secret|key|token)`),
		Message: "Sensitive data may be embedded directly from an environment variable into a string",
	},
	{
		Pattern: regexp.MustCompile(`(?i)eval\s*\(\s*(?:request|req|input|param|query)`),
		Message: "Detected code passing user input to eval() (RCE risk)",
	},
	{
		Pattern: regexp.MustCompile(`exec\s*\(\s*` + "`" + `[^` + "`" + `]*\$\{`),
		Message: "Detected code passing a template literal to exec() (command injection risk)",
	},
	{
		Pattern: regexp.MustCompile(`innerHTML\s*=\s*(?:.*\+.*|` + "`" + `[^` + "`" + `]*\$\{)`),
		Message: "Detected code assigning user input to innerHTML (XSS risk)",
	},
	{
		Pattern: regexp.MustCompile(`(?i)(?:password|passwd|secret|api_key|apikey)\s*=\s*["'][^"']{8,}["']`),
		Message: "Detected a hardcoded secret (password / API key)",
	},
}

func detectSecurityRisks(content string) []string {
	var warnings []string
	for _, sp := range securityPatterns {
		if sp.Pattern.MatchString(content) {
			warnings = append(warnings, sp.Message)
		}
	}
	return warnings
}

// ---------------------------------------------------------------------------
// EvaluatePostTool — PostToolUse hook entry point
// ---------------------------------------------------------------------------

// EvaluatePostTool evaluates post-tool checks (tampering detection + security review).
// Only Write/Edit/MultiEdit are inspected; all other tools get immediate approve.
func EvaluatePostTool(input hookproto.HookInput) hookproto.HookResult {
	if !matchesWriteEditMultiEdit(input.ToolName) {
		return hookproto.HookResult{Decision: hookproto.DecisionApprove}
	}

	var systemMessages []string

	// Tampering detection
	filePath, _ := getStringField(input.ToolInput, "file_path")
	if filePath != "" {
		isTest := isTestFile(filePath)
		isConfig := isConfigFile(filePath)

		if isTest || isConfig {
			content := getChangedContent(input.ToolInput)
			if content != "" {
				warnings := detectTampering(content, isTest)
				if len(warnings) > 0 {
					fileType := "test file"
					if !isTest {
						fileType = "CI/config file"
					}
					var lines []string
					for _, w := range warnings {
						lines = append(lines, fmt.Sprintf("- [%s] %s\n  location: %s", w.PatternID, w.Description, w.MatchedText))
					}
					msg := fmt.Sprintf("[v4] Test-tampering warning\n\nSuspicious patterns detected in %s `%s`:\n\n%s\n\n[Please review]\nConfirm this change does not intentionally disable tests or reduce implementation quality.\nIf you determine it is tampering, revert the change.",
						fileType, filePath, strings.Join(lines, "\n"))
					systemMessages = append(systemMessages, msg)
				}
			}
		}
	}

	// Security risk detection
	content := getChangedContent(input.ToolInput)
	if content != "" {
		secWarnings := detectSecurityRisks(content)
		if len(secWarnings) > 0 {
			var lines []string
			for _, w := range secWarnings {
				lines = append(lines, fmt.Sprintf("- %s", w))
			}
			msg := fmt.Sprintf("[v4] Security risk detected:\n%s", strings.Join(lines, "\n"))
			systemMessages = append(systemMessages, msg)
		}
	}

	if len(systemMessages) == 0 {
		return hookproto.HookResult{Decision: hookproto.DecisionApprove}
	}

	return hookproto.HookResult{
		Decision:      hookproto.DecisionApprove,
		SystemMessage: strings.Join(systemMessages, "\n\n---\n\n"),
	}
}

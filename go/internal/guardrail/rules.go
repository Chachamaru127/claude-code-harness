// Package guard implements the Harness v4 declarative guardrail rules engine.
//
// Each rule is a (toolPattern, evaluate) pair evaluated in order;
// the first match wins (short-circuit).
package guardrail

import (
	"fmt"
	"regexp"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// GuardRule is a single declarative guard rule.
type GuardRule struct {
	ID          string
	ToolPattern *regexp.Regexp
	Evaluate    func(ctx hookproto.RuleContext) *hookproto.HookResult
}

// Pre-compiled patterns for R03 (shell write to protected paths)
var r03ShellWritePatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?:>>?|tee)\s+\S*\.env\b`),
	regexp.MustCompile(`(?:>>?|tee)\s+\S*\.env\.`),
	regexp.MustCompile(`(?:>>?|tee)\s+\S*\.git/`),
	regexp.MustCompile(`(?:>>?|tee)\s+\S*id_rsa\b`),
	regexp.MustCompile(`(?:>>?|tee)\s+\S*id_ed25519\b`),
	regexp.MustCompile(`(?:>>?|tee)\s+\S*\.pem\b`),
	regexp.MustCompile(`(?:>>?|tee)\s+\S*\.key\b`),
}

// Pre-compiled patterns for R08 (breezing reviewer prohibited commands)
var r08ReviewerProhibitedPatterns = []*regexp.Regexp{
	regexp.MustCompile(`\bgit\s+(?:commit|push|reset|checkout|merge|rebase)\b`),
	regexp.MustCompile(`\brm\s+`),
	regexp.MustCompile(`\bmv\s+`),
	regexp.MustCompile(`\bcp\s+.*-r\b`),
}

// Pre-compiled patterns for R09 (secret file detection)
var r09SecretPatterns = []*regexp.Regexp{
	regexp.MustCompile(`\.env$`),
	regexp.MustCompile(`id_rsa$`),
	regexp.MustCompile(`\.pem$`),
	regexp.MustCompile(`\.key$`),
	regexp.MustCompile(`secrets?/`),
}

// Rules is the ordered table of all guard rules.
var Rules = []GuardRule{
	// R01: sudo block (Bash)
	{
		ID:          "R01:no-sudo",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			if !hasSudo(command) {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "sudo の使用は禁止されています。必要な場合はユーザーに手動実行を依頼してください。",
			}
		},
	},

	// R02: protected path write block (Write/Edit/MultiEdit)
	{
		ID:          "R02:no-write-protected-paths",
		ToolPattern: regexp.MustCompile(`^(?:Write|Edit|MultiEdit)$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			filePath, ok := ctx.Input.ToolInput["file_path"].(string)
			if !ok {
				return nil
			}
			if !isProtectedPath(filePath) {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   fmt.Sprintf("保護されたパスへの書き込みは禁止されています: %s", filePath),
			}
		},
	},

	// R03: Bash write to protected paths block
	{
		ID:          "R03:no-bash-write-protected-paths",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			for _, p := range r03ShellWritePatterns {
				if p.MatchString(command) {
					return &hookproto.HookResult{
						Decision: hookproto.DecisionDeny,
						Reason:   "保護されたファイルへのシェル書き込みは禁止されています。",
					}
				}
			}
			return nil
		},
	},

	// R04: confirm write outside project root
	{
		ID:          "R04:confirm-write-outside-project",
		ToolPattern: regexp.MustCompile(`^(?:Write|Edit|MultiEdit)$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			filePath, ok := ctx.Input.ToolInput["file_path"].(string)
			if !ok {
				return nil
			}
			if isUnderProjectRoot(filePath, ctx.ProjectRoot) {
				return nil
			}
			// Work mode skips confirmation
			if ctx.WorkMode {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionAsk,
				Reason:   fmt.Sprintf("プロジェクトルート外への書き込みです: %s\n許可しますか？", filePath),
			}
		},
	},

	// R05: confirm dangerous deletion commands
	{
		ID:          "R05:confirm-rm-rf",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			if !hasDangerousRmRf(command) {
				return nil
			}
			if ctx.WorkMode {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionAsk,
				Reason:   fmt.Sprintf("危険な削除コマンドを検出しました:\n%s\n実行しますか？", command),
			}
		},
	},

	// R06: git push --force block (no bypass even in work mode)
	{
		ID:          "R06:no-force-push",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			if !hasForcePush(command) {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "git push --force は禁止されています。履歴を破壊する操作は許可されません。",
			}
		},
	},

	// R07: Codex mode — no Write/Edit
	{
		ID:          "R07:codex-mode-no-write",
		ToolPattern: regexp.MustCompile(`^(?:Write|Edit|MultiEdit)$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			if !ctx.CodexMode {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "Codex モード中は Claude が直接ファイルを書き込めません。実装は Codex Worker (codex exec) に委譲してください。",
			}
		},
	},

	// R08: Breezing reviewer — no write operations
	{
		ID:          "R08:breezing-reviewer-no-write",
		ToolPattern: regexp.MustCompile(`^(?:Write|Edit|MultiEdit|Bash)$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			if ctx.BreezingRole != "reviewer" {
				return nil
			}
			toolName := ctx.Input.ToolName
			if toolName == "Bash" {
				command, ok := ctx.Input.ToolInput["command"].(string)
				if !ok {
					return nil
				}
				matched := false
				for _, p := range r08ReviewerProhibitedPatterns {
					if p.MatchString(command) {
						matched = true
						break
					}
				}
				if !matched {
					return nil
				}
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "Breezing reviewer ロールはファイル書き込みおよびデータ変更コマンドを実行できません。",
			}
		},
	},

	// R09: warn on secret file read
	{
		ID:          "R09:warn-secret-file-read",
		ToolPattern: regexp.MustCompile(`^Read$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			filePath, ok := ctx.Input.ToolInput["file_path"].(string)
			if !ok {
				return nil
			}
			for _, p := range r09SecretPatterns {
				if p.MatchString(filePath) {
					return &hookproto.HookResult{
						Decision:      hookproto.DecisionApprove,
						SystemMessage: fmt.Sprintf("警告: 機密情報が含まれる可能性のあるファイルを読み取っています: %s", filePath),
					}
				}
			}
			return nil
		},
	},

	// R10: --no-verify / --no-gpg-sign block
	{
		ID:          "R10:no-git-bypass-flags",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			if !hasDangerousGitBypassFlag(command) {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "--no-verify / --no-gpg-sign の使用は禁止されています。フックや署名検証を迂回しないでください。",
			}
		},
	},

	// R11: protected branch git reset --hard block
	{
		ID:          "R11:no-reset-hard-protected-branch",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			if !hasProtectedBranchResetHard(command) {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "protected branch への git reset --hard は禁止されています。履歴を壊さない方法を使ってください。",
			}
		},
	},

	// R12: deny direct push to protected branch
	{
		ID:          "R12:deny-direct-push-protected-branch",
		ToolPattern: regexp.MustCompile(`^Bash$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			command, ok := ctx.Input.ToolInput["command"].(string)
			if !ok {
				return nil
			}
			if !hasDirectPushToProtectedBranch(command) {
				return nil
			}
			return &hookproto.HookResult{
				Decision: hookproto.DecisionDeny,
				Reason:   "main/master への直接 push は禁止されています。feature branch 経由で PR を作成してください。",
			}
		},
	},

	// R13: warn on protected review paths (Write/Edit/MultiEdit)
	{
		ID:          "R13:warn-protected-review-paths",
		ToolPattern: regexp.MustCompile(`^(?:Write|Edit|MultiEdit)$`),
		Evaluate: func(ctx hookproto.RuleContext) *hookproto.HookResult {
			filePath, ok := ctx.Input.ToolInput["file_path"].(string)
			if !ok {
				return nil
			}
			if !isProtectedReviewPath(filePath) {
				return nil
			}
			return &hookproto.HookResult{
				Decision:      hookproto.DecisionApprove,
				SystemMessage: fmt.Sprintf("警告: 重要ファイルへの変更を検出しました: %s", filePath),
			}
		},
	},
}

// EvaluateRules evaluates all guard rules in order and returns the first match.
// If no rule matches, it returns approve.
func EvaluateRules(ctx hookproto.RuleContext) hookproto.HookResult {
	toolName := ctx.Input.ToolName
	for _, rule := range Rules {
		if !rule.ToolPattern.MatchString(toolName) {
			continue
		}
		if result := rule.Evaluate(ctx); result != nil {
			return *result
		}
	}
	return hookproto.HookResult{Decision: hookproto.DecisionApprove}
}

package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/harnessmem"
)

// setupInput は Setup フックの stdin JSON ペイロード。
type setupInput struct {
	HookEventName string `json:"hook_event_name"`
	SessionID     string `json:"session_id"`
	Mode          string `json:"mode"` // "init" または "maintenance"
}

// setupOutput は Setup フックのレスポンス形式。
type setupOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// writeSetupOutput は Setup フックのレスポンスを書き込む。
func writeSetupOutput(w io.Writer, message string) error {
	var out setupOutput
	out.HookSpecificOutput.HookEventName = "Setup"
	out.HookSpecificOutput.AdditionalContext = message
	return writeJSON(w, out)
}

// isSimpleMode は CLAUDE_CODE_SIMPLE 環境変数でシンプルモードを検出する。
// check-simple-mode.sh の is_simple_mode() 関数に対応。
func isSimpleMode() bool {
	val := strings.ToLower(os.Getenv("CLAUDE_CODE_SIMPLE"))
	return val == "1" || val == "true" || val == "yes"
}

// runSyncPluginCache はプラグインキャッシュ同期スクリプトを実行する（存在する場合）。
func runSyncPluginCache(scriptDir string) {
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		_ = cmd.Run() // エラーは無視
	}
}

// getPlansFilePath は設定から Plans.md のパスを取得する。
// helpers.go の resolvePlansPath() を使った Go ネイティブ実装。
// bash (config-utils.sh) への依存を排除している。
func getPlansFilePath(_ string) string {
	projectRoot := resolveProjectRoot()
	if path := resolvePlansPath(projectRoot); path != "" {
		return path
	}
	return filepath.Join(projectRoot, "Plans.md")
}

// runTemplateTracker はテンプレートトラッカースクリプトを実行する。
func runTemplateTracker(scriptDir, action string) string {
	trackerScript := filepath.Join(scriptDir, "template-tracker.sh")
	if _, err := os.Stat(trackerScript); err == nil {
		cmd := exec.Command("bash", trackerScript, action)
		if out, err := cmd.Output(); err == nil {
			return strings.TrimSpace(string(out))
		}
	}
	return ""
}

// HandleSetupHookInit は setup-hook.sh の init モードの Go 移植。
//
// 初回セットアップとして以下を実行する:
//  1. プラグインキャッシュの同期
//  2. .claude/state/ ディレクトリの初期化
//  3. デフォルト設定ファイルの生成（存在しない場合）
//  4. CLAUDE.md の生成（存在しない場合）
//  5. Plans.md の生成（存在しない場合）
//  6. テンプレートトラッカーの初期化
func HandleSetupHookInit(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "init")
}

// HandleSetupHookMaintenance は setup-hook.sh の maintenance モードの Go 移植。
//
// メンテナンス処理として以下を実行する:
//  1. プラグインキャッシュの同期
//  2. 7日以上の古いセッションアーカイブの削除
//  3. .tmp ファイルの削除
//  4. テンプレート更新チェック
//  5. 設定ファイルの YAML 構文検証
func HandleSetupHookMaintenance(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "maintenance")
}

// HandleSetupHook は setup-hook.sh 全体の Go 移植。
// stdin の JSON ペイロードまたは引数でモードを決定する。
func HandleSetupHook(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "")
}

// handleSetupHook は setup-hook.sh の内部実装。
// mode が空の場合は stdin ペイロードから決定する。
func handleSetupHook(in io.Reader, out io.Writer, mode string) error {
	// SIMPLE モード検出
	simpleMode := isSimpleMode()
	if simpleMode {
		fmt.Fprintf(os.Stderr, "[WARNING] CLAUDE_CODE_SIMPLE mode detected — skills/agents/memory disabled\n")
	}

	// stdin から JSON を読み取る（エラーは無視）
	data, _ := io.ReadAll(in)

	// ペイロードからモードを決定（引数が優先）
	if mode == "" {
		var input setupInput
		if len(data) > 0 {
			_ = json.Unmarshal(data, &input)
		}
		if input.Mode != "" {
			mode = input.Mode
		} else {
			mode = "init"
		}
	}

	// スクリプトディレクトリを推定（実行バイナリ基準。テスト時は cwd）
	scriptDir := resolveSetupScriptDir()

	switch mode {
	case "init":
		return runSetupInit(out, scriptDir, simpleMode)
	case "maintenance":
		return runSetupMaintenance(out, scriptDir, simpleMode)
	default:
		return writeSetupOutput(out, fmt.Sprintf("[Setup] 不明なモード: %s", mode))
	}
}

// resolveSetupScriptDir はスクリプトディレクトリのパスを解決する。
// フックは対象プロジェクトの CWD で実行されるため、CWD ベースの検索は
// harness のインストール先を指さない。以下の優先順位で解決する:
//
//  1. CLAUDE_PLUGIN_ROOT 環境変数（harness インストール先）
//  2. HARNESS_SCRIPT_DIR 環境変数（明示的なオーバーライド）
//  3. CWD（開発環境用フォールバック）
func resolveSetupScriptDir() string {
	if root := os.Getenv("CLAUDE_PLUGIN_ROOT"); root != "" {
		return filepath.Join(root, "scripts")
	}
	if dir := os.Getenv("HARNESS_SCRIPT_DIR"); dir != "" {
		return dir
	}
	// フォールバック: カレントディレクトリの scripts/（開発環境用）
	cwd, _ := os.Getwd()
	return filepath.Join(cwd, "scripts")
}

// runSetupInit は init モードの処理を実行する。
func runSetupInit(out io.Writer, scriptDir string, simpleMode bool) error {
	var messages []string

	// 1. プラグインキャッシュの同期
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		if err := cmd.Run(); err == nil {
			messages = append(messages, "プラグインキャッシュ同期完了")
		}
	}

	// 2. 状態ディレクトリの初期化
	stateDir := ".claude/state"
	if err := os.MkdirAll(stateDir, 0o755); err == nil {
		// 初期化成功（既存でも OK）
	}

	// 3. デフォルト設定ファイルの生成
	configFile := ".claude-code-harness.config.yaml"
	if !fileExists(configFile) {
		templatePath := filepath.Join(scriptDir, "..", "templates", ".claude-code-harness.config.yaml.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, configFile); err == nil {
				messages = append(messages, "設定ファイル生成完了")
			}
		}
	}

	// 4. CLAUDE.md の生成
	if !fileExists("CLAUDE.md") {
		templatePath := filepath.Join(scriptDir, "..", "templates", "CLAUDE.md.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, "CLAUDE.md"); err == nil {
				messages = append(messages, "CLAUDE.md 生成完了")
			}
		}
	}

	// 5. Plans.md の生成（plansDirectory 設定を考慮）
	plansPath := getPlansFilePath(scriptDir)
	if !fileExists(plansPath) {
		plansDir := filepath.Dir(plansPath)
		if plansDir != "." {
			_ = os.MkdirAll(plansDir, 0o755)
		}
		templatePath := filepath.Join(scriptDir, "..", "templates", "Plans.md.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, plansPath); err == nil {
				messages = append(messages, "Plans.md 生成完了")
			}
		}
	}

	// 6. テンプレートトラッカーの初期化
	runTemplateTracker(scriptDir, "init")

	// 7. harness-mem managed companion の自動セットアップ。
	// 失敗しても Harness 本体の Setup hook は止めない。
	if result := harnessmem.AutoSetupFromSetupHook(harnessMemAutoSetupMarkerPath()); result.Attempted {
		if result.Ready {
			messages = append(messages, "harness-mem companion setup complete")
		} else {
			messages = append(messages, "harness-mem companion setup deferred")
		}
	} else if result.Ready {
		messages = append(messages, "harness-mem companion ready")
	}

	// SIMPLE モード警告を追加
	if simpleMode {
		messages = append(messages, "WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
	}

	if len(messages) == 0 {
		return writeSetupOutput(out, "[Setup:init] ハーネスは既に初期化済みです")
	}
	return writeSetupOutput(out, "[Setup:init] "+strings.Join(messages, ", "))
}

func harnessMemAutoSetupMarkerPath() string {
	projectRoot := resolveProjectRoot()
	return filepath.Join(projectRoot, ".claude", "state", "harness-mem-companion-setup.json")
}

// runSetupMaintenance は maintenance モードの処理を実行する。
func runSetupMaintenance(out io.Writer, scriptDir string, simpleMode bool) error {
	var messages []string

	// 1. プラグインキャッシュの同期
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		if err := cmd.Run(); err == nil {
			messages = append(messages, "キャッシュ同期完了")
		}
	}

	// 2. 古いセッションファイルのクリーンアップ（7日以上）
	stateDir := ".claude/state"
	archiveDir := filepath.Join(stateDir, "sessions")
	if _, err := os.Stat(archiveDir); err == nil {
		cutoff := time.Now().AddDate(0, 0, -7)
		entries, err := os.ReadDir(archiveDir)
		if err == nil {
			for _, entry := range entries {
				if !strings.HasPrefix(entry.Name(), "session-") || !strings.HasSuffix(entry.Name(), ".json") {
					continue
				}
				info, err := entry.Info()
				if err != nil {
					continue
				}
				if info.ModTime().Before(cutoff) {
					_ = os.Remove(filepath.Join(archiveDir, entry.Name()))
				}
			}
		}
		messages = append(messages, "古いセッションアーカイブ削除")
	}

	// 3. 一時ファイルのクリーンアップ
	if _, err := os.Stat(stateDir); err == nil {
		removeTmpFiles(stateDir)
	}

	// 4. テンプレート更新チェック
	checkResult := runTemplateTracker(scriptDir, "check")
	if checkResult != "" {
		var checkData map[string]interface{}
		if err := json.Unmarshal([]byte(checkResult), &checkData); err == nil {
			if needsCheck, ok := checkData["needsCheck"].(bool); ok && needsCheck {
				updatesCount := 0
				if count, ok := checkData["updatesCount"].(float64); ok {
					updatesCount = int(count)
				}
				messages = append(messages, fmt.Sprintf("テンプレート更新あり: %d件", updatesCount))
			}
		}
	}

	// 5. SIMPLE モード警告を追加
	if simpleMode {
		messages = append(messages, "WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
	}

	// 6. 設定ファイルの YAML 構文チェック（python3 が利用可能な場合）
	configFile := ".claude-code-harness.config.yaml"
	if fileExists(configFile) {
		if err := validateYAMLConfig(configFile); err != nil {
			messages = append(messages, "警告: 設定ファイルの構文エラー")
		}
	}

	if len(messages) == 0 {
		return writeSetupOutput(out, "[Setup:maintenance] メンテナンス完了（変更なし）")
	}
	return writeSetupOutput(out, "[Setup:maintenance] "+strings.Join(messages, ", "))
}

// copyFile はファイルをコピーする。
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("read %s: %w", src, err)
	}
	return os.WriteFile(dst, data, 0o644)
}

// removeTmpFiles はディレクトリ内の .tmp ファイルを再帰的に削除する。
func removeTmpFiles(dir string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if entry.IsDir() {
			removeTmpFiles(path)
			continue
		}
		if strings.HasSuffix(entry.Name(), ".tmp") {
			_ = os.Remove(path)
		}
	}
}

// validateYAMLConfig は python3 で YAML 構文を検証する。
func validateYAMLConfig(configFile string) error {
	if _, err := exec.LookPath("python3"); err != nil {
		return nil // python3 がない場合はスキップ
	}
	cmd := newYAMLValidationCommand(configFile)
	return cmd.Run()
}

func newYAMLValidationCommand(configFile string) *exec.Cmd {
	return exec.Command("python3", "-c", "import sys, yaml; yaml.safe_load(open(sys.argv[1]))", configFile)
}

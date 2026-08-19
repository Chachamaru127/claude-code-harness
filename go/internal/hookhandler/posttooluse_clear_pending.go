package hookhandler

import (
	"io"
	"os"
	"path/filepath"
)

// ClearPendingHandler は PostToolUse フックハンドラ（pending-skills クリア）。
// Skill ツール実行後に .claude/state/pending-skills/*.pending ファイルを削除する。
// Skill の呼び出しをもって品質ゲート実行済みとみなし、pending 状態を解消する。
//
// shell 版: scripts/posttooluse-clear-pending.sh
type ClearPendingHandler struct {
	// ProjectRoot はプロジェクトルートのパス。空の場合は cwd を使用する。
	ProjectRoot string
}

// Handle は stdin からペイロードを読み取り（使用しない）、
// pending-skills ディレクトリの *.pending ファイルをすべて削除する。
func (h *ClearPendingHandler) Handle(r io.Reader, w io.Writer) error {
	// stdin は読み捨て（このハンドラは入力を使用しない）
	_, _ = io.ReadAll(r)

	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	pendingDir := filepath.Join(projectRoot, ".claude", "state", "pending-skills")

	// pending ディレクトリが存在しない場合はスキップ
	if _, err := os.Stat(pendingDir); os.IsNotExist(err) {
		return nil
	}

	// *.pending ファイルをすべて削除
	matches, err := filepath.Glob(filepath.Join(pendingDir, "*.pending"))
	if err == nil {
		for _, path := range matches {
			_ = os.Remove(path)
		}
	}

	return nil
}

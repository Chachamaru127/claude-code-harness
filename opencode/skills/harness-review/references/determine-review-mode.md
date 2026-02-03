---
name: determine-review-mode
description: "Determine review mode (default/codex) from .claude-code-harness.config.yaml. Falls back to 'default' if Codex is not configured or enabled."
allowed-tools: ["Read"]
---

# Determine Review Mode

`.claude-code-harness.config.yaml`からレビューモードを決定し、**Codex MCP を自動検出**して利用可否を判断する。利用不可の場合は`default`にフォールバックする。

---

## 入力

- **config_file**: 設定ファイルのコンテキスト（任意）

---

## 出力

```json
{
  "review_mode": "default"
}
```

または、Codexが有効な場合：

```json
{
  "review_mode": "codex"
}
```

---

## 実行手順

### Step 1: 設定ファイルの読み込み

```bash
# config_file が存在する場合は読み込む
# 存在しない場合は default にフォールバック
```

### Step 2: レビューモードの確認

設定ファイルの構造：

```yaml
review:
  mode: codex  # または "default"
  codex:
    enabled: true      # または false
    timeout_ms: 60000  # Codex MCP のタイムアウト（ミリ秒）
```

### Step 3: Codex MCP 自動検出（必須）

Codex MCP サーバーの有無を確認する。検出に失敗したら `default` にフォールバック。

```bash
# 例: MCP サーバー一覧で codex を検出
claude mcp list | grep -i codex
```

> **タイムアウト**: `review.codex.timeout_ms`（ms）を上限に検出を打ち切る。

### Step 4: 判定ロジック

```javascript
// 疑似コード例
let review_mode = "default";
const timeoutMs = config.review?.codex?.timeout_ms ?? 60000;
const codexAvailable = detectCodexMcp(timeoutMs);

// 1. review.modeを確認
if (config.review?.mode === "codex") {
  // 2. review.codex.enabledを確認
  if (config.review?.codex?.enabled === true && codexAvailable) {
    // 3. Codex MCP サーバーが利用可能なら codex
    review_mode = "codex";
  }
}

// デフォルトは "default"
return { review_mode };
```

### Step 5: フォールバック条件

以下の場合は`default`にフォールバック：

1. `config_file` が存在しない
2. `review.mode`が未設定または`default`
3. `review.mode`が`codex`だが`review.codex.enabled`が`false`
4. `review.codex.enabled`が未設定
5. Codex MCP サーバーが検出できない（`timeout_ms` 超過含む）

---

## 使用例

### 例1: Codex有効

**設定ファイル**:
```yaml
review:
  mode: codex
  codex:
    enabled: true
```

**出力**:
```json
{
  "review_mode": "codex"
}
```

### 例2: Codex無効

**設定ファイル**:
```yaml
review:
  mode: codex
  codex:
    enabled: false
```

**出力**:
```json
{
  "review_mode": "default"
}
```

### 例3: 設定ファイル未設定

**設定ファイル**: 存在しない、または`review`セクションなし

**出力**:
```json
{
  "review_mode": "default"
}
```

---

## 注意事項

- **安全側に倒す**: Codex設定が不明確な場合は`default`にフォールバック
- **設定ファイルの優先**: 環境変数などではなく、設定ファイルの値を優先する
- **MCPサーバー確認**: 実装時は`claude mcp list`でCodex MCPサーバーの存在も確認可能（オプション）

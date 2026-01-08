# Claude Code 2.1.0 対応アップデートプラン

## 🎯 概要

Claude Code v2.1.0 で導入された新機能に harness を対応させるためのアップデートプランです。

> **📌 運用ルール**: このドキュメントは「参照用プラン」です。実際のタスク追跡は `Plans.md` に起票して行います。
> チェックボックスは計画の全体像を示すためのものであり、進捗管理は Plans.md で行ってください。

---

## 📋 変更一覧

### Phase 1: スキル・エージェントのフロントマター拡張（高優先度）

#### 1.1 新しいフロントマターフィールドの対応

| フィールド | 対象 | 説明 | 根拠 | ステータス |
|-----------|------|------|------|-----------|
| `context: fork` | skill/command | 分離コンテキストで実行 | [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) | ✅ 確認済み |
| `agent` | skill | エージェントタイプを指定 | [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) | ✅ 確認済み |
| `skills` | agent | サブエージェント用スキル自動読み込み | [Skills Documentation](https://code.claude.com/docs/en/skills) | ✅ 確認済み |
| `user-invocable: false` | skill | スラッシュメニューから非表示 | [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "opt-out with `user-invocable: false`" | ✅ 確認済み |

**設定/CLIオプション（フロントマター外）**:

| オプション | 対象 | 説明 | 根拠 | ステータス |
|-----------|------|------|------|-----------|
| `--disallowedTools` | CLI | 禁止ツールリスト | [CLI Reference](https://code.claude.com/docs/en/cli-reference) | ✅ 確認済み |
| `disallowedTools` | agent定義 | エージェント固有の禁止ツール | [CHANGELOG 2.0.30](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added `disallowedTools` field to custom agent definitions" | ✅ 確認済み |
| `permissionMode` | agent定義 | エージェントの権限モード | [CHANGELOG 2.0.43](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added `permissionMode` field for custom agents" | ✅ 確認済み |

- [ ] cc:TODO `/harness-init`で生成するテンプレートに新フィールドを追加
- [ ] cc:TODO 既存エージェント（6個）に `skills` フィールド追加を検討
- [ ] cc:TODO 既存エージェントに `disallowedTools` フィールド追加（安全性強化）
- [ ] cc:TODO 内部専用スキルに `user-invocable: false` を設定

#### 1.2 エージェントへのインラインフック対応

Claude Code 2.1.0 では、エージェントのフロントマターに直接フックを定義可能になりました。

**根拠**: [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added hooks support to agent frontmatter, allowing agents to define PreToolUse, PostToolUse, and Stop hooks scoped to the agent's lifecycle"

```yaml
---
name: my-agent
hooks:
  PreToolUse:
    - matcher: "Bash"
      command: "echo 'checking...'"
  PostToolUse:
    - matcher: "*"
      command: "echo 'done'"
  Stop:
    - prompt: "Summarize what was done"
---
```

- [ ] cc:TODO エージェントテンプレートにインラインフック例を追加
- [ ] cc:TODO `ci-cd-fixer`エージェントにPreToolUseフック追加（危険コマンド検出）

---

### Phase 2: フックシステムの拡張（高優先度）

#### 2.1 新しいフック設定オプション

| オプション | 説明 | 根拠 | ステータス |
|-----------|------|------|-----------|
| `once: true` | フックを1回だけ実行 | [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added support for `once: true` config for hooks" | ✅ 確認済み |
| `SubagentStart` | サブエージェント開始時イベント | [CHANGELOG 2.0.43](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added the `SubagentStart` hook event" | ✅ 確認済み |
| `SubagentStop` | サブエージェント終了時イベント | [Hooks Documentation](https://code.claude.com/docs/en/hooks)、[CHANGELOG 2.0.41](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Split Stop hook triggering into Stop and SubagentStop" | ✅ 確認済み |

#### 2.2 `once: true` の設定例

**根拠**: [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" session-init",
            "timeout": 30,
            "once": true
          }
        ]
      }
    ]
  }
}
```

#### 2.3 SubagentStart / SubagentStop の設定例

**根拠**: [Hooks Documentation](https://code.claude.com/docs/en/hooks)、[Plugins Reference](https://code.claude.com/docs/en/plugins-reference)

`SubagentStop` では以下のフィールドが利用可能:
- `agent_id`: サブエージェントの識別子（[CHANGELOG 2.0.42](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)）
- `agent_transcript_path`: トランスクリプトファイルのパス（[CHANGELOG 2.0.42](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)）

```json
{
  "SubagentStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" subagent-tracker start",
          "timeout": 5
        }
      ]
    }
  ],
  "SubagentStop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js\" subagent-tracker stop",
          "timeout": 5
        }
      ]
    }
  ]
}
```

- [ ] cc:TODO `hooks/hooks.json` に `SubagentStart` フック追加
- [ ] cc:TODO `SubagentStop` フック追加（agent_id, agent_transcript_path活用）
- [ ] cc:TODO `session-init.sh` フックに `once: true` を適用（重複実行防止）
- [ ] cc:TODO フック用スクリプト `subagent-tracker.sh` 作成

---

### Phase 3: 設定テンプレートの更新（中優先度）

#### 3.1 language設定の追加

**根拠**: [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added `language` setting to configure Claude's response language (e.g., language: \"japanese\")"

```json
{
  "language": "japanese"
}
```

- [ ] cc:TODO `templates/claude/settings.local.json.template` に `language` 設定追加
- [ ] cc:TODO `/harness-init` で言語設定を自動検出（ja/en）

#### 3.2 ワイルドカード権限パターンの活用

**根拠**: [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added wildcard pattern matching for Bash tool permissions using `*` at any position in rules"

```json
{
  "permissions": {
    "allow": [
      "Bash(npm *)",
      "Bash(git * main)",
      "Bash(bun *)"
    ]
  }
}
```

- [ ] cc:TODO 権限テンプレートにワイルドカードパターン例を追加
- [ ] cc:TODO `templates/claude/settings.security.json.template` 更新

#### 3.3 MCP動的更新対応

**根拠**: [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added support for MCP `list_changed` notifications, allowing MCP servers to dynamically update their available tools"

- [ ] cc:TODO `harness-ui` MCP サーバーで動的ツール更新を検討

---

### Phase 4: ドキュメント更新（中優先度）

#### 4.1 Skills ホットリロード対応

**根拠**: [CHANGELOG 2.1.0](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Added automatic skill hot-reload - skills created or modified in `~/.claude/skills` or `.claude/skills` are now immediately available without restarting the session"

**運用への影響**: 従来は「スキル追加後は再起動が必要」という前提がありましたが、2.1.0以降は再起動不要になりました。

- [ ] cc:TODO 既存ドキュメントで「再起動が必要」と記載している箇所を見直し
- [ ] cc:TODO `/skill-list` コマンドの説明を更新（ホットリロード対応を明記）
- [ ] cc:TODO `docs/ARCHITECTURE.md` のスキル説明を更新

#### 4.2 新機能ドキュメント

- [ ] cc:TODO `docs/CLAUDE_CODE_2_1_FEATURES.md` 作成（新機能解説）
- [ ] cc:TODO `docs/ARCHITECTURE.md` 更新（新フック、新フィールド）
- [ ] cc:TODO `README.md` 更新（Claude Code 2.1.0対応を明記）

#### 4.3 CHANGELOG更新

- [ ] cc:TODO `CHANGELOG.md` に v2.7.0 エントリ追加

---

### Phase 5: 既存機能の最適化（低優先度）

#### 5.1 Exploreサブエージェント活用

**根拠**: [CHANGELOG 2.0.17](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) - "Introducing the Explore subagent. Powered by Haiku it'll search through your codebase efficiently to save context!"

- [ ] cc:TODO `/sync-status` コマンドで Explore エージェント活用を検討
- [ ] cc:TODO プロジェクト分析スキルで Explore 活用

#### 5.2 context: fork の活用

- [ ] cc:TODO 重い処理を行うスキル（例：code-reviewer呼び出し）に `context: fork` を適用
- [ ] cc:TODO `/harness-review` コマンドを fork コンテキストで実行

---

## 🔄 互換性確認

### 非推奨となった機能

| 機能 | 状態 | harness対応 | 根拠 |
|------|------|------------|------|
| `claude config` コマンド | 非推奨 | ✅ すでに settings.json 使用 | [CHANGELOG 1.0.7](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |
| 出力スタイル | 非推奨→再有効化 | ⚠️ 検討 | [CHANGELOG 2.0.32](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |
| `ignorePatterns` in .claude.json | 移行済み | ✅ settings.json へ | [CHANGELOG 1.0.7](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |

### 新しいフック入力フィールド

| フィールド | 追加バージョン | 対応状況 | 根拠 |
|-----------|---------------|---------|------|
| `tool_use_id` | 2.0.43 | ⚠️ 未使用 | [CHANGELOG 2.0.43](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |
| `agent_id` (SubagentStop) | 2.0.42 | ⚠️ 未対応 | [CHANGELOG 2.0.42](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |
| `agent_transcript_path` (SubagentStop) | 2.0.42 | ⚠️ 未対応 | [CHANGELOG 2.0.42](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |
| `hook_event_name` | 2.0.41 | ⚠️ 未使用 | [CHANGELOG 2.0.41](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) |

---

## 📊 優先度サマリー

| Phase | 優先度 | タスク数 | 工数目安 |
|-------|--------|---------|---------|
| Phase 1 | 高 | 6 | 中 |
| Phase 2 | 高 | 4 | 中 |
| Phase 3 | 中 | 4 | 小 |
| Phase 4 | 中 | 6 | 小 |
| Phase 5 | 低 | 4 | 小 |
| **合計** | - | **24** | - |

---

## 🚀 次のステップ

1. **Phase 1 + Phase 2 を同時着手**（高優先度）
2. フロントマター拡張のための既存ファイル調査
3. hooks.json の拡張実装
4. テスト追加

---

## 📝 参考リンク

| リソース | URL |
|---------|-----|
| Claude Code CHANGELOG | https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md |
| Claude Code CHANGELOG (raw) | https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md |
| Plugins Documentation | https://code.claude.com/docs/en/plugins |
| Plugins Reference | https://code.claude.com/docs/en/plugins-reference |
| Hooks Documentation | https://code.claude.com/docs/en/hooks |
| Skills Documentation | https://code.claude.com/docs/en/skills |
| CLI Reference | https://code.claude.com/docs/en/cli-reference |

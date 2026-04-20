---
name: cc-update-review
description: "Claude/Codex upstream update 統合の品質ガードレール。Feature Table 追加時に「書いただけ」を検出し、実装または Plans 化を強制する。Use when reviewing Claude Code / Codex update integration PRs. Do NOT load for: implementation work, standard reviews, setup."
description-en: "Quality guardrail for Claude/Codex update integration. Detects doc-only Feature Table additions and requires implementation or explicit planning. Internal use only."
description-ja: "Claude/Codex upstream update 統合の品質ガードレール。Feature Table 追加時に「書いただけ」を検出し、実装または Plans 化を強制する。内部専用。"
user-invocable: false
allowed-tools: ["Read", "Grep", "Glob"]
---

# Claude/Codex Update Review ガードレール

Claude Code / OpenAI Codex のアップデート統合時に「Feature Table に書いただけ」を防止する品質ガードレール。
Feature Table への追加が実装・検証・明示的な将来タスク化を伴っているかを分類し、不足があれば実装案を強制出力する。

## Quick Reference

以下の状況でこのスキルがトリガーされる:

- Claude Code / Codex upstream update 統合 PR のレビュー時
- `docs/CLAUDE-feature-table.md` に新行が追加された diff を検出した時
- `/harness-review` が upstream update 統合 PR と判定した場合の内部呼び出し
- `claude-codex-upstream-update` スキル更新のレビュー時

トリガーしない状況:

- 通常の実装作業
- Feature Table / upstream 追従に関係しない変更
- セットアップ・初期化作業

## 前提チェック

レビュー冒頭で必ず確認する:

- upstream のバージョン別分解表があるか
- Claude Code の一次情報 URL が `anthropics/claude-code` または公式 docs になっているか
- Codex の一次情報 URL が `openai/codex/releases` または OpenAI 公式記事になっているか
- `B: 書いただけ` が残っていないか
- skill mirror を触る場合、`skills/`, `codex/.codex/skills/`, `.agents/skills/` の差分が意図通りか

禁止する古い参照:

- 旧 TypeScript guardrail path
- 旧 TypeScript implementation glob
- 旧 Codex feature-table path
- 旧 Codex plugin directory
- 旧 Codex state directory を現行正本として扱う記述
- 存在しない Anthropic 側 Codex repo URL

## 3 カテゴリ分類

Feature Table に追加された各項目を、以下の 3 カテゴリに分類する。

### (A) 実装あり

定義: Feature Table の追加に対応する hooks / settings / Go / scripts / agents / skills / tests の変更が同じ PR に含まれている。

判定条件:

- Feature Table の行で言及されている機能に関連するファイルが変更されている
- `hooks/hooks.json`, `.claude-plugin/hooks.json`, `.claude-plugin/settings.json`, `go/internal/guardrail/`, `go/internal/hookhandler/`, `scripts/`, `agents/`, `skills/`, `tests/` のいずれかに実体差分がある
- 対象テストまたは検証スクリプトで固定されている

例:

| Feature Table 追加 | 対応する実装変更 | 判定 |
|-------------------|----------------|------|
| `AskUserQuestion updatedInput` | Go handler + hooks wiring + upstream integration test | A |
| `sandbox.network.deniedDomains` | `.claude-plugin/settings.json` + jq test | A |
| `find -delete hardening` | `go/internal/guardrail/` + unit test | A |

結果: OK。追加のアクション不要。

---

### (B) 書いただけ

定義: Feature Table にのみ行が追加され、Harness 側の実装変更も Plans 化もない。かつ upstream 自動継承にも該当しない。

判定条件:

- Feature Table に新行がある
- 同じ PR 内で関連する実装 / test / skill / Plans の変更がない
- Harness が独自の付加価値を提供すべき機能である

例:

| Feature Table 追加 | 対応する実装変更 | 判定 |
|-------------------|----------------|------|
| `PreCompact hook` | なし | B |
| `permission hardening` | settings / guardrail / tests の確認なし | B |
| `Codex marketplace` | Plans への切り出しなし | B |

結果: NG。PR をブロックし、実装案または Plans 化を要求する。

---

### (C) upstream 自動継承

定義: Claude Code / Codex 本体のパフォーマンス改善・バグ修正・内部最適化等で、Harness 側の変更が不要な項目。

判定条件:

- upstream 本体の修正であり、Harness がラップ・拡張する余地がない
- Harness の settings / hooks / guardrail / workflow / tests に影響しない
- Feature Table に「upstream 自動継承」または「CC 自動継承 / Codex 側自動継承」と明記されている

注意:

- permission / sandbox / security / Bash allowlist / MCP trust boundary は安易に C にしない
- その項目が Harness の独自 guardrail や settings に影響しないことを確認してから C にする
- Claude Code 2.1.113 の hardening は、`sandbox.network.deniedDomains`, wrapper Bash deny, `find -exec/-delete`, macOS dangerous rm paths を確認するまで C 判定しない

例:

| Feature Table 追加 | 理由 | 判定 |
|-------------------|------|------|
| `Agent Teams permission dialog crash fix` | CC 本体の crash fix。Harness 側変更不要 | C |
| `Codex Guardian timeout wording` | Codex 側 UX 修正。Harness surface なし | C |

結果: OK。ただし理由を明記する。

---

### (P) Plans 化

定義: 今回は直接実装しないが、Harness に取り込む価値があるため `Plans.md` に明示タスクとして残す項目。

判定条件:

- Feature Table の付加価値列が `A: 将来タスク化` または `P: Plans 化` として読める
- `Plans.md` に対応タスクがあり、setup / guardrails / memory / Codex workflow など実装面が明記されている
- alpha release や大規模設計変更など、即実装しない理由が書かれている

例:

| Feature Table 追加 | Plans への切り出し | 判定 |
|-------------------|-------------------|------|
| `Codex marketplace / MCP Apps` | Codex workflow 比較軸タスク | P |
| `Codex 0.122.0-alpha` | stable 化後の compare 調査タスク | P |

結果: OK。次回 cycle で拾える。

## Upstream update PR チェックリスト

```markdown
## Claude/Codex update 統合チェックリスト

### 1. 一次情報と分解表
- [ ] Claude / Codex の公式 URL を確認した
- [ ] Version / Upstream item / Category / Harness surface / Action の表がある
- [ ] alpha / stable / docs-only の区別がある

### 2. Feature Table 差分
- [ ] `docs/CLAUDE-feature-table.md` の追加行を列挙した
- [ ] 各行に A / C / P のいずれかが付いている
- [ ] B が 0 件である

### 3. カテゴリ別の確認
- [ ] (A) 実装あり: 対応する実装ファイルとテストがある
- [ ] (B) 書いただけ: 0 件。残る場合は PR ブロック
- [ ] (C) 自動継承: permission / sandbox / security / workflow 影響を確認済み
- [ ] (P) Plans 化: `Plans.md` に将来タスクがある

### 4. Mirror と stale path
- [ ] `skills/` と `codex/.codex/skills/` の意図しない drift がない
- [ ] `.agents/skills/` が存在する場合、Claude/Codex 表記が壊れていない
- [ ] 旧 TypeScript guardrail path、旧 Codex plugin directory、旧 Codex feature-table path などの旧参照がない

### 5. CHANGELOG / tests
- [ ] CHANGELOG に「今まで / 今後」または相当する user-facing 説明がある
- [ ] upstream integration test または対象 unit test が追加 / 更新されている
```

## カテゴリ B 検出時の出力フォーマット

カテゴリ B が 1 件以上検出された場合、以下のフォーマットで実装案を出力する。
このフォーマットの出力は必須であり、省略は許可されない。

```markdown
## カテゴリ B 検出: 実装案

### B-{番号}. {Feature Table の項目名}

**現状**: Feature Table に記載のみ。Harness 側の実装 / 検証 / Plans 化なし。

**Harness ならではの付加価値**:
{この機能を Harness がどう活用すべきかの具体的な説明}

**実装案**:

| 対象ファイル | 変更内容 |
|------------|---------|
| `{ファイルパス}` | {具体的な変更内容} |
| `{ファイルパス}` | {具体的な変更内容} |

**ユーザー体験の改善**:
- 今まで: {現在のユーザー体験}
- 今後: {実装後のユーザー体験}

**実装の優先度**: {高 / 中 / 低}
**推定工数**: {小 / 中 / 大}
```

## 関連スキル

- `claude-codex-upstream-update` - upstream 差分調査と実装 cycle
- `harness-review` - コードレビュー
- `harness-work` - カテゴリ B / P の実装
- `memory` - 分類基準の SSOT 化

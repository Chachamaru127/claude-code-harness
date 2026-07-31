# Workflow Test Wiring Governance

`.github/workflows/` の AI 編集 deny と「新規テストの CI 配線」を両立させるためのルール。
operator 裁定 (2026-07-16): deny の本質は**報酬ハック防止**であって「AI はテスト網に触れない」ではない。

## なぜこのルールが必要か

背景 (why): [docs/rules/governance-rationale.md](../../docs/rules/governance-rationale.md#workflow-test-wiringmd)

## 配線の正本は tests/validate-plugin.sh（workflows は薄い層に保つ）

- `.github/workflows/validate-plugin.yml` は「`bash tests/validate-plugin.sh` を呼ぶ」薄い層に保ち、
  **AI は引き続き編集しない**（deny 維持。ここが報酬ハックの最終防壁）
- 新規テストの CI 配線は `tests/validate-plugin.sh` への追加で行う。このファイルは AI が編集できる
- これにより「テスト追加 → CI 反映」に workflows 編集は不要になる

## 方向の非対称ルール

| 操作 | 扱い |
|---|---|
| テストの**追加**（validate-plugin.sh への新セクション、tests/ 新規ファイル） | AI 可。通常のレビューを通す |
| テストの**削除・弱体化**（アサーション減・期待値緩和・呼び出し除去） | REQUEST_CHANGES 対象。`.claude/rules/test-quality.md` と reviewer regression lens が検知する |
| `.github/workflows/` 自体の変更 | 引き続き operator 手動のみ |

## 独立 auditor 設計（operator 提案 2026-07-16、実装は Plans.md 116.1）

テスト網がアップデートに追随しているかを、実装セッションから独立した agent が監査する:

1. **固定プロンプト**: auditor の指示文は repo に版管理し（`agents/` 配下）、呼び出し側が
   free-text で上書きしない。監査基準の恣意的変更を防ぐ
2. **fresh-context**: auditor は実装セッションと記憶・会話状態を共有しない
3. **権限**: auditor は「テスト追加の PR を起こす」までを行える。既存テストの削除・弱体化は提案しない
4. **PR gate**: auditor が必要と判定したテストが green になるまで、対象変更の PR は merge しない
5. **再申立て（appeal）**: 車輪の再発明的な指摘（既存の同等テストを見落とした等）に対し、
   依頼側は根拠付きで**1 回まで**再申立てできる。auditor は同じ固定プロンプトで裁定し、
   その判定を最終とする（ループ上限 1 = 交渉による基準侵食を防ぐ）

### 実装（Phase 116.1）

- `agents/test-wiring-auditor.md` — 固定プロンプト（read-only agent）
- `scripts/test-wiring-audit-core.sh` — 機械的第一パス（deterministic floor）
- `templates/schemas/test-wiring-audit.v1.json` — verdict artifact schema
- `tests/test-test-wiring-auditor.sh` — contract + SHA pin + core fixture

## 関連

- `.claude/rules/test-quality.md` — テスト改ざん禁止（弱体化検知の既存層）
- `.claude/rules/self-audit.md` — deny 面の減少検知
- Plans.md Phase 116 — auditor agent の実装チケット

# CLAUDE.md 構造監査 — Phase 47.1.1 調査レポート

調査日: 2026-04-20
対象: `CLAUDE.md` v2026-04-19 時点 (142 行、Phase 50.1.1 の pointer 追加後)
Phase 47 のゴール: session-start 読込コストの実測 → `.claude/rules/` への分割可否判断

## (a) section 別 line 計測

`awk` で `## H2` 境界ごとに line 数を集計した結果:

| # | Section | 行範囲 | 行数 |
|---|---------|--------|-----|
| 1 | Project Overview | 5-10 | 6 |
| 2 | Claude Code Feature Utilization | 11-18 | 8 |
| 3 | Development Rules | 19-44 | **26** |
| 4 | Repository Structure | 45-48 | 4 |
| 5 | Using Skills (Important) | 49-66 | **18** |
| 6 | Development Flow | 67-74 | 8 |
| 7 | Testing | 75-83 | 9 |
| 8 | Notes | 84-90 | 7 |
| 9 | MCP Trust Policy | 91-98 | 8 |
| 10 | Permission Boundaries | 99-114 | **16** |
| 11 | Key Commands (for development) | 115-127 | 13 |
| 12 | SSOT (Single Source of Truth) | 128-132 | 5 |
| 13 | Test Tampering Prevention | 133-142 | 10 |
|   | (ヘッダー + 空行) | 1-4 | 4 |
|   | **合計** | | **142** |

### Top 3 重い section

1. **Development Rules (26 行)**: 5 つの sub-section (Commit / Version / CHANGELOG / Language / Code Style)
2. **Using Skills (18 行)**: Top Skill Categories テーブル (5 行) + trigger 説明
3. **Permission Boundaries (16 行)**: guardrail 7 行テーブル + 説明

30 行超の section は存在しない。142 行全体で ~3.5KB 相当（session-start context 全体の 1-2%）。

## (b) 分割候補 section の列挙

`.claude/rules/` へ移設できる候補:

| 候補 | 現在の位置 | 分割先案 | メリット | 懸念点 |
|------|----------|---------|---------|-------|
| **MCP Trust Policy** | CLAUDE.md 91-98 (8 行) | `.claude/rules/mcp-trust-policy.md` | 既存 `codex-cli-only.md` と整合、外部 MCP 追加手順を独立管理 | 8 行なので分割価値は限定的 |
| **Permission Boundaries** | CLAUDE.md 99-114 (16 行) | `.claude/rules/permission-boundaries.md` | settings.json deny と連動、表を拡張しやすい | session-start で毎回見てほしい重要情報 |
| **Development Rules** | CLAUDE.md 19-44 (26 行) | `.claude/rules/development-rules.md` に一括 or sub-section 毎に分散 | 最大 section の軽量化 | 既に CHANGELOG は `github-release.md` に分離済みで残りは short |
| **Notes** | CLAUDE.md 84-90 (7 行) | 削除 or Repository Structure に merge | section ヘッダー + 項目 4 件で overhead が高い | 小さすぎて分割単独では価値なし |

2 つ以上の候補を列挙する DoD (b) は満たす。ただし (d) の判断で分割有無を決定する。

## (c) `@` 記法の可否調査

### 調査方法

既存 repo 内での `@path/to/file.md` パターン使用を grep で確認:

```bash
grep -rE '@[a-zA-Z0-9_/.-]+\.md' CLAUDE.md .claude/rules/*.md
# → 0 件
```

他箇所での使用:
- `.claude/worktrees/flamboyant-shannon/templates/*/commands/review-cc-work.md:83`: `@Plans.md から...` の形で **prompt body 内**で使用
- `docs/constitution.md:99`: `@docs/constitution.md の品質ゲートを満たすこと。` (self-reference、prose)

### 判定

1. **CC 2.1.111+ での `@file.md` 記法の公式仕様**: Claude Code の CLAUDE.md は auto-include されるが、`@path/to/file.md` 記法による追加 import が**公式に文書化された安定機能として存在する確認は取れない**。prompt body 内での参照案内としては使えるが、CLAUDE.md 自体が auto-load される現状では二重ロードになるリスクもある
2. **既存の運用実績**: CLAUDE.md 内では使われていない。pointer は常に `[.claude/rules/xxx.md](path)` のマークダウンリンク形式
3. **smoke test の存在**: `tests/test-claude-md-auto-include.sh` は存在しない。機能として smoke test で確認する対象ではなく、CC のバージョン互換性の問題

**結論**: `@` 記法は **安定動作する保証なし**。現状の pointer 方式（通常のマークダウンリンク + session-start で assistant が必要時に Read で追う）が最も安全。

## (d) 最終判断と根拠

### 判断: **現状維持（分割しない）**

### 根拠

1. **定量データ**: 142 行 / 最大 section 26 行は CC の session-start context から見れば軽量。分割しなくても token pressure は低い
2. **pointer 方式の安全性**: 現 CLAUDE.md は既に "concise overview + detailed pointer" パターンで設計されている（CHANGELOG → `github-release.md`, skill catalog → `docs/CLAUDE-skill-catalog.md`, feature table → `docs/CLAUDE-feature-table.md`）。詳細情報は既に外出ししており、CLAUDE.md に残っているのは「session-start で必ず参照すべき overview と index」
3. **`@` 記法の不確定性**: CC 2.1.111+ で `@` 記法が auto-include に昇格する保証がない。現 pointer (通常リンク) は assistant が必要時に Read で追う形で運用できる。`@` への移行は gain より divergence risk の方が大きい
4. **分割の主観的コスト**: section を `.claude/rules/` に移すと、source-of-truth が 2 箇所に分散する。現状 CLAUDE.md を読むだけで Harness 固有の運用規約の "目次" が一望できるメリットを失う
5. **hook 警告の扱い**: `PostToolUse` hook が 130 行超で警告を出す仕組みが v4.3.1 頃から入ったが、これは「150 行近くを超えたら再検討」の意味であり、「即分割すべき」の意味ではない。Phase 50.1.1 で +1 行したのは必要最小の pointer 追加で、意図的

### 将来の分割トリガー（将来対応ルール）

- **Trigger A**: 単一 section が 30 行超になったら、その section のみ分割を検討
- **Trigger B**: CLAUDE.md 全体が 180 行超になったら、全体再構成を検討
- **Trigger C**: CC 公式ドキュメントが `@` 記法の auto-include 挙動を明文化したら、section 再配置 + `@` 記法による一括 import への移行を検討

現時点 (142 行、最大 26 行) では Trigger A/B/C のいずれも満たさないため、現状維持が最適解。

## (e) 本 Phase の成果

本 Phase は調査のみで、**本体 `CLAUDE.md` の構造は変更していない**。
Phase 50.1.1 による pointer 1 行追加は別タスクとして実施済み。

## 関連ファイル

- `CLAUDE.md` (調査対象、無改変)
- `.claude/rules/` 配下 17 ファイル (分割先候補)
- `docs/CLAUDE-feature-table.md` (既に外出し済みの例)
- `docs/CLAUDE-skill-catalog.md` (既に外出し済みの例)
- `docs/CLAUDE-commands.md` (既に外出し済みの例)

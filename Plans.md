# Claude Code Harness — Plans.md

最終アーカイブ: 2026-04-19（Phase 44 + 45 + 46 → `.claude/memory/archive/Plans-2026-04-19-phase44-46.md`）
前回アーカイブ: 2026-04-17（Phase 37 + 41 + 42 + 43 → `.claude/memory/archive/Plans-2026-04-17-phase37-41-42-43.md`）

---

## 📦 アーカイブ

完了済み Phase は以下のファイルへ切り出し済み（git history にも残存）:

- [Phase 44 + 45 + 46](.claude/memory/archive/Plans-2026-04-19-phase44-46.md) — Opus 4.7 / CC 2.1.99-110 追従 "Arcana" (v4.2.0) + Plugin Manifest 公式準拠 + Worker 3 層防御 (#84-#87, v4.3.0)
- [Phase 37 + 41 + 42 + 43](.claude/memory/archive/Plans-2026-04-17-phase37-41-42-43.md) — Hokage 完全体 / Long-Running Harness / Go hot-path migration / Advisor Strategy
- [Phase 39 + 40 + 41.0](.claude/memory/archive/Plans-2026-04-15-phase39-40-41.0.md) — レビュー体験改善 / Migration Residue Scanner / Long-Running Harness Spike

---

## 🔖 Status マーカー凡例

PM ↔ Impl 運用で使用する標準マーカー:

| マーカー | 意味 | 誰が付ける |
|---------|------|-----------|
| `pm:依頼中` | PM がタスクを起票し、Impl へ依頼中 | PM |
| `cc:WIP` | Impl（Claude Code）が着手中 | Impl |
| `cc:完了` | Impl が作業完了し、PM の確認待ち | Impl |
| `pm:確認済` | PM が最終確認を完了 | PM |

**状態遷移**: `pm:依頼中 → cc:WIP → cc:完了 → pm:確認済`

**後方互換**: `cursor:依頼中` / `cursor:確認済` は `pm:依頼中` / `pm:確認済` の同義として扱う（Cursor PM 運用時の表記）。

---

## Phase 47: CLAUDE.md 構造見直し調査 [P2]

Purpose: CLAUDE.md が 141 行となり post-tool-use hook が分割検討を出している。実データ (関連 rules/docs への pointer 構造) を測定して、分割するか現状維持するかの判断材料を整える。実装はこの Phase では行わない（調査のみ）。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 47.1.1 | (a) CLAUDE.md 現行 141 行を section 単位で token 計測し、どのセクションが session-start 読込時に最もコストを食っているかをデータで出す（`wc -l` + 各セクションの行数表を `docs/claude-md-structure-audit.md` に記録）。(b) 他の harness repo (.claude/rules/ 配下 11 ファイル) に移せる section 候補を列挙（例: Permission Boundaries → `.claude/rules/permission-boundaries.md`、MCP Trust Policy → `.claude/rules/mcp-trust-policy.md` として再配置可能か）。(c) 分割した場合の CLAUDE.md side の pointer 方式（`@path/to/file.md` 参照 vs インラインコピー）を比較し、CC 2.1.111+ で `@` 記法が安定動作するかを `tests/test-claude-md-auto-include.sh` のような smoke test で確認（既存があれば参照、無ければ新設不要で観察のみ）。(d) 最終判断: 分割実装する/現状維持する のどちらかを rationale 付きで docs に記録 | (a) section 別 line 計測が docs/claude-md-structure-audit.md にある、(b) 分割候補 section が 2 つ以上列挙されている、(c) `@` 記法の可否が判定済み、(d) 判断と根拠が記録されている、(e) この Phase は調査のみで本体 CLAUDE.md は変更しない | - | cc:TODO |

---

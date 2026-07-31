# Release Notes Format

CHANGELOG の `## [X.Y.Z]` セクションを GitHub Release 用のノートに変換するルール。

## CHANGELOG ドラフト作成（メモリ上、Pre-Gate ステップ 7）

Confirmation Gate に提示する前に、以下をメモリ上で計算する（まだファイルには書き込まない）:

1. `## [Unreleased]` の本文を切り出す。
2. `## [Unreleased]` と `## [<previous>]` の間に `## [<new>] - YYYY-MM-DD` を挿入した形を作る。
3. 末尾 compare link を更新する:
   - `[Unreleased]: .../compare/v<prev>...HEAD` → `v<new>...HEAD`
   - `[<new>]: .../compare/v<prev>...v<new>` を追加する。
4. repo URL は既存の `[Unreleased]: ` 行から動的抽出する。

## 言語

- **GitHub Release notes: 英語** (公開リポジトリ向けの標準)
- **CHANGELOG.md: 日本語** (プロジェクトの第一言語が日本語の場合)

CHANGELOG を日本語で書いている場合、GitHub Release を作る際に英訳が必要。
スキルは Claude を呼んで draft 生成し、Confirmation Gate でユーザーに確認させる。

## 必須要素

```markdown
## What's Changed

**<1-line value summary>**

### Before / After

| Before | After |
|--------|-------|
| <previous UX> | <new UX> |

---

### Added
- <item>

### Changed
- <item>

### Fixed
- <item>

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## 要素の生成方法

### "What's Changed" のサマリー

CHANGELOG `[X.Y.Z]` セクションの `### テーマ` 行から抽出。
ない場合は Added/Changed/Fixed の最初の項目から 1 文で要約。

### Before / After テーブル

CHANGELOG の「今まで / 今後」記述から抽出。
ない場合は以下から推測:
- Fixed 項目 → 「<bug description>」 vs 「Fixed」
- Added 項目 → 「<feature>が使えなかった」 vs 「使えるように」
- Changed 項目 → 「<old behavior>」 vs 「<new behavior>」

### Added / Changed / Fixed

CHANGELOG の該当セクションをそのまま英訳して転記。

### フッター

固定: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## Draft 確認

Confirmation Gate では以下を提示:

```
GitHub Release Preview:
━━━━━━━━━━━━━━━━━━━━━━
Title: v4.0.4 - Fix CI validation gap
Body (first 20 lines):

  ## What's Changed

  **Fixed a gap in validate-plugin.sh ...**
  ...

(Full body: 45 lines)
━━━━━━━━━━━━━━━━━━━━━━
```

ユーザーが "修正して:..." と指示した場合は再生成。

## 検証

workflow に release notes を渡す前に、以下を満たすかチェック:

1. `## What's Changed` セクションが存在する
2. **太字サマリー**行が存在する
3. `### Before / After` テーブルが存在する
4. フッター `Generated with [Claude Code]` が存在する

満たさない場合は Gate に戻して修正を促す。

## 複数変更のまとめ方

CHANGELOG の `[X.Y.Z]` に 2 つ以上の機能がある場合:

- Title: 最も重要な 1 つで代表 (または "Multiple fixes and improvements")
- Body: 各機能を `### N. <feature name>` で分割して英訳

同日に複数バージョンを出すのは非推奨（versioning.md）。バッチリリースでまとめること。

# Social Content

このディレクトリは、X などの外向き発信用コンテンツの正本を置く場所です。

## 置くもの

- 投稿文
- スレッド原稿
- 画像生成プロンプト
- alt テキスト
- 投稿メモ

補足:
- `x-article` の生成途中 package は `out/social/<slug>/` にまとまる
- その中には `article.md`、画像、品質レポート、API 応答が入る
- `docs/social/` は公開用に昇格させた正本を置く場所として使う

## 置かないもの

- 生成済み画像
- 候補レンダリング
- 比較用の派生画像
- 一時出力

それらは `out/social/` に置きます。

`out/x-post/` や `out/x-promo/` などの旧ディレクトリは互換のため残っていますが、新しい social 系成果物は `out/social/` を優先します。

## 命名ルール

- 更新紹介: `claude-code-<version>-harness-update.md`
- 一般告知: `harness-<topic>-x-post.md`
- 連番よりもテーマ名優先

## 運用ルール

- 投稿前に文面を直すなら、このディレクトリの原稿を更新する
- 画像生成後の成果物だけ `out/social/` に追加する
- 迷ったら `docs/content-layout.md` を正本ルールとして参照する

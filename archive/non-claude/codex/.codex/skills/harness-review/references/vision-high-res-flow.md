# Vision High-Res Flow (Opus 4.7)

Opus 4.7 の高解像度 vision 機能（短辺最大 2576px）を harness-review で活かすための
典型シナリオ別フロー。

> **解像度上限**: 短辺 2576px が運用上の安全上限。それを超える画像は事前リサイズ推奨。
> 詳細ガイドは [`docs/opus-4-7-vision-usage.md`](../../../docs/opus-4-7-vision-usage.md) を参照。

---

## シナリオ 1: PDF ページレビュー

仕様書・設計ドキュメント・リリースノート等の PDF をレビュー対象にする場合。

### フロー

1. **ページ範囲を特定する**

   PDF 全体を一括で渡すと token 消費が大きくなるため、まずページ構成を把握する。

   ```
   Read tool: file_path="<path>.pdf", pages="1-5"
   ```

2. **1 ページあたりの実効 DPI を確認する**

   PDF の DPI が高い場合、レンダリング後に短辺が 2576px を超えることがある。
   超える場合は DPI を落として再エクスポートを依頼する（詳細は usage ガイド参照）。

3. **レビュー対象ページを Read で読み込む**

   ```
   Read tool: file_path="<path>.pdf", pages="<対象ページ範囲>"
   ```

   Read tool は pages パラメータで指定したページを vision モデルに渡す。
   1 回あたり最大 20 ページまで指定可能。

4. **Reviewer agent に渡す**

   読み込んだページの内容を harness-review のレビューフロー（Step 2: 5 観点）へ流す。
   Reviewer は視覚的なレイアウト・図表・コードスニペットを含めて評価する。

5. **バッチ処理（ページ数が多い場合）**

   20 ページを超える PDF は 20 ページ単位でバッチ分割する。

   ```
   pages="1-20"  → レビュー → 指摘を記録
   pages="21-40" → レビュー → 指摘を記録
   ...
   最後にまとめて verdict を統合する
   ```

### 判定基準

PDF レビューは reviewer_profile を `static` として扱い、以下を評価する:

| 観点 | チェック内容 |
|------|------------|
| **Quality** | 図表の説明が十分か、手順の前後関係が明確か |
| **Accessibility** | 代替テキストがない画像のみページはないか |
| **AI Residuals** | "TODO", "TBD", "Draft" 等の未完了マーカー |

---

## シナリオ 2: 設計図（Architecture Diagram）レビュー

システム構成図・ER 図・シーケンス図等の画像をレビュー対象にする場合。

### フロー

1. **画像の解像度を確認する**

   ```bash
   # macOS: sips で解像度確認
   sips -g pixelWidth -g pixelHeight diagram.png

   # ImageMagick がある場合
   identify diagram.png
   ```

   短辺が 2576px 以下なら Read tool で直接渡せる。
   超えている場合は事前リサイズ（詳細は usage ガイド参照）。

2. **Read tool で画像を読み込む**

   ```
   Read tool: file_path="diagram.png"
   ```

   Opus 4.7 は 2576px まで視認できるため、細かいラベルや矢印も解析できる。

3. **Reviewer agent に渡すコンテキストを準備する**

   ```
   以下のアーキテクチャ図をレビューしてください。
   対象: <システム名> の <図の種類（構成図 / ER 図 / シーケンス図 等）>
   確認観点: <レビュー目的（整合性確認 / 変更差分確認 / セキュリティ確認 等）>
   ```

4. **評価項目**

   | 観点 | チェック内容 |
   |------|------------|
   | **Security** | 認証フロー・認可境界・暗号化要件が図に反映されているか |
   | **Quality** | コンポーネント間の依存関係が明確か、単一責任が保たれているか |
   | **Performance** | ボトルネックになりやすい箇所（同期処理 / N+1 / キャッシュなし等）が可視化されているか |

5. **実装コードとの照合**

   設計図レビュー後、対応する実装コードを Code Review フローで照合し整合性を確認する。

---

## シナリオ 3: UI スクリーンショットレビュー

Web / モバイル UI のスクリーンショットを `--ui-rubric` オプションで採点する場合。

### フロー

1. **スクリーンショットを用意する**

   対象ページ・コンポーネントのスクリーンショットを取得する。
   Retina / HiDPI 環境では論理ピクセルの 2 倍サイズになることが多い。

   ```bash
   # macOS: screencapture コマンド
   screencapture -x screenshot.png

   # 解像度確認
   sips -g pixelWidth -g pixelHeight screenshot.png
   ```

2. **解像度を確認しリサイズ（必要に応じて）**

   短辺が 2576px を超える場合はリサイズする（詳細は usage ガイド参照）。
   2576px 以下なら Read tool でそのまま渡せる。

3. **harness-review --ui-rubric で評価する**

   ```
   /harness-review --ui-rubric
   ```

   実行前に Read tool でスクリーンショットを読み込み、Reviewer agent に渡す:

   ```
   Read tool: file_path="screenshot.png"
   ```

4. **4 軸採点（ui-rubric.md 参照）**

   | 軸 | 評価内容 |
   |----|---------|
   | **Design Quality** | ビジュアル階層・余白・カラー整合性 |
   | **Originality** | 独自性・ブランド表現 |
   | **Craft** | ピクセル精度・アニメーション・マイクロインタラクション |
   | **Functionality** | ユーザーフローの完結性・エラー状態の考慮 |

5. **複数解像度の比較（モバイル / タブレット / デスクトップ）**

   各解像度のスクリーンショットを同一セッションで連続 Read し、
   Reviewer agent にまとめてレスポンシブ対応を評価させる。

   ```
   Read tool: file_path="mobile.png"    # 375×812 相当
   Read tool: file_path="tablet.png"    # 768×1024 相当
   Read tool: file_path="desktop.png"   # 1440×900 相当
   ```

---

## Reviewer Agent との繋ぎ方

上記 3 シナリオのいずれでも、画像 / PDF を Read tool で読み込んだ後の
Reviewer agent への接続は以下の共通パターンで行う。

### breezing モードでの繋ぎ方

Lead が Worker から vision 入力ありのタスクを受け取った場合:

1. Worker は `files_changed` に画像/PDF パスを含めて返す
2. Lead は Read tool でそのパスを読み込み、vision コンテキストを付加してレビューを実行する
3. Reviewer agent が `review-result.v1` スキーマで verdict を返す

```json
// Reviewer に渡す追加コンテキスト例
{
  "vision_inputs": [
    { "type": "image", "path": "diagram.png", "role": "architecture_diagram" },
    { "type": "pdf",  "path": "spec.pdf",    "role": "specification", "pages": "1-10" }
  ],
  "review_context": "画像・PDF を含む変更のレビュー"
}
```

### 画像入力を受け取った場合の Reviewer の振る舞い

- Reviewer は画像入力を「通常の diff テキスト」と同等に扱い、`review-result.v1` を返す
- `observations[].location` には `"diagram.png:全体"` / `"spec.pdf:p3"` のように記載する
- 画像のみで critical / major を判定できない場合は `minor` または `recommendation` に留める
- vision 入力の有無によって判定基準（critical / major / minor / recommendation）は変わらない

---

## バッチ処理ガイドライン

複数の画像 / PDF ページを連続してレビューする場合:

| 状況 | 推奨アプローチ |
|------|--------------|
| PDF 20 ページ以下 | 1 回の Read で全ページ指定 |
| PDF 21 ページ以上 | 20 ページ単位でバッチ分割 → 指摘を統合 |
| 画像 1〜5 枚 | 連続 Read → まとめてレビュー |
| 画像 6 枚以上 | 5 枚単位でバッチ → verdict を最後に統合 |
| 高解像度画像が混在 | 事前リサイズ後に処理（usage ガイド参照） |

バッチ処理では各バッチの `observations` を蓄積し、
全バッチ完了後に `critical` / `major` の有無で最終 verdict を決定する。

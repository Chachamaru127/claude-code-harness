#!/bin/bash
# ======================================
# 過去バージョンのプラグインを取得
# ======================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"
VERSIONS_DIR="$BENCHMARK_DIR/versions"

echo "========================================"
echo "過去バージョンの取得"
echo "========================================"
echo ""

# バージョン定義（名前 参照）
# タグが存在する場合はタグを、ない場合はコミットハッシュを使用
VERSIONS=(
  "v2.4.0:v2.4.0"       # タグ
  "v2.3.1:778c4d2"      # コミットハッシュ
  "v2.0.0:fe78053"      # コミットハッシュ
)

cd "$PLUGIN_ROOT"

# 現在のブランチを保存
CURRENT_BRANCH=$(git branch --show-current)

for entry in "${VERSIONS[@]}"; do
  version="${entry%%:*}"
  ref="${entry##*:}"
  VERSION_DIR="$VERSIONS_DIR/$version"

  echo "処理中: $version (ref: $ref)"

  # 参照が存在するか確認
  if ! git rev-parse "$ref" >/dev/null 2>&1; then
    echo "  警告: 参照 $ref が見つかりません"
    continue
  fi

  # バージョンディレクトリを作成/更新
  rm -rf "$VERSION_DIR"
  mkdir -p "$VERSION_DIR"

  # 指定バージョンのファイルをエクスポート
  git archive "$ref" | tar -x -C "$VERSION_DIR"

  echo "  ✓ $VERSION_DIR に展開しました"
done

# 元のブランチに戻る（念のため）
git checkout "$CURRENT_BRANCH" > /dev/null 2>&1 || true

echo ""
echo "========================================"
echo "完了"
echo "========================================"
echo ""
echo "取得したバージョン:"
ls -la "$VERSIONS_DIR"

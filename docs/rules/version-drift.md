# Version Drift Detection

## チェック対象

VERSION と .claude-plugin/plugin.json の version は常に一致必須。
不一致検出時は `./scripts/sync-version.sh` の実行を提案（自動実行はしない）。

## Feature Table 鮮度

docs/CLAUDE-feature-table.md 内の「計画中（未実装）」「実装予定」項目は
6ヶ月経過で削除を提案。

## なぜこのルールが必要か

D2（不正確情報）は一度修正しても再発する。
バージョン不一致と Feature Table の腐敗は最も一般的なドリフトパターン。

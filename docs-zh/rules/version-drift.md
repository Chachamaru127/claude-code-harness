# Version Drift Detection

## 检查对象

VERSION 和 .claude-plugin/plugin.json 的 version 须始终保持一致。
检测到不一致时，建议执行 `./scripts/sync-version.sh`（不自动执行）。

## Feature Table 新鲜度

docs/CLAUDE-feature-table.md 内的"计划中（未实现）""计划实现"项目
经过 6 个月后建议删除。

## 为什么需要此规则

D2（不准确信息）即使修正一次也会复发。
版本不一致和 Feature Table 的腐坏是最常见的 drift 模式。

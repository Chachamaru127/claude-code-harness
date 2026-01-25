# decisions.md - 意思決定記録

## D1: プロジェクト初期化

**日時**: 2026-01-18
**決定**: Claude Code Harness で Solo 運用を開始

### 背景
- 評価テスト用プロジェクト
- TypeScript + Vitest + ESLint の既存構成

### 決定内容
- Solo モードで運用（.cursor/ なし）
- `/plan-with-agent` → `/work` → `/harness-review` のフロー

### 理由
- シンプルな運用で十分
- 2-Agent 運用は不要

# Nested Skills Directory 設計文書

> **Claude Code v2.1.6+**: `.claude/skills` のネスト構造を自動発見

## 現状

```
skills/
├── impl/SKILL.md
├── harness-review/SKILL.md
├── verify/SKILL.md
└── ...
```

すべてのスキルが1階層で管理されており、カテゴリは SKILL.md 内で論理的に分類。

## 将来案（検討中）

```
skills/
├── development/
│   ├── impl/SKILL.md
│   └── verify/SKILL.md
├── quality/
│   ├── harness-review/SKILL.md
│   └── ci/SKILL.md
├── workflow/
│   ├── workflow/SKILL.md
│   └── handoff/SKILL.md
└── ...
```

## 移行検討事項

### メリット
- カテゴリによる視覚的整理
- 関連スキルの近接配置
- プロジェクト固有スキル（`.claude/skills/`）との明確な分離

### デメリット
- 既存のスキル参照パスが変更になる
- プラグイン互換性の確認が必要
- 完全修飾名の形式が変わる可能性

### 互換性確認事項
- [ ] Claude Code v2.1.6+ でネスト構造が正しく発見されるか
- [ ] 既存の SKILL.md 参照が動作するか
- [ ] プラグインシステムとの互換性

## 結論

**現時点では移行しない**。理由:
1. 既存ユーザーへの影響が大きい
2. 現状の1階層でも十分管理可能
3. 将来の Claude Code アップデートで仕様が変わる可能性

**次のステップ**:
- Claude Code のネストスキル仕様の安定を待つ
- 必要に応じてプロジェクト固有スキル（`.claude/skills/`）でネスト構造を試験

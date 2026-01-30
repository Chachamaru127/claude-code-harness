# Self-Learning Mechanism

ultrawork の自己学習メカニズムに関する詳細仕様。

---

## 概要

ultrawork は各イテレーションで発生した失敗から学習し、
次のイテレーションで同じ失敗を繰り返さないよう戦略を調整する。

---

## 学習フロー

```
失敗発生
    ↓
エラーパターン分類
    ↓
失敗コンテキスト記録
    ↓
次イテレーション
    ↓
学習データ読み込み
    ↓
回避戦略を選択
    ↓
戦略を適用してタスク実行
    ↓
成功 → 学習データを「有効」としてマーク
失敗 → 別の戦略を試行
```

---

## エラーパターン分類

### パターン一覧

| パターン | 検出方法 | 例 |
|----------|----------|---|
| `type_error` | "Type '...' is not assignable" | 型の不一致 |
| `import_error` | "Cannot find module" | インポートパス |
| `test_failure` | "FAIL", "AssertionError" | テスト失敗 |
| `build_error` | "Build failed", "Compilation error" | ビルドエラー |
| `runtime_error` | "TypeError", "ReferenceError" | 実行時エラー |
| `lint_error` | "eslint", "prettier" | リントエラー |
| `dependency_error` | "peer dependency", "version mismatch" | 依存関係 |
| `unknown` | 上記に該当しない | 不明 |

### 分類ロジック

```typescript
function classifyError(error: string): ErrorPattern {
  const patterns: [RegExp, ErrorPattern][] = [
    [/Type '.*' is not assignable/i, 'type_error'],
    [/Cannot find module/i, 'import_error'],
    [/Module not found/i, 'import_error'],
    [/FAIL|AssertionError|Expected.*but got/i, 'test_failure'],
    [/Build failed|Compilation error/i, 'build_error'],
    [/TypeError|ReferenceError|is not defined/i, 'runtime_error'],
    [/eslint|prettier|lint/i, 'lint_error'],
    [/peer dependency|version.*mismatch/i, 'dependency_error'],
  ];

  for (const [regex, pattern] of patterns) {
    if (regex.test(error)) return pattern;
  }
  return 'unknown';
}
```

---

## 戦略マッピング

### パターン別戦略

#### type_error

```typescript
const TYPE_ERROR_STRATEGIES = [
  {
    name: 'check_type_definitions',
    description: '関連する型定義を先に確認',
    preCheck: async (ctx) => {
      // 型定義ファイルを検索
      const typeFiles = await glob('**/types/**/*.ts');
      return { files: typeFiles };
    },
    priority: 1
  },
  {
    name: 'add_type_guard',
    description: '型ガードを追加',
    apply: (code) => {
      // 型ガードパターンを挿入
    },
    priority: 2
  },
  {
    name: 'use_type_assertion',
    description: '型アサーションを使用（最終手段）',
    apply: (code) => {
      // as キーワードを使用
    },
    priority: 3
  }
];
```

#### import_error

```typescript
const IMPORT_ERROR_STRATEGIES = [
  {
    name: 'verify_path_structure',
    description: 'パス構造を再確認',
    preCheck: async (ctx) => {
      // ディレクトリ構造を確認
      const structure = await listDirectories(ctx.projectRoot);
      return { structure };
    },
    priority: 1
  },
  {
    name: 'check_tsconfig_paths',
    description: 'tsconfig.json のパスエイリアスを確認',
    preCheck: async (ctx) => {
      const tsconfig = await readJson('tsconfig.json');
      return { paths: tsconfig.compilerOptions?.paths };
    },
    priority: 2
  },
  {
    name: 'use_relative_path',
    description: '相対パスに変更',
    apply: (importPath, currentFile) => {
      return calculateRelativePath(currentFile, importPath);
    },
    priority: 3
  }
];
```

#### test_failure

```typescript
const TEST_FAILURE_STRATEGIES = [
  {
    name: 'read_test_expectations',
    description: 'テストケースを読んで期待値を理解',
    preCheck: async (ctx) => {
      const testFile = findRelatedTest(ctx.sourceFile);
      const content = await readFile(testFile);
      return { testContent: content };
    },
    priority: 1
  },
  {
    name: 'check_mock_data',
    description: 'モックデータを確認',
    preCheck: async (ctx) => {
      const mocks = await glob('**/__mocks__/**');
      return { mocks };
    },
    priority: 2
  },
  {
    name: 'debug_assertion',
    description: 'アサーションの詳細を確認',
    apply: (testCode) => {
      // console.log を追加してデバッグ
    },
    priority: 3
  }
];
```

#### build_error

```typescript
const BUILD_ERROR_STRATEGIES = [
  {
    name: 'check_dependencies',
    description: '依存関係を確認、順序変更',
    preCheck: async (ctx) => {
      const deps = await analyzeDependencies(ctx.files);
      return { deps, order: topologicalSort(deps) };
    },
    priority: 1
  },
  {
    name: 'clear_cache',
    description: 'ビルドキャッシュをクリア',
    apply: async () => {
      await exec('rm -rf .next node_modules/.cache');
    },
    priority: 2
  },
  {
    name: 'reinstall_deps',
    description: '依存関係を再インストール',
    apply: async () => {
      await exec('rm -rf node_modules && pnpm install');
    },
    priority: 3
  }
];
```

---

## 戦略選択アルゴリズム

### 優先度ベース選択

```typescript
function selectStrategy(
  pattern: ErrorPattern,
  previousAttempts: Attempt[]
): Strategy {
  const strategies = STRATEGY_MAP[pattern];

  // 未試行の戦略を優先度順で選択
  const tried = previousAttempts.map(a => a.strategy);
  const untried = strategies.filter(s => !tried.includes(s.name));

  if (untried.length > 0) {
    return untried.sort((a, b) => a.priority - b.priority)[0];
  }

  // 全戦略試行済み → 複合戦略を試行
  return createCompositeStrategy(pattern, previousAttempts);
}
```

### 複合戦略

```typescript
function createCompositeStrategy(
  pattern: ErrorPattern,
  attempts: Attempt[]
): Strategy {
  // 失敗した戦略の情報から新しいアプローチを生成
  const insights = attempts.map(a => a.result);

  return {
    name: 'composite_strategy',
    description: '複合アプローチ',
    steps: [
      'タスクを細分化',
      '各サブタスクで異なる戦略を適用',
      '結果を統合'
    ]
  };
}
```

---

## 学習データの永続化

### ワークログへの記録

```typescript
function recordLearning(
  worklog: Worklog,
  failure: TaskFailure,
  successfulStrategy: Strategy
) {
  worklog.append({
    event: 'learned',
    from_iteration: failure.iteration,
    pattern: failure.pattern,
    context: failure.error,
    strategy: successfulStrategy.name,
    strategy_description: successfulStrategy.description,
    priority: 'high',
    applicable_to: extractApplicableConditions(failure)
  });
}
```

### 学習データの活用

```typescript
function applyLearnings(
  learnings: Learning[],
  currentTask: Task
): TaskPlan {
  // 現在のタスクに適用可能な学習を抽出
  const applicable = learnings.filter(l =>
    isApplicable(l, currentTask)
  );

  // 優先度順にソート
  applicable.sort((a, b) => {
    if (a.priority === 'high' && b.priority !== 'high') return -1;
    return 0;
  });

  // タスク計画に事前チェックを追加
  return {
    task: currentTask,
    preChecks: applicable.map(l => l.strategy),
    fallbackStrategies: getRelatedStrategies(applicable)
  };
}
```

---

## 学習の限界と対処

### 3回連続失敗

同じパターンで3回連続失敗した場合：

```typescript
function handleRepeatedFailure(
  pattern: ErrorPattern,
  attempts: Attempt[]
): Action {
  if (attempts.length >= 3) {
    return {
      action: 'change_approach',
      steps: [
        '別アプローチを検索（コードベースから類似パターン）',
        'タスクを分割して再試行',
        'ユーザーに確認（最終手段）'
      ]
    };
  }
}
```

### 学習データの精度向上

```typescript
// 成功した戦略の重みを増加
function updateStrategyWeight(
  strategy: Strategy,
  success: boolean
) {
  if (success) {
    strategy.weight = Math.min(strategy.weight * 1.2, 10);
    strategy.successCount++;
  } else {
    strategy.weight = Math.max(strategy.weight * 0.8, 0.1);
    strategy.failureCount++;
  }
}
```

---

## 実行例

### イテレーション1: 失敗

```
タスク: 認証ミドルウェア作成
エラー: Type 'unknown' is not assignable to type 'User'
パターン: type_error
試行戦略: use_type_assertion
結果: 失敗

ワークログ記録:
{
  "event": "task_failed",
  "task": "認証ミドルウェア",
  "error": "Type 'unknown' is not assignable to type 'User'",
  "error_type": "type_error",
  "attempted_fix": "use_type_assertion",
  "fix_result": "failed"
}
```

### イテレーション2: 学習適用

```
読み込み: 前回の type_error 失敗
戦略選択: check_type_definitions（優先度1、未試行）
事前チェック: src/types/User.ts を読む
発見: User 型の定義を確認
実装: 正しい型を使用
結果: 成功

ワークログ記録:
{
  "event": "learned",
  "pattern": "type_error",
  "context": "User type not found",
  "strategy": "check_type_definitions",
  "priority": "high"
}
```

---

## VibeCoder 向け説明

| 何が起きるか | 説明 |
|-------------|------|
| 失敗したら | 自動的に原因を分析して記録 |
| 次の試行で | 前回の失敗を避ける方法を選択 |
| 同じエラー3回 | 別のアプローチを試す |
| 成功したら | その方法を覚えておく |

**ポイント**: ultrawork は「失敗から学ぶ」ので、最初の試行で失敗しても問題ない。
むしろ失敗するほど賢くなる。

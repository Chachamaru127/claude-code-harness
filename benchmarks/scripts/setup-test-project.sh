#!/bin/bash
# ======================================
# テストプロジェクトのセットアップ
# ======================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
TEST_PROJECT="$BENCHMARK_DIR/test-project"

echo "========================================"
echo "Claude harness ベンチマーク - テストプロジェクト初期化"
echo "========================================"

# テストプロジェクトをクリーンアップ
rm -rf "$TEST_PROJECT"
mkdir -p "$TEST_PROJECT"

cd "$TEST_PROJECT"

# 基本構造を作成
mkdir -p src/{api,components,utils/__tests__,services,legacy}
mkdir -p .claude

# package.json
cat > package.json << 'EOF'
{
  "name": "benchmark-test-project",
  "version": "1.0.0",
  "description": "Claude harness benchmark test project",
  "main": "index.js",
  "scripts": {
    "test": "jest",
    "build": "tsc"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^20.0.0",
    "jest": "^29.5.0",
    "ts-jest": "^29.1.0",
    "typescript": "^5.0.0"
  }
}
EOF

# tsconfig.json
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
EOF

# Plans.md（空）
cat > Plans.md << 'EOF'
# Plans

## Current Tasks

<!-- タスクはここに追加されます -->

## Completed

<!-- 完了タスク -->
EOF

# CLAUDE.md
cat > CLAUDE.md << 'EOF'
# CLAUDE.md

## Project Overview

This is a benchmark test project for Claude harness.

## Coding Standards

- Use TypeScript
- Follow ESLint rules
- Write tests for all functions
EOF

# 意図的な脆弱性を含む認証ハンドラー（セキュリティレビュー用）
cat > src/api/auth-handler.ts << 'EOF'
import { Request, Response } from 'express';

// 警告: このコードには意図的なセキュリティ問題が含まれています
// ベンチマークのセキュリティレビューテスト用です

const users: any[] = [];

export async function login(req: Request, res: Response) {
  const { username, password } = req.body;

  // 問題1: SQLインジェクション脆弱性（実際にはORMを使うべき）
  const query = `SELECT * FROM users WHERE username = '${username}' AND password = '${password}'`;
  console.log(query);

  // 問題2: 平文パスワードの比較
  const user = users.find(u => u.username === username && u.password === password);

  if (user) {
    // 問題3: 機密情報をレスポンスに含める
    res.json({
      success: true,
      user: user,
      password: password,
      token: 'secret-token-123'
    });
  } else {
    res.json({ success: false, error: 'Invalid credentials' });
  }
}

export async function register(req: Request, res: Response) {
  const { username, password, email } = req.body;

  // 問題4: 入力検証なし
  const newUser = {
    id: users.length + 1,
    username,
    password, // 問題5: パスワードを平文で保存
    email
  };

  users.push(newUser);

  // 問題6: XSS脆弱性
  res.send(`<h1>Welcome, ${username}!</h1>`);
}

export function getUserProfile(req: Request, res: Response) {
  const userId = req.params.id;

  // 問題7: 認可チェックなし（他ユーザーの情報取得可能）
  const user = users.find(u => u.id == userId);

  if (user) {
    res.json(user);
  } else {
    res.status(404).json({ error: 'User not found' });
  }
}
EOF

# 追加のTypeScriptファイル（並列レビュー条件: 変更ファイル >= 5 を満たすため）
cat > src/api/session.ts << 'EOF'
// ベンチマーク用: 意図的に問題を含むセッション管理

type Session = {
  userId: string;
  token: string;
  createdAt: number;
};

const sessions: Record<string, Session> = {};

export function createSession(userId: string) {
  // 問題: 予測可能なトークン（本番では crypto.randomUUID 等）
  const token = `token-${userId}-${Date.now()}`;
  sessions[token] = { userId, token, createdAt: Date.now() };
  return token;
}

export function getSession(token: string) {
  // 問題: 入力検証なし・型も曖昧
  return sessions[token as any] ?? null;
}
EOF

cat > src/api/profile.ts << 'EOF'
// ベンチマーク用: 意図的に問題を含むプロフィール取得

export type Profile = {
  id: string;
  name: string;
  bio?: string;
};

// 問題: any の使用 / エラーハンドリング不足
export async function fetchProfile(userId: any): Promise<Profile> {
  const res = await fetch(`/api/profile/${userId}`);
  const data = await res.json();
  return data;
}
EOF

cat > src/utils/sanitize.ts << 'EOF'
// ベンチマーク用: 意図的に弱いサニタイズ（XSSレビュー用）

// 問題: 不完全な置換（本番ではDOMPurify等を検討）
export function naiveSanitize(html: string) {
  return html.replace(/<script.*?>.*?<\\/script>/gi, "");
}
EOF

# 品質問題を含むReactコンポーネント（品質レビュー用）
cat > src/components/Dashboard.tsx << 'EOF'
import React, { useState, useEffect } from 'react';

// 警告: このコードには意図的な品質問題が含まれています
// ベンチマークの品質レビューテスト用です

interface User {
  id: number;
  name: string;
  email: string;
}

interface DashboardProps {
  userId: number;
}

// 問題1: コンポーネントが大きすぎる
export default function Dashboard({ userId }: DashboardProps) {
  const [user, setUser] = useState<User | null>(null);
  const [posts, setPosts] = useState<any[]>([]);
  const [comments, setComments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [counter, setCounter] = useState(0);

  // 問題2: 依存配列が不適切（無限ループの可能性）
  useEffect(() => {
    fetchData();
  });

  // 問題3: async関数の定義が毎回再作成される
  const fetchData = async () => {
    try {
      const userRes = await fetch(`/api/users/${userId}`);
      const userData = await userRes.json();
      setUser(userData);

      const postsRes = await fetch(`/api/users/${userId}/posts`);
      const postsData = await postsRes.json();
      setPosts(postsData);

      const commentsRes = await fetch(`/api/users/${userId}/comments`);
      const commentsData = await commentsRes.json();
      setComments(commentsData);
    } catch (e) {
      // 問題4: エラーハンドリングが不十分
      setError('Error');
    }
    setLoading(false);
  };

  // 問題5: インラインスタイルの乱用
  const headerStyle = {
    backgroundColor: '#f0f0f0',
    padding: '20px',
    marginBottom: '10px',
    borderRadius: '5px'
  };

  // 問題6: 計算が毎回実行される（useMemoなし）
  const expensiveCalculation = () => {
    let result = 0;
    for (let i = 0; i < 10000; i++) {
      result += Math.sqrt(i);
    }
    return result;
  };

  const calculatedValue = expensiveCalculation();

  // 問題7: コールバックが毎回再作成される
  const handleClick = () => {
    setCounter(counter + 1);
    console.log('clicked', counter);
  };

  if (loading) return <div>Loading...</div>;
  if (error) return <div>{error}</div>;

  return (
    <div>
      {/* 問題8: key属性がない、indexをkeyに使用 */}
      <div style={headerStyle}>
        <h1>Dashboard for {user?.name}</h1>
        <p>Calculated: {calculatedValue}</p>
        <button onClick={handleClick}>Count: {counter}</button>
      </div>

      <div>
        <h2>Posts</h2>
        {posts.map((post, index) => (
          <div key={index}>
            <h3>{post.title}</h3>
            <p>{post.content}</p>
          </div>
        ))}
      </div>

      <div>
        <h2>Comments</h2>
        {comments.map((comment, i) => (
          <div key={i}>
            <p>{comment.text}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

# レガシーJavaScriptファイル（リファクタリング用）
cat > src/legacy/user-service.js << 'EOF'
// レガシーコード: TypeScript変換とリファクタリングが必要

var axios = require('axios');

function UserService() {
  this.baseUrl = 'https://api.example.com';
  this.users = [];
}

UserService.prototype.getAllUsers = function(callback) {
  var self = this;
  axios.get(this.baseUrl + '/users')
    .then(function(response) {
      self.users = response.data;
      callback(null, self.users);
    })
    .catch(function(error) {
      callback(error, null);
    });
};

UserService.prototype.getUserById = function(id, callback) {
  var self = this;
  axios.get(this.baseUrl + '/users/' + id)
    .then(function(response) {
      callback(null, response.data);
    })
    .catch(function(error) {
      callback(error, null);
    });
};

UserService.prototype.createUser = function(userData, callback) {
  var self = this;
  if (!userData.name || !userData.email) {
    callback(new Error('Name and email are required'), null);
    return;
  }
  axios.post(this.baseUrl + '/users', userData)
    .then(function(response) {
      self.users.push(response.data);
      callback(null, response.data);
    })
    .catch(function(error) {
      callback(error, null);
    });
};

UserService.prototype.updateUser = function(id, userData, callback) {
  var self = this;
  axios.put(this.baseUrl + '/users/' + id, userData)
    .then(function(response) {
      for (var i = 0; i < self.users.length; i++) {
        if (self.users[i].id === id) {
          self.users[i] = response.data;
          break;
        }
      }
      callback(null, response.data);
    })
    .catch(function(error) {
      callback(error, null);
    });
};

UserService.prototype.deleteUser = function(id, callback) {
  var self = this;
  axios.delete(this.baseUrl + '/users/' + id)
    .then(function(response) {
      self.users = self.users.filter(function(user) {
        return user.id !== id;
      });
      callback(null, { success: true });
    })
    .catch(function(error) {
      callback(error, null);
    });
};

module.exports = UserService;
EOF

# .gitignore
cat > .gitignore << 'EOF'
node_modules/
dist/
.claude/state/
EOF

echo ""
echo "✓ テストプロジェクトを初期化しました: $TEST_PROJECT"
echo ""
echo "作成されたファイル:"
find "$TEST_PROJECT" -type f | sed "s|$TEST_PROJECT/||"
echo ""
echo "次のステップ: ./scripts/run-benchmark.sh --task <task-name> --version <version>"

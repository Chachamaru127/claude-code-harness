# Terminal System 完全仕様書

> harness-ui のターミナル表示・操作・連携を完璧に実装するための仕様

---

## 現状分析

### 既存実装

| コンポーネント | 状態 | 説明 |
|---------------|------|------|
| `Terminal.tsx` | ✅ | xterm.js ベースの表示 |
| `TerminalCards.tsx` | ✅ | セッション一覧カード |
| `pty-manager.ts` | ✅ | Bun.spawn による PTY 管理 |
| `WebSocket` | ✅ | リアルタイム通信 |
| 状態検出 | ✅ | WAITING/RUNNING/IDLE |
| フェーズ検出 | ✅ | PLAN/WORK/REVIEW |

### 改善が必要な点

| 機能 | 現状 | 目標 |
|------|------|------|
| 履歴永続化 | 1000行で切り捨て | 無制限 + ファイル保存 |
| セッション復元 | なし | ブラウザリロード時に復元 |
| 検索 | なし | Ctrl+F でインクリメンタル検索 |
| スプリットビュー | なし | 複数ターミナル同時表示 |
| コマンド補完 | なし | オートコンプリート |
| ログエクスポート | なし | JSON/テキストダウンロード |
| Claude連携 | 基本的 | コマンドパレット統合 |

---

## アーキテクチャ

### レイヤー構成

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ Terminal    │ │ SplitView   │ │ CommandBar  │           │
│  │ (xterm.js)  │ │ Container   │ │ (Palette)   │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
├─────────────────────────────────────────────────────────────┤
│                    State Layer                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ useTerminal │ │ useSessions │ │ useSearch   │           │
│  │ Hook        │ │ Hook        │ │ Hook        │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
├─────────────────────────────────────────────────────────────┤
│                    Transport Layer                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              WebSocket (Bidirectional)               │   │
│  │  send_input | log_chunk | resize | session_update    │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Server Layer                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ PTYManager  │ │ LogStore    │ │ Session     │           │
│  │ (Bun.spawn) │ │ (persist)   │ │ Persistence │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

### メッセージフロー

```
Client                        Server
  │                             │
  │─── create_session ─────────▶│  PTY spawn
  │◀── session_update ──────────│
  │                             │
  │─── send_input ─────────────▶│  PTY write
  │◀── log_chunk ──────────────│  PTY output
  │                             │
  │─── resize_terminal ────────▶│  PTY resize
  │                             │
  │─── search_logs ────────────▶│  LogStore query
  │◀── search_results ─────────│
  │                             │
  │─── export_logs ────────────▶│  LogStore export
  │◀── export_data ────────────│
```

---

## 詳細仕様

### 1. ターミナル表示（Terminal.tsx 拡張）

#### 1.1 xterm.js アドオン

```typescript
// 必要なアドオン
import { FitAddon } from 'xterm-addon-fit';        // ✅ 既存
import { SearchAddon } from 'xterm-addon-search';   // NEW
import { WebLinksAddon } from 'xterm-addon-web-links'; // NEW
import { Unicode11Addon } from 'xterm-addon-unicode11'; // NEW
import { SerializeAddon } from 'xterm-addon-serialize'; // NEW

interface TerminalHandle {
  write: (data: string) => void;
  focus: () => void;
  reset: () => void;
  fit: () => void;
  // NEW
  search: (query: string, options?: SearchOptions) => boolean;
  searchNext: () => boolean;
  searchPrevious: () => boolean;
  clearSearch: () => void;
  serialize: () => string;
  scrollToBottom: () => void;
  scrollToTop: () => void;
}

interface SearchOptions {
  regex?: boolean;
  wholeWord?: boolean;
  caseSensitive?: boolean;
  decorations?: {
    matchBackground?: string;
    activeMatchBackground?: string;
  };
}
```

#### 1.2 テーマ設定

```typescript
interface TerminalTheme {
  background: string;
  foreground: string;
  cursor: string;
  cursorAccent: string;
  selectionBackground: string;
  // ANSI colors
  black: string;
  red: string;
  green: string;
  yellow: string;
  blue: string;
  magenta: string;
  cyan: string;
  white: string;
  brightBlack: string;
  brightRed: string;
  brightGreen: string;
  brightYellow: string;
  brightBlue: string;
  brightMagenta: string;
  brightCyan: string;
  brightWhite: string;
}

// Harness テーマ（デフォルト）
const harnessTheme: TerminalTheme = {
  background: '#0a0a0a',
  foreground: '#e4e4e7',
  cursor: '#e4e4e7',
  cursorAccent: '#0a0a0a',
  selectionBackground: 'rgba(255, 255, 255, 0.2)',
  black: '#27272a',
  red: '#ef4444',
  green: '#22c55e',
  yellow: '#eab308',
  blue: '#3b82f6',
  magenta: '#a855f7',
  cyan: '#06b6d4',
  white: '#e4e4e7',
  brightBlack: '#52525b',
  brightRed: '#f87171',
  brightGreen: '#4ade80',
  brightYellow: '#facc15',
  brightBlue: '#60a5fa',
  brightMagenta: '#c084fc',
  brightCyan: '#22d3ee',
  brightWhite: '#fafafa',
};
```

#### 1.3 キーボードショートカット

| キー | アクション | 説明 |
|------|-----------|------|
| `Ctrl+Shift+C` | コピー | 選択テキストをコピー |
| `Ctrl+Shift+V` | ペースト | クリップボードから貼り付け |
| `Ctrl+Shift+F` | 検索 | 検索バー表示 |
| `Ctrl+Shift+K` | クリア | ターミナルクリア |
| `Ctrl+Shift+T` | 新規ターミナル | 新しいセッション作成 |
| `Ctrl+Shift+W` | 閉じる | 現在のセッション終了 |
| `Ctrl+Tab` | 次のターミナル | 次のセッションにフォーカス |
| `Ctrl+Shift+Tab` | 前のターミナル | 前のセッションにフォーカス |
| `Ctrl+1-4` | ターミナル切替 | 指定番号のセッション |
| `Escape` | 検索閉じる | 検索バーを閉じる |
| `F3` / `Shift+F3` | 次/前の検索結果 | 検索結果ナビゲーション |

### 2. スプリットビュー（SplitTerminal.tsx）

#### 2.1 レイアウトモード

```typescript
type SplitMode = 'single' | 'horizontal' | 'vertical' | 'quad';

interface SplitLayout {
  mode: SplitMode;
  panes: PaneConfig[];
}

interface PaneConfig {
  id: string;
  sessionId: string | null;
  size: number; // percentage
}

// レイアウト例
// single:     [████████████████]
// horizontal: [████████][████████]
// vertical:   [████████]
//             [████████]
// quad:       [████][████]
//             [████][████]
```

#### 2.2 コンポーネント構造

```
SplitTerminal/
├── index.tsx           # メインコンテナ
├── Pane.tsx            # 個別ペイン
├── Resizer.tsx         # ドラッグリサイザー
├── PaneHeader.tsx      # ペインヘッダー（タイトル、閉じるボタン）
└── LayoutSelector.tsx  # レイアウト選択UI
```

```tsx
// SplitTerminal/index.tsx
interface SplitTerminalProps {
  sessions: PTYSession[];
  layout: SplitLayout;
  onLayoutChange: (layout: SplitLayout) => void;
  onSendInput: (sessionId: string, data: string) => void;
  onResize: (sessionId: string, cols: number, rows: number) => void;
  onFocus: (sessionId: string) => void;
  onClose: (sessionId: string) => void;
}

export function SplitTerminal({
  sessions,
  layout,
  onLayoutChange,
  onSendInput,
  onResize,
  onFocus,
  onClose,
}: SplitTerminalProps) {
  // レイアウトに応じたグリッド生成
  const gridTemplate = useMemo(() => {
    switch (layout.mode) {
      case 'single':
        return { columns: '1fr', rows: '1fr' };
      case 'horizontal':
        return { columns: '1fr 1fr', rows: '1fr' };
      case 'vertical':
        return { columns: '1fr', rows: '1fr 1fr' };
      case 'quad':
        return { columns: '1fr 1fr', rows: '1fr 1fr' };
    }
  }, [layout.mode]);

  return (
    <div
      className="split-terminal"
      style={{
        display: 'grid',
        gridTemplateColumns: gridTemplate.columns,
        gridTemplateRows: gridTemplate.rows,
        gap: '2px',
        height: '100%',
      }}
    >
      {layout.panes.map((pane, index) => (
        <Pane
          key={pane.id}
          pane={pane}
          session={sessions.find(s => s.id === pane.sessionId)}
          onSendInput={onSendInput}
          onResize={onResize}
          onFocus={onFocus}
          onClose={onClose}
        />
      ))}
    </div>
  );
}
```

### 3. 検索機能（SearchBar.tsx）

```tsx
interface SearchBarProps {
  onSearch: (query: string, options: SearchOptions) => void;
  onNext: () => void;
  onPrevious: () => void;
  onClose: () => void;
  matchCount: number;
  currentMatch: number;
}

export function SearchBar({
  onSearch,
  onNext,
  onPrevious,
  onClose,
  matchCount,
  currentMatch,
}: SearchBarProps) {
  const [query, setQuery] = useState('');
  const [options, setOptions] = useState<SearchOptions>({
    caseSensitive: false,
    wholeWord: false,
    regex: false,
  });

  return (
    <div className="search-bar">
      <input
        type="text"
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          onSearch(e.target.value, options);
        }}
        placeholder="Search..."
        autoFocus
      />
      <span className="match-count">
        {matchCount > 0 ? `${currentMatch}/${matchCount}` : 'No results'}
      </span>
      <div className="search-options">
        <button
          className={options.caseSensitive ? 'active' : ''}
          onClick={() => {
            const newOptions = { ...options, caseSensitive: !options.caseSensitive };
            setOptions(newOptions);
            onSearch(query, newOptions);
          }}
          title="Case sensitive"
        >
          Aa
        </button>
        <button
          className={options.wholeWord ? 'active' : ''}
          onClick={() => {
            const newOptions = { ...options, wholeWord: !options.wholeWord };
            setOptions(newOptions);
            onSearch(query, newOptions);
          }}
          title="Whole word"
        >
          W
        </button>
        <button
          className={options.regex ? 'active' : ''}
          onClick={() => {
            const newOptions = { ...options, regex: !options.regex };
            setOptions(newOptions);
            onSearch(query, newOptions);
          }}
          title="Regex"
        >
          .*
        </button>
      </div>
      <button onClick={onPrevious} title="Previous (Shift+F3)">↑</button>
      <button onClick={onNext} title="Next (F3)">↓</button>
      <button onClick={onClose} title="Close (Escape)">×</button>
    </div>
  );
}
```

### 4. コマンドパレット（CommandPalette.tsx）

#### 4.1 統合コマンド

```typescript
interface Command {
  id: string;
  label: string;
  description: string;
  category: 'harness' | 'terminal' | 'navigation' | 'claude';
  shortcut?: string;
  action: () => void | Promise<void>;
}

// ハーネスコマンド
const harnessCommands: Command[] = [
  {
    id: 'harness:plan',
    label: '/plan-with-agent',
    description: 'Start planning phase with agent',
    category: 'harness',
    shortcut: 'Ctrl+Shift+P',
    action: () => sendToActiveTerminal('/plan-with-agent '),
  },
  {
    id: 'harness:work',
    label: '/work',
    description: 'Start work phase',
    category: 'harness',
    shortcut: 'Ctrl+Shift+W',
    action: () => sendToActiveTerminal('/work '),
  },
  {
    id: 'harness:review',
    label: '/harness-review',
    description: 'Run code review',
    category: 'harness',
    shortcut: 'Ctrl+Shift+R',
    action: () => sendToActiveTerminal('/harness-review\n'),
  },
];

// ターミナルコマンド
const terminalCommands: Command[] = [
  {
    id: 'terminal:new',
    label: 'New Terminal',
    description: 'Create a new terminal session',
    category: 'terminal',
    shortcut: 'Ctrl+Shift+T',
    action: () => createSession(),
  },
  {
    id: 'terminal:close',
    label: 'Close Terminal',
    description: 'Close the active terminal',
    category: 'terminal',
    shortcut: 'Ctrl+Shift+W',
    action: () => destroyActiveSession(),
  },
  {
    id: 'terminal:clear',
    label: 'Clear Terminal',
    description: 'Clear terminal output',
    category: 'terminal',
    shortcut: 'Ctrl+Shift+K',
    action: () => clearActiveTerminal(),
  },
  {
    id: 'terminal:split-h',
    label: 'Split Horizontal',
    description: 'Split terminal horizontally',
    category: 'terminal',
    action: () => setLayout('horizontal'),
  },
  {
    id: 'terminal:split-v',
    label: 'Split Vertical',
    description: 'Split terminal vertically',
    category: 'terminal',
    action: () => setLayout('vertical'),
  },
];
```

#### 4.2 コンポーネント

```tsx
interface CommandPaletteProps {
  isOpen: boolean;
  onClose: () => void;
  commands: Command[];
}

export function CommandPalette({ isOpen, onClose, commands }: CommandPaletteProps) {
  const [query, setQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);

  const filteredCommands = useMemo(() => {
    if (!query) return commands;
    const lower = query.toLowerCase();
    return commands.filter(
      (cmd) =>
        cmd.label.toLowerCase().includes(lower) ||
        cmd.description.toLowerCase().includes(lower)
    );
  }, [commands, query]);

  // キーボードナビゲーション
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex((i) => Math.min(i + 1, filteredCommands.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex((i) => Math.max(i - 1, 0));
        break;
      case 'Enter':
        e.preventDefault();
        if (filteredCommands[selectedIndex]) {
          filteredCommands[selectedIndex].action();
          onClose();
        }
        break;
      case 'Escape':
        onClose();
        break;
    }
  }, [filteredCommands, selectedIndex, onClose]);

  if (!isOpen) return null;

  return (
    <div className="command-palette-overlay" onClick={onClose}>
      <div className="command-palette" onClick={(e) => e.stopPropagation()}>
        <input
          type="text"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setSelectedIndex(0);
          }}
          onKeyDown={handleKeyDown}
          placeholder="Type a command..."
          autoFocus
        />
        <div className="command-list">
          {filteredCommands.map((cmd, index) => (
            <div
              key={cmd.id}
              className={`command-item ${index === selectedIndex ? 'selected' : ''}`}
              onClick={() => {
                cmd.action();
                onClose();
              }}
            >
              <span className="command-label">{cmd.label}</span>
              <span className="command-description">{cmd.description}</span>
              {cmd.shortcut && <span className="command-shortcut">{cmd.shortcut}</span>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

### 5. ログ永続化（LogStore）

#### 5.1 サーバー側

```typescript
// src/server/services/log-store.ts

interface LogEntry {
  timestamp: number;
  sessionId: string;
  data: string;
  type: 'output' | 'input';
}

interface LogFile {
  sessionId: string;
  projectId: string;
  startedAt: number;
  entries: LogEntry[];
}

export class LogStore {
  private logDir: string;
  private buffers: Map<string, LogEntry[]> = new Map();
  private flushInterval: ReturnType<typeof setInterval>;

  constructor(logDir: string = '.harness-logs') {
    this.logDir = logDir;
    this.ensureLogDir();
    this.flushInterval = setInterval(() => this.flushAll(), 5000);
  }

  private ensureLogDir(): void {
    if (!existsSync(this.logDir)) {
      mkdirSync(this.logDir, { recursive: true });
    }
  }

  append(sessionId: string, data: string, type: 'output' | 'input'): void {
    const entry: LogEntry = {
      timestamp: Date.now(),
      sessionId,
      data,
      type,
    };

    if (!this.buffers.has(sessionId)) {
      this.buffers.set(sessionId, []);
    }
    this.buffers.get(sessionId)!.push(entry);
  }

  async flush(sessionId: string): Promise<void> {
    const buffer = this.buffers.get(sessionId);
    if (!buffer || buffer.length === 0) return;

    const filePath = join(this.logDir, `${sessionId}.jsonl`);
    const lines = buffer.map((entry) => JSON.stringify(entry)).join('\n') + '\n';

    await appendFile(filePath, lines);
    this.buffers.set(sessionId, []);
  }

  async flushAll(): Promise<void> {
    for (const sessionId of this.buffers.keys()) {
      await this.flush(sessionId);
    }
  }

  async getFullLog(sessionId: string): Promise<LogEntry[]> {
    const filePath = join(this.logDir, `${sessionId}.jsonl`);
    if (!existsSync(filePath)) return [];

    const content = await readFile(filePath, 'utf-8');
    const lines = content.trim().split('\n');
    return lines.map((line) => JSON.parse(line) as LogEntry);
  }

  async search(sessionId: string, query: string): Promise<SearchResult[]> {
    const entries = await this.getFullLog(sessionId);
    const results: SearchResult[] = [];
    const regex = new RegExp(query, 'gi');

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const matches = entry.data.matchAll(regex);
      for (const match of matches) {
        results.push({
          lineIndex: i,
          columnIndex: match.index!,
          text: entry.data,
          timestamp: entry.timestamp,
        });
      }
    }

    return results;
  }

  async export(sessionId: string, format: 'json' | 'text'): Promise<string> {
    const entries = await this.getFullLog(sessionId);

    if (format === 'json') {
      return JSON.stringify(entries, null, 2);
    }

    return entries
      .map((entry) => {
        const time = new Date(entry.timestamp).toISOString();
        return `[${time}] ${entry.data}`;
      })
      .join('');
  }

  destroy(): void {
    clearInterval(this.flushInterval);
    this.flushAll();
  }
}

interface SearchResult {
  lineIndex: number;
  columnIndex: number;
  text: string;
  timestamp: number;
}
```

#### 5.2 API エンドポイント

```typescript
// 追加 API

// GET /api/sessions/:id/logs
// クエリ: ?offset=0&limit=1000
// レスポンス: { entries: LogEntry[], total: number }

// GET /api/sessions/:id/logs/search
// クエリ: ?q=pattern&regex=true
// レスポンス: { results: SearchResult[] }

// GET /api/sessions/:id/logs/export
// クエリ: ?format=json|text
// レスポンス: application/json または text/plain
```

### 6. セッション永続化

#### 6.1 セッション状態保存

```typescript
// src/server/services/session-store.ts

interface PersistedSession {
  id: string;
  projectId: string;
  worktreePath: string;
  phase: PTYSessionPhase;
  createdAt: number;
  lastActivity: number;
  scrollPosition: number;
}

export class SessionStore {
  private storePath: string;

  constructor(storePath: string = '.harness-sessions.json') {
    this.storePath = storePath;
  }

  async save(sessions: PTYSession[]): Promise<void> {
    const persisted = sessions.map((s) => ({
      id: s.id,
      projectId: s.projectId,
      worktreePath: s.worktreePath,
      phase: s.phase,
      createdAt: s.createdAt,
      lastActivity: s.lastActivity,
      scrollPosition: 0,
    }));

    await writeFile(this.storePath, JSON.stringify(persisted, null, 2));
  }

  async load(): Promise<PersistedSession[]> {
    if (!existsSync(this.storePath)) return [];

    const content = await readFile(this.storePath, 'utf-8');
    return JSON.parse(content) as PersistedSession[];
  }
}
```

#### 6.2 クライアント側復元

```typescript
// useSessionRestore.ts

export function useSessionRestore(
  sessions: PTYSession[],
  createSession: (projectId: string, worktreePath?: string) => void
) {
  const [restored, setRestored] = useState(false);

  useEffect(() => {
    if (restored) return;

    const savedLayout = localStorage.getItem('harness-terminal-layout');
    const savedFocused = localStorage.getItem('harness-focused-terminal');

    if (savedLayout) {
      try {
        const layout = JSON.parse(savedLayout);
        // レイアウト復元ロジック
      } catch {
        // ignore
      }
    }

    setRestored(true);
  }, [restored]);

  // 変更時に自動保存
  useEffect(() => {
    if (!restored) return;

    localStorage.setItem('harness-terminal-layout', JSON.stringify(layout));
  }, [layout, restored]);
}
```

### 7. Claude 連携

#### 7.1 状態検出の強化

```typescript
// pty-manager.ts の detectStatus を拡張

interface ClaudeState {
  status: 'idle' | 'thinking' | 'tool_use' | 'waiting_input' | 'complete';
  currentTool?: string;
  progress?: number;
  lastMessage?: string;
}

private detectClaudeState(data: string): ClaudeState | null {
  // ツール実行中
  const toolMatch = data.match(/Using tool: (\w+)/);
  if (toolMatch) {
    return { status: 'tool_use', currentTool: toolMatch[1] };
  }

  // 思考中
  if (data.includes('Thinking...') || data.includes('⠋') || data.includes('⠙')) {
    return { status: 'thinking' };
  }

  // 入力待ち
  const waitingPatterns = [
    /Do you want to proceed/i,
    /\[y\/N\]/i,
    /\[Y\/n\]/i,
    /Press Enter/i,
    /waiting for/i,
  ];
  for (const pattern of waitingPatterns) {
    if (pattern.test(data)) {
      return { status: 'waiting_input', lastMessage: data };
    }
  }

  // 完了
  if (data.includes('Done.') || data.includes('Completed.')) {
    return { status: 'complete' };
  }

  return null;
}
```

#### 7.2 進捗インジケーター

```tsx
// ClaudeProgress.tsx

interface ClaudeProgressProps {
  state: ClaudeState;
}

export function ClaudeProgress({ state }: ClaudeProgressProps) {
  if (state.status === 'idle') return null;

  return (
    <div className="claude-progress">
      {state.status === 'thinking' && (
        <div className="thinking">
          <span className="spinner">⠋</span>
          Thinking...
        </div>
      )}
      {state.status === 'tool_use' && (
        <div className="tool-use">
          <span className="tool-icon">🔧</span>
          Using: {state.currentTool}
        </div>
      )}
      {state.status === 'waiting_input' && (
        <div className="waiting">
          <span className="pulse">●</span>
          Waiting for input...
        </div>
      )}
      {state.status === 'complete' && (
        <div className="complete">
          <span className="check">✓</span>
          Complete
        </div>
      )}
    </div>
  );
}
```

---

## ファイル構成

```
harness-ui/src/
├── client/
│   ├── components/
│   │   ├── Terminal/
│   │   │   ├── index.tsx           # 拡張版 Terminal
│   │   │   ├── SearchBar.tsx       # 検索UI
│   │   │   ├── ClaudeProgress.tsx  # Claude状態表示
│   │   │   └── useTerminalShortcuts.ts
│   │   ├── SplitTerminal/
│   │   │   ├── index.tsx           # スプリットコンテナ
│   │   │   ├── Pane.tsx
│   │   │   ├── Resizer.tsx
│   │   │   └── LayoutSelector.tsx
│   │   ├── CommandPalette/
│   │   │   ├── index.tsx
│   │   │   └── commands.ts         # コマンド定義
│   │   └── TerminalCards.tsx       # 既存拡張
│   ├── hooks/
│   │   ├── useTerminal.ts          # ターミナル制御
│   │   ├── useSearch.ts            # 検索機能
│   │   ├── useSessionRestore.ts    # セッション復元
│   │   └── useShortcuts.ts         # キーボード
│   └── styles/
│       ├── terminal.css
│       └── command-palette.css
├── server/
│   ├── services/
│   │   ├── pty-manager.ts          # 既存拡張
│   │   ├── log-store.ts            # NEW: ログ永続化
│   │   └── session-store.ts        # NEW: セッション永続化
│   └── routes/
│       └── logs.ts                 # NEW: ログ API
└── shared/
    └── types.ts                    # 型定義拡張
```

---

## 実装優先順位

### Phase 1: 基盤強化（必須）
1. [ ] SearchAddon 統合
2. [ ] WebLinksAddon 統合
3. [ ] キーボードショートカット
4. [ ] ログ永続化（LogStore）

### Phase 2: UI拡張
5. [ ] SearchBar コンポーネント
6. [ ] CommandPalette コンポーネント
7. [ ] スプリットビュー基本

### Phase 3: 連携強化
8. [ ] Claude 状態検出強化
9. [ ] 進捗インジケーター
10. [ ] セッション復元

### Phase 4: 高度な機能
11. [ ] ログエクスポート
12. [ ] 複雑なスプリットレイアウト
13. [ ] セッション間連携

---

## 技術制約

- xterm.js v5.3.0 使用（既存）
- Bun.spawn の terminal オプション使用（既存）
- WebSocket でリアルタイム通信（既存）
- ログは JSONL 形式で保存
- テーマは Tailwind カラーに準拠

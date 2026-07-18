# Hardening Parity

最終更新: 2026-07-09 (Phase 111.0)

この文書は、Harness が **複数 host** でどこまで同じ安全性を提供するかを整理する
共通ポリシーです。

ポイントは次の 3 つです。

- 共通化するのは「何を危険とみなすか」という**ポリシー**（R01–R13 + runtime floor）
- 実装は host の native pre-action hook と codec に合わせて分ける
- **同じ capability 名でも enforcement 強度は host ごとに違う**（false parity 禁止）

## Shared kernel (3cli hook floor)

Claude Code (`PreToolUse`)、Codex CLI (`PreToolUse`, **Bash-only**)、Cursor
(`preToolUse`) は、生成 hook 経由で同じ入口に集まります:

```text
host native hook → bin/harness hook pre-tool --host <claude|codex|cursor>
                → runtimefloor + R01–R13 policy
                → exit 2 + host deny envelope
```

証拠と詳細: `docs/research/3cli-hook-floor-contract-2026-06.md`、
`hosts.toml`、`bash tests/test-3cli-hook-floor.sh`。

**Grok は現状 floor 対象外**です。Grok に PreToolUse 級 deny を主張してはいけません。

## Policy Matrix

| Policy | 例 | Severity | Claude Code | Codex CLI | Cursor |
|--------|----|----------|-------------|-----------|--------|
| No verification bypass | `git commit --no-verify` | Deny | PreToolUse deny | Bash PreToolUse floor + quality gate | preToolUse deny (when hooked) |
| Protected branch destructive reset | `git reset --hard main` | Deny | PreToolUse deny | Bash PreToolUse floor + quality gate | preToolUse deny (when hooked) |
| Direct push to protected branch | `git push origin main` | Confirm/Deny | PreToolUse | Bash floor + merge gate 推奨 | preToolUse + Lead/merge discipline |
| Force push | `git push --force` | Deny | PreToolUse deny | Bash PreToolUse floor + merge gate | preToolUse deny (when hooked) |
| Protected files editing | `package.json`, workflows 等 | Warn/Fail | PreToolUse warn | quality gate fail (強め) | guidance + outer review |
| Pre-push secrets scan | token-like string | Deny | Bash 前 deny または fail | Bash floor + quality gate | preToolUse when shell is mapped |

## Protected Files Profile

既定の protected files は「壊れると影響が広いが、通常の実装では毎回は触らない」ものに絞ります。

- `package.json`
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/*.yml`
- `.github/workflows/*.yaml`
- `schema.prisma`
- `wrangler.toml`
- `index.html`

設計意図:

- **deny ではなく warn を基本**にする（正当な変更はある）
- `.env` や秘密鍵は **別ルールで deny**（protected path）
- Codex の merge gate は protected files を **fail 扱い**しやすい

## Runtime Mapping

### Claude Code

- **PreToolUse**: 複数 tool 種別で実行前 deny / ask / warn
- **PostToolUse**: 書き込み後の警告
- **PermissionRequest**: 安全な read-only / test の自動許可

### Codex CLI

Codex は **hook を持つ**（2026-06 3cli floor 以降）。ただし:

1. **PreToolUse は Bash のみ**
   non-Bash（例: Read `~/.ssh/...`）は hook で hard-deny されない
2. **実行前 contract 注入**
   companion / instructions に禁止事項を明示
3. **post-exec quality gate + merge gate**
   通らない成果物は main に取り込まない
4. **worktree fingerprint**
   敏感 path の事後差分で補完

「Codex に hook が無い」は **古い記述**です。正しい短文は
**「Bash PreToolUse floor + 事後ゲート。non-Bash は Claude と非対称」**。

### Cursor

- Project `.cursor/hooks.json` → `harness hook pre-tool --host cursor`
- Live deny は Phase 83.7 で観測済み（protected path Write 阻止）
- **伝統的な FS jail はない**（公式 security ドキュメント + spike 知見）
- permissions allowlist は **best-effort**（security guarantee ではない）
- non-exit-2 は fail-open になり得る

### Grok

- Plugin install / skill discovery は candidate 証拠
- Harness 共有 pre-tool floor の **メンバーではない**
- SessionStart / PreToolUse 同等を主張しない

## Known Asymmetry

| 項目 | Claude Code | Codex CLI | Cursor | Grok |
|------|-------------|-----------|--------|------|
| 実行前中断 | 強い（多 tool） | Bash のみ強い | tool deny 可 | 未 claim |
| FS 閉じ込め | 権限モデル依存 | worktree + fingerprint | **弱い / なし** | 未 claim |
| コマンド単位 deny | 強い | Bash floor | 強いが fail-open あり | 未 claim |
| main 取り込み前の阻止 | 可能 | merge gate | Lead review + cherry-pick | 運用依存 |
| Floor membership | yes | yes | yes | **no** |

要するに:

- **Claude Code** はその場で広く止めるのが得意
- **Codex CLI** は Bash の事前停止 + 出力を通さない二段
- **Cursor** は deny できるが containment を host に任せられない
- **Grok** はまだ shared floor 外

## Operator Guidance

- 安全性を最優先する作業は Claude Code 経路を優先する
- Codex は実装・レビュー補助として使い、main 取り込み前に quality gate を通す
- Cursor write は dedicated worktree + Lead review + cherry-pick を前提にする
- Grok で危険操作の実行前停止を期待しない（現状の tier が `candidate` な理由）

## Validation Surface

- `docs/tool-capability-matrix.md` の `pre_use_guard` 行と矛盾しないこと
- `bash tests/test-3cli-hook-floor.sh`（3cli）
- `bash tests/test-support-claim-wording.sh`（公開文言）
- host 昇格は H1–H8（`docs/spec/planning-and-host-adapter.md`）を同一 claim path で満たすこと

## Related

- `docs/research/3cli-hook-floor-contract-2026-06.md`
- `docs/research/cursor-adapter-candidate.md`
- `docs/research/grok-adapter-candidate.md`
- `docs/plans/phase-111-multi-host-supported.md`

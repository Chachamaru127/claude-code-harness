# Phase 110: Post-v5.0.0 Operator Closeout

**Status (2026-07-09):** executed (110.0 skipped by operator — no confirmed leak)

| Task | Status |
|------|--------|
| 110.0 token rotation | skipped (no confirmed leak; `/.codex/` already gitignored) |
| 110.1 tree align | done — `archive/local-main-pre-v5` @ ed6b18c9, main @ c100dbb4+ |
| 110.2 109.5 marker | done in Plans.md |
| 110.3 HOTL + EN | done — A research draft (`docs/research/README_HOTL_ja.md`), EN=No |
| 110.4 Dependabot | done triage — #232/#234/#230 auto-merge queued; #233 deferred; vitest alerts accept-risk (bench-only) |
| 110.5 salvage | done — all drop, archive retained |
| 110.6 closeout | done with this commit |

---

创建日期: 2026-07-09  
前提: v5.0.0 "Zero-Base Redesign Mainline" 已发布  
Release: https://github.com/Chachamaru127/claude-code-harness/releases/tag/v5.0.0  
origin/main: `c100dbb4`  
Plans 正本: **origin/main 的 Plans.md**（local main 是 pre-redesign 树，15 ahead / 249 behind — 非正本）

## Spec skip reason

不改变 Product behavior / API / 分发 contract 的 operator hygiene + ledger sync。
- 110.1–110.2: git/workspace alignment + marker（仅限 task ledger）
- 110.3: secret rotation（ops、无代码变更）
- 110.4: docs owner judgment（README_HOTL claim surface — 仅在改变公开 claim 时后续 Spec delta）
- 110.5: Dependabot triage（deps、redesign 后的重新评估）
- 110.6: optional local-value salvage（如果 port 触及 product 则升格到另一个 Phase）

`team_validation_mode: manual-pass`（Product / Architecture / Security / QA / Skeptic 已单独分离评价。依据见本文件"验证备忘录"）。

---

## 进度摘要（harness-sync 2026-07-09）

| 面 | 状态 |
|----|------|
| GitHub Release v5.0.0 | 已发布・draft=false・asset 4 |
| origin Plans 109.0–109.4 | cc:done |
| origin Plans **109.5** | **cc:todo 的状态（drift）** — 实际作业已完成 |
| local `VERSION` | 4.16.4（stale） |
| origin `VERSION` | 5.0.0 |
| local Plans.md | Phase 96 为止（无 redesign Phase 91–109） |
| local branch | main, **15 ahead / 249 behind** origin/main |
| working tree | dirty: model-routing Sonnet5 / agents / README HOTL 追加 / binaries / Plans 94.4 marker / `.gitignore` `/.codex/` / untracked `README_HOTL_ja.md` |
| Dependabot alerts | open **21**（vitest CRITICAL 系占大部分 + @ai-sdk/provider-utils LOW） |
| Dependabot PRs open | #230 #232 #233 #234（+ #228 Phase97 是别的事项） |
| Secrets | `.codex/environments/environment.toml` 有 GH_TOKEN / FIRECRAWL_API_KEY 明文（**git 非追踪**。working-tree `.gitignore` 已添加 `/.codex/` 未 commit） |

### Drift 检测表

| Task | 当前 (origin Plans) | 变更后 | 理由 |
|------|---------------------|--------|------|
| 109.5 | cc:todo | cc:done [c100dbb4 / v5.0.0] | PR #235+#236 merge, tag, 4 assets, EN notes 完毕 |
| 94.4 (local only) | cc:wip → dirty cc:done | **discard with local tree** | origin redesign 树中 94.4 是不同的 lineage。local closeout 是 109.1 port 对象 |

### 本地 15 commit 的判定（推荐）

`git cherry` 显示 15 个全部为 `+`（未取用 patch-id）。但**109.1 已功能 port 了 4 条 guard**并记录在台账。skill prune / progressive disclosure 容易与 redesign 线的 skill 树（例如 origin `harness-work` ~1010 行 vs local ~509 行）冲突。

| 群 | commits | 推荐 |
|----|---------|------|
| guard Phase94 closeout | 462e94ff…ed6b18c9 | **drop**（109.1a 已 port。差分残留的话在 110.6 做 spot-check） |
| skill prune / progressive disclosure | fa88d4cf…7405c30d + d199ef91 | **archive then drop by default**。如需要则在 origin 上重新实现 |
| wip HOTL wiring | f6cdb042 | **salvage 候选**（plan-brief/accept/progress）。origin 已有 skill，需按 diff 单位判断必要性 |
| merge skill-prune | 8ca82ced | drop with parents |
| dirty uncommitted model-routing | working tree | **drop**（origin 已有 sonnet-5） |
| dirty README HOTL 3 画面追加 | working tree | 与 f6cdb042 汇总到 110.4/110.6 |
| untracked README_HOTL_ja.md | working tree | **keep as review artifact**（110.4） |
| `.gitignore` `/.codex/` | working tree | **keep and commit on origin tree**（与 110.3 配套） |

### 回顾（v5.0.0）

| 指标 | 值 |
|------|-----|
| 已完成里程碑 | Phase 109 release done |
| 阻塞项 | release preflight clean-checkout 伪 green（生成物残留） |
| 教训 | 生成物 assert 需 materialize-then-verify（FACT-4）。$HOME plugin fallback 也属于同型 |
| 下次改进 | release-preflight / 生成物测试需固定为 clean checkout 前提 |

---

## Phase 110 任务（适用于 origin Plans.md）

适用时机: **110.1 完成后**在 origin/main 上的 `Plans.md` 追加 + 更新 109.5 marker。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 110.0 | `[lane:gate]` `[tdd:skip:ops]` **token rotation（P0）**。`.codex/environments/` 中有明文 `GH_TOKEN` / `FIRECRAWL_API_KEY`。**revoke → 重新发行 → 新值注入 env**（不在文件中留明文）。以旧值可能已出现在 agent log / session transcript 为前提处理 | (a) 旧 GH PAT 已在 GitHub 上 revoke、(b) 旧 Firecrawl key 已 invalidate、(c) 新 secret 仅在 shell env / secret manager 中（repo 内明文 0）、(d) `/.codex/` 在 origin 树上 commit 时被 `.gitignore` 忽略 | - | cc:TODO |
| 110.1 | `[lane:gate]` `[tdd:skip:git-ops]` **将 local main 对齐到 origin/main (`c100dbb4`)**。推荐: (1) 将 dirty 退避到 `git stash -u` 或 `archive/local-main-pre-v5` 分支、(2) `git branch archive/local-main-pre-v5 HEAD`、(3) `git switch main && git reset --hard origin/main`、(4) 仅从 stash 重新应用 **README_HOTL_ja.md** 和 **`.gitignore /.codex/`**。不推荐将 15 commit 整个 rebase（与 249 commit redesign 的冲突成本过大） | (a) `git rev-parse HEAD` == `origin/main`、(b) `VERSION` == `5.0.0`、(c) Plans.md 中存在 Phase 109、(d) archive branch 残留、(e) working tree 中无不想要的 binary/model-routing dirty | - | cc:TODO |
| 110.2 | `[lane:gate]` `[tdd:skip:ledger]` **将 109.5 marker 设为 cc:done**。evidence: PR #235 `970dff0d`, PR #236 `c100dbb4`, tag `v5.0.0`, assets=4, notes EN+Before/After。可在 Phase 109 Purpose 追加 1 行 release URL | (a) 109.5 Status 为 `cc:done [c100dbb4]`、(b) Status 或 Purpose 中残留满足 DoD (a)(b)(c) 的 evidence、(c) `rg '109\.5.*cc:todo' Plans.md` 为 0 | 110.1 | cc:TODO |
| 110.3 | `[lane:release]` `[tdd:skip:docs-only]` **README_HOTL_ja.md owner 审查 + EN 判断**。S0 已指出"言行不一致"（Bridge Daemon / Decision Card 未接线 vs ✅ 标注）。判定: (A) 保持为内部メモ gitignore/local-only、(B) 升格到公开 README 则将 claim 降为带 evidence、(C) 制作 EN 版或 skip | (a) owner 在 decisions.md 或 Plans Status 中留下了选择 A/B/C 的记录、(b) B 的情况下 ✅/🔜 与 origin 实现 evidence 一致、(c) EN 是否必要已确定为 Yes/No、(d) 如公开则 `git diff --check` PASS | 110.1 | cc:TODO |
| 110.4 | `[lane:release]` `[tdd:skip:dependency-triage]` **Dependabot 重新评估（21 alerts / open PRs）**。在 redesign 主线化后的 default branch 上: (i) 对 vitest CRITICAL 分类为在 `benchmarks/` 目录下还是 production path、(ii) #230/#232/#234 Actions bump 如果 CI green 则是 merge 候选、(iii) #233 agent-eval major 保持 bench 隔离并个别判断、(iv) 对 alert 执行 close or accept risk 记录 | (a) 将 21 alerts 按 path×severity 分类制表、(b) 各 PR/alert 附有 merge / defer / accept-risk、(c) production runtime path 的 CRITICAL 为 0 或已 issue 化、(d) 与 Supply Chain Alert Contract 不矛盾 | 110.1 | cc:TODO |
| 110.5 | `[lane:fast]` `[tdd:skip:optional-salvage]` **local-only 价值的取舍**。遍历 archive 15 commit + stash，仅 cherry-pick 或重新实现 origin 中没有的差分。默认: guard 群 skip / model-routing skip / skill prune 以 origin redesign 优先 skip / HOTL wiring 仅在 110.3 结果为 B 时 port | (a) 在 Plans 或 mem 中保留对 archive 的 keep/drop 表、(b) keep 为 0 则以 cc:done 关闭 task、(c) keep>0 则添加以 focused test + review 为 DoD 的子 task | 110.1, 110.2 | cc:TODO |
| 110.6 | `[Closeout]` `[lane:release]` `[tdd:skip:test-aggregation]` Phase 110 closeout。不制作 release/tag | (a) 110.0–110.4 done（110.5 可 skip）、(b) `bash tests/validate-plugin.sh` 在 origin 树上 PASS、(c) `git status` clean 或仅有想要的 untracked、(d) GOD_plans §8 M6/M token 状态已更新、(e) 无 tag | 110.0, 110.2, 110.3, 110.4 | cc:TODO |

---

## 执行顺序（推荐）

```
110.0 token rotation     ← 今すぐ（他と並列可、最優先）
110.1 tree align         ← Risk Gate: reset --hard（archive 必須）
110.2 109.5 marker       ← harness-sync 一発
110.3 HOTL README 判断   ← owner のみ
110.4 Dependabot triage  ← 機械分類は agent、merge は GO
110.5 salvage (optional)
110.6 closeout
```

### 不推荐

- 将 local 15 commit 以 `git rebase origin/main` 全部搬上去（冲突地狱、guard 双重化）
- 将 dirty binary 4 个带入 origin
- 不重新发行 token 就 commit `.codex/environments`

---

## 验证备忘录（manual-pass perspectives）

| 视角 | 所见 |
|------|------|
| Product | v5.0.0 已出货。剩余的是 hygiene。HOTL README 的 ✅ 是 claim risk（S0 已知） |
| Architecture | Plans/SSOT 正本是 origin redesign。local 4.16 树是 archive 对象 |
| Security | **token rotation P0**。Dependabot vitest 先分类 path（bench 隔离则可 accept-risk） |
| QA | 109.5 DoD 以 release URL + assets 满足。validate-plugin 在 110.1 后重新运行 |
| Skeptic | "14 commit rebase"看起来工作量很大，但其中大部分已 port 完毕或树不同。reset+archive 更安全 |

---

## 109.5 marker 更新用 1 行（110.2）

```markdown
| 109.5 | ... | ... | 109.4 | cc:done [c100dbb4] (PR #235+#236, tag v5.0.0, assets=4, EN notes 2026-07-09) |
```

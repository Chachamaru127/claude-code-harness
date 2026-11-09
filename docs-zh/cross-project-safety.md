# 跨项目搜索时的 3 层防御（Phase 65.3）

想要引用其他项目中过去的判断和知识，但不希望客户名、人名、公司名等**固有名词混入**。
为此分为 3 层，用 redaction（黑化）机制防止固有名词泄露。

## 想要实现的事

通常，Claude harness 的搜索**仅限于当前项目**（默认安全）。

但是，当需要汇集类似案件的知识时，可以通过 `--cross-project-group <name>` flag 启用跨项目搜索。
此时，**其他项目的固有名词不会泄露到当前项目的 HTML 中**，通过 3 层防御。

## 方法

### 小组定义（前提准备）

在 `.claude/rules/cross-project-groups.yaml` 中列出 member project：

```yaml
schema_version: cross-project-group.v1
groups:
  - name: PersonalTools
    members:
      - my-cli
      - my-dotfiles
      - my-scripts
```

详见 [cross-project-groups-schema.md](cross-project-groups-schema.md)

### 启用跨项目搜索

```bash
# Plan Brief で横断検索を使う
/harness-plan-brief --cross-project-group "PersonalTools"
```

或者 skill 侧 SKILL.md 的 Step 2 (alt) 中描述的 MCP N-call 流程自动应用。

### 3 层 redaction 的作用

当跨项目搜索被启用时，在 HTML 生成时自动执行以下操作：

#### Layer 1：harness-mem 服务器端（Cross-Contract，不同 repo）

- `<private>` 块的 strip（服务器出口必执行，opt-out 不可）
- `strict_project: true` 为默认（但通过 MCP 传递时目前不变，Phase 65.3.5 对应 N-call）
- 实现：`harness-mem/memory-server/src/core/privacy-tags.ts`

#### Layer 2a：基于词典的固有名词 redaction（客户端）

- 从 `.claude/rules/client-redaction.yaml` 的词典进行 literal string match
- 示例：`NoraiCorp` → `[Client_A]`、`田中太郎` → `[Person_A]`
- 实现：`scripts/redact-by-dictionary.sh`（PiiRule 兼容 schema）

#### Layer 2b：NER（命名实体识别）redaction（客户端）

- 使用 Japanese tokenizer（fugashi + UniDic-lite）进行形态素分析
- pos2 == "固有名词" 的 token 替换为 `[Entity]`
- 连续的固有名词 token 合并为 1 个 [Entity]
- tokenizer 不存在时 **fail-open**（原文保留 + stderr 警告）
- 实现：`scripts/redact-by-ner.sh`

#### Layer 3：最终 sanity scan（客户端）

- 在 HTML 生成前，排除 template chrome（CSS/HTML comment）后进行 scan
- 将连续 5 个以上片假名检测为"残留"
- 检测时 **不生成 HTML 并 exit 1**（fail-safe）
- 实现：`scripts/render-html.sh --with-redaction` + `scripts/final-scan-redaction.py`

### 审计日志

每次执行跨项目搜索时，向 `.claude/state/audit/cross-project-search.jsonl` 追加 1 行：

```json
{
  "schema_version": "cross-project-audit.v1",
  "timestamp": "2026-05-09T12:00:00Z",
  "group_name": "PersonalTools",
  "member_projects": ["my-cli", "my-dotfiles"],
  "query_hash": "<sha256 64 chars>",
  "redaction_count": {"dict": 2, "ner": 1},
  "output_passed_final_scan": true
}
```

实际查询字符串**不记录**（隐私），仅记录 sha256 hash。

生成的 HTML 末尾显示"redacted: dict X 件 + NER Y 件"。

## 注意事项

### 1. Layer 1 在服务器端（不同 repo），不从 claude-code-harness 操作

作为 cross-repo handoff workflow（D42）的边界，Layer 1 在 harness-mem 侧完成。
即使客户端创建了包含 `<private>` 的新 fixture，通过服务器途经一定会被 strip（opt-out 不可）。

### 2. NER tokenizer 是 opt-in 依赖

`scripts/redact-by-ner.sh` 使用 fugashi（Python tokenizer）。
安装情况：
- 环境中存在则自动使用（确认：`python3 -c "from fugashi import Tagger"`）
- 不存在则 fail-open（仅用 Layer 2a + Layer 3 运行）

需要完整 NER 覆盖率时执行 `pip install fugashi unidic-lite`。

### 3. Layer 3 final scan 是 fail-safe

检测到连续 5 个以上片假名时，HTML **不生成并 exit 1**。
不生成比"泄露的 HTML 被公开"更安全的判断。

template 作者的有意 branding（例如 CSS comment 中的 `ハーネスオレンジ`）被排除
（template chrome strip 使 `<!-- -->` `/* */` `<style>` `<script>` 不在 scan 范围内）。

### 4. 现有服务器端 sentinel `[REDACTED_*]` 的双重替换防护

mem 侧 `event-recorder.ts:redactContent` 输出的 `[REDACTED_EMAIL]` `[REDACTED_KEY]` `[REDACTED_SECRET]` `[REDACTED_HEX]`，
防止客户端 Layer 2 再次 redaction，通过 sentinel 暂存 → redaction → 还原的 3 步实现。
正则 `[A-Za-z0-9_]+` 应对大小写。

### 5. 跨项目 default 为 OFF

不指定 `--cross-project-group` flag 时，搜索仅限于当前项目（Phase 65.1.x 的行为）。
不显式 opt-in 不会执行跨项目搜索。

### 6. 审计日志中不保留原始查询

`query_hash` 仅记录 sha256（64 字符 hex）。
由于无法还原，泄露时实际查询内容也受保护。

## 相关

- [cross-project-groups-schema.md](cross-project-groups-schema.md) — 小组设置方法
- [cognitive-load-surfaces.md](cognitive-load-surfaces.md) — 3 surface 的作用
- `.claude/rules/cross-repo-handoff.md` — D42（claude-code-harness ↔ harness-mem 边界）
- `.claude/memory/decisions.md` D43（本功能的设计判断，4 判断包）

## 相关脚本

| 脚本 | 作用 |
|----------|------|
| `scripts/load-cross-project-groups.sh` | 读取 yaml SSOT 解析 member projects |
| `scripts/redact-by-dictionary.sh` | Layer 2a 词典 redaction |
| `scripts/redact-by-ner.sh` | Layer 2b NER redaction |
| `scripts/final-scan-redaction.py` | Layer 3 最终 scan |
| `scripts/render-html.sh --with-redaction` | 依次应用 3 层生成 HTML |
| `scripts/cross-project-audit-log.sh` | 审计日志 append |

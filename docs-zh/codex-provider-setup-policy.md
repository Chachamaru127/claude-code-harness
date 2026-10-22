# Codex Provider Setup Policy

最终更新: 2026-08-22

本文档是为了将 Codex `0.123.0` 添加的 provider 和 model metadata、以及 Codex `0.130.0` stable 明确的 Bedrock 认证的处理固定为 Harness 的 Codex setup guidance。

## 一句话总结

Harness 引导 Codex 的 provider 选择，但不在分发的 `config.toml` 中擅自固定 `model` 或 `model_provider`。

## 打个比方

Codex 本体是车站的检票机。
Harness 是指示该往哪个检票口走的指示牌。
因为如果指示牌擅自重做检票机，就无法跟上车站侧的改造。

## 官方参考

- OpenAI Codex `rust-v0.123.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.123.0>
- OpenAI Codex `rust-v0.130.0` stable release: <https://github.com/openai/codex/releases/tag/rust-v0.130.0> (published `2026-05-08T23:09:55Z`)
- Codex Amazon Bedrock provider PR: <https://github.com/openai/codex/pull/18744>
- Codex config basics: <https://developers.openai.com/codex/config-basic>
- Codex config reference: <https://developers.openai.com/codex/config-reference>
- Codex models and ChatGPT-sign-in retirement guidance: <https://developers.openai.com/codex/models>
- Amazon Bedrock OpenAI model docs: <https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-openai.html>

## 对象和判断

| 项目 | 用途 | Harness 判断 |
|------|------|--------------|
| `amazon-bedrock` | Codex 的 built-in Amazon Bedrock provider | 作为 Codex `0.123.0` 之后的标准 provider 引导 |
| `model_provider` | 选择 Codex 使用的 provider 的设置 | 仅 Bedrock 用户在 user / project config 中设置。Harness 分发 default 不包含 |
| `model_providers.amazon-bedrock.aws.profile` | 选择 AWS profile 的设置 | 将认证信息放在 AWS 侧，Harness 仅显示 profile 名的示例 |
| `aws login` / console-login credentials | 通过 AWS profile 使用 AWS console-login credential 的认证路径 | 作为 Codex `0.130.0` stable 的 Bedrock auth 引导。Harness 不写 credential 本体 |
| `model` | 固定 Codex 使用的 model 的设置 | 仅在需要再现性时在 user / project config 中指定。Harness setup default 不固定 |
| `gpt-5.4` / `gpt-5.4-mini` | ChatGPT 登录时在 2026-08-31 从 Codex 退休的 model | 仅明示迁移到 `gpt-5.6-terra` / `gpt-5.6-luna`，不固定在分发 config 的 default 中 |
| Claude Code Bedrock guidance | Claude Code 端处理 Bedrock / Vertex / custom gateway 的设置 | 不要与 Codex 的 `amazon-bedrock` provider 混用。Claude 侧是 `CLAUDE_CODE_USE_BEDROCK` 和 Anthropic model overrides 的领域 |

## Codex `amazon-bedrock` provider

Codex `0.123.0` 中，`amazon-bedrock` 成为了 built-in provider。
不需要像以前那样将 Bedrock 用的 provider 定义整体复制到 `config.toml`。

仅使用 Bedrock 的 user / project 按如下设置 provider 和 AWS profile。

```toml
model_provider = "amazon-bedrock"

[model_providers.amazon-bedrock.aws]
profile = "codex-bedrock"
```

此例中的 `codex-bedrock` 是 AWS profile 名。
实际的 profile 名、AWS region、认证信息要与各环境的 AWS 设置匹配。
Harness 不写入 AWS credential、temporary token、secret key。

Codex `0.130.0` stable (`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) 中，Bedrock auth 可以使用 `aws login` profile 的 AWS console-login credentials 了。
Harness 的处理方式不变。

- `aws login` 和 AWS console-login credential 的执行/保存是 AWS 侧的职责。
- Harness 仅显示 profile 名的放置位置，不生成/复制/保存 AWS access key、secret key、session token、console-login cache。
- 分发的 `codex/.codex/config.toml` default 中不启用 `model_provider = "amazon-bedrock"`。
- 仅使用 Bedrock 的 project / user 在自己的 config 中明示 `model_provider` 和 profile。

也就是说，console-login credentials 作为 "AWS profile 的内容" 处理，Harness 的 template 和 setup 不触及 credential material。

## Model default and migration policy

The official Codex models guidance states:

> GPT-5.4 and GPT-5.4 mini retire from Codex with ChatGPT sign-in on August 31, 2026.
> If you sign in with ChatGPT, replace `gpt-5.4` with `gpt-5.6-terra` and `gpt-5.4-mini` with `gpt-5.6-luna`.
> The OpenAI API and Codex authenticated with your own API key aren't affected.

Harness 方针:

- 未指定 config 继承 provider/account/CLI recommended model，不假设固定的 gpt-5.4 default。
- Harness 分发的 `codex/.codex/config.toml` 保持 `model` 为 unset。
- `scripts/setup-codex.sh` 和 `$harness-setup codex` 不擅自替换用户的现有 `model`。
- 需要固定 model 时，用户在 `~/.codex/config.toml` 或 project `.codex/config.toml` 中明示。
- 不要将旧的 `gpt-5.2-codex` 或 `gpt-5-codex` 作为当前推荐示例新引导。

ChatGPT 登录的已保存设置迁移示例:

```toml
# 旧 gpt-5.4 の明示 pin を移行する場合
model = "gpt-5.6-terra"

# 旧 gpt-5.4-mini の明示 pin を移行する場合
model = "gpt-5.6-luna"
```

通常省略 `model`，委托给 provider/account/CLI recommended model。
API key 认证的 Codex 不受 GPT-5.4 retirement 影响。

## Claude Code guidance との切り分け

Claude Code 端的 Bedrock guidance 是通过 Bedrock / Vertex / custom gateway 使用 Anthropic model 的事情。
与 Codex 的 `amazon-bedrock` provider 设置键和职责不同。

| 运行时 | 主要设置 | Harness 的处理 |
|------------|----------|----------------|
| Codex CLI | `model_provider = "amazon-bedrock"`、`[model_providers.amazon-bedrock.aws]` | 作为 Codex setup guidance 引导 |
| Claude Code | `CLAUDE_CODE_USE_BEDROCK`、`ANTHROPIC_DEFAULT_*`、`modelOverrides` | 作为 Claude Code / Anthropic model guidance 处理 |

即使在同一 repository 中使用两者，也不要混合设置。
改变 Codex 的 provider 不会自动启用 Claude Code 的 Bedrock mode。
改变 Claude Code 的 Bedrock 设置也不会自动改变 Codex 的 `model_provider`。

## Verification record

2026-08-22 确认了官方 Codex models guidance 和分发设置的 model policy。

```bash
rg -n "gpt-5\\.2-codex|gpt-5-codex|gpt-5\\.1|codex-mini|gpt-5\\.3-codex|gpt-5\\.4" \
  docs skills codex skills-codex scripts tests templates .claude-plugin opencode .agents -u
```

判断:

- `gpt-5.4` / `gpt-5.4-mini` 仅作为 ChatGPT 登录端的迁移源标识符保留。
- ChatGPT 登录的明示 pin 迁移到 `gpt-5.6-terra` / `gpt-5.6-luna`。
- API key 认证作为 GPT-5.4 retirement 的例外引导。
- 新的 setup guidance 不在分发 config 中添加固定 model。

## Why this way

Provider 和 model metadata 是 Codex 本体在运行时判断的领域。
Harness 在分发设置中固定它们容易与 Codex 侧的 model catalog 更新、provider default、AWS profile support 产生竞争。

因此 Harness 说明应使用的设置键和注意事项，仅在需要的人于 user / project config 中明示。
这样最易于自然接收 Codex 本体的改进。

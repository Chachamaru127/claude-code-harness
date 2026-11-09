# Public Claims Contract

状态: active

本契约适用于公开 README、landing page、release 文案、社交文案、截图、
用户评价以及独立报道列表。公开文案只能描述已针对当前实现验证过的行为。
缺失或过期的证据是 `unavailable`，而不是该主张为真的证明。

## Publication Rules

1. 实现类主张需要验证日期和当前证据。
   证据缺失必须 fail closed。
2. Host tier 行在构建时从 `hosts/registry.json` 派生；manifest 不能复制或覆盖它们。
3. 私有归档可以保留 `verified`、`rejected` 和 `unavailable` 的用户评价记录。
   公开构建只接受 `access_status` 为 `direct_public` 的 `verified` 记录。
4. `source_capture_ref` 是必需保留的完整来源 `.png`、`.jpg` 或 `.webp` 文件，
   位于 evidence root 之下。`public_crop_ref` 是可选的，也是唯一用于公开展示的图片。
5. 发布依据是受控的：`direct_public_source` 或 `minimal_attributed_quote`。
   引文必须是至多 280 个 Unicode 字符的单一修剪摘录。
6. 独立报道与用户评价分开存储和渲染；关于本项目的文章不等于用户背书。
7. 需要登录或不可用的来源、无效或间接的 URL、缺失或无效的抓取、过长引文，
   以及以英语或日语给出的量化或绝对化的速度／安全性主张，一律 fail closed。
8. 完整来源抓取保存在私有 evidence archive 中。公开展示的裁剪图（若存在）
   只包含署名和引文所需的最小来源区域；排除无关的回复、人物、互动数、
   客户数据和认证信息。

当前可执行的门禁是
`scripts/validate-publication-records.py --evidence-root <dir> <records.json>`。
它接受用户评价或实现类主张的 manifest；任何不合格的记录都会使整个构建输入
以非零码退出。独立报道不进入这两个集合中的任何一个。

## Machine-Readable Policy

<!-- public-claims-policy:start -->
```json
{
  "schema_version": "publication-policy.v1",
  "record_schema_version": "publication-records.v1",
  "validator": "scripts/validate-publication-records.py",
  "host_tier_source": "hosts/registry.json",
  "host_tier_overrides": "forbidden",
  "collections": {
    "testimonials": "testimonials",
    "independent_coverage": "independent_coverage",
    "implementation_claims": "implementation_claims"
  },
  "direct_source_url": {
    "schemes": ["https"],
    "blocked_hosts": ["bit.ly", "t.co", "tinyurl.com", "google.com", "bing.com"],
    "blocked_path_segments": ["login", "signin", "auth", "search"]
  },
  "testimonial": {
    "required": [
      "kind",
      "source_url",
      "posted_at",
      "language",
      "quote",
      "retrieved_at",
      "publication_basis",
      "access_status",
      "source_capture_ref",
      "status"
    ],
    "optional": ["public_crop_ref"],
    "status_values": ["verified", "rejected", "unavailable"],
    "publishable_statuses": ["verified"],
    "access_status_values": ["direct_public", "login_required", "unavailable"],
    "publishable_access_statuses": ["direct_public"],
    "publication_basis_values": ["direct_public_source", "minimal_attributed_quote"],
    "source_capture_extensions": [".png", ".jpg", ".webp"],
    "source_capture_min_width": 800,
    "source_capture_min_height": 600,
    "public_crop_min_width": 240,
    "public_crop_min_height": 100,
    "quote_max_characters": 280
  },
  "implementation_claim": {
    "required": ["kind", "text", "verified_at", "evidence_refs", "status"],
    "kind_value": "implementation_claim",
    "status_values": ["verified", "rejected", "unavailable"],
    "publishable_statuses": ["verified"]
  },
  "blocked_claim_patterns": [
    "\\d+(?:\\.\\d+)?\\s*(?:[xX](?!\\w)|×)",
    "\\d+(?:\\.\\d+)?\\s*[%％]\\s*(?:speed\\s*up|speedup|faster|safer|more\\s+secure|高速化?|速度向上|安全性向上)",
    "\\d+(?:\\.\\d+)?\\s*倍.{0,12}(?:高速化?|速く|速度|効率|生産性|安全)",
    "(?:absolutely\\s+safe|100\\s*[%％]\\s*(?:secure|safe)|completely\\s+safe|fully\\s+secure|guaranteed\\s+safe|zero\\s+risk|never\\s+fails|fail[- ]?proof|絶対(?:に)?安全|完全(?:に)?安全|失敗しない|必ず成功|リスクゼロ)"
  ]
}
```
<!-- public-claims-policy:end -->

## Record Shape

公开用户评价输入是实际的 JSON：

```json
{
  "schema_version": "publication-records.v1",
  "collection": "testimonials",
  "records": []
}
```

每条记录只能包含必需的用户评价字段以及可选的 `public_crop_ref`。
验证器在显式的 `--evidence-root` 之下解析抓取路径，拒绝路径穿越和缺失文件，
并检查图片的 magic bytes 而不是信任文件扩展名。

获取只能证明所引来源在那个日期可以直接观察。
这并不验证来源中无关的技术主张。
被拒绝和不可用的记录保留为私有审计数据。
独立文章在独立报道标题下链接到其原始来源，绝不放在用户评价构建输入之内。

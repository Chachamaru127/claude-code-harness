#!/bin/bash
# check-doc-zh-parity.sh
# 中文翻译结构一致性校验: 保证中文文档是原文的完整翻译，而非摘要或改写
#
# 覆盖两类文件对:
#   1. docs/<rel>.md  ->  docs-zh/<rel>.md   (目录结构镜像)
#   2. <name>.md      ->  <name>_zh.md       (仓库根, 见 ROOT_PAIRS)
#
# 逐文件比较结构特征:
#   - 代码块数量、围栏语言、内容哈希 (代码块必须逐字一致)
#   - 标题层级序列
#   - 表格行数与每行管道数
#   - 列表项数量
#   - 链接数量 (链接目标由 fix-doc-zh-links.py 负责重指向)
#   - 非空行数量 (日文/CJK 源 ±20%, 英文源 ±45%: 中文信息密度更高导致行数压缩)
#   - 译文残留日文假名 (阈值 3 行, 允许引用原文片段)
#
# Usage: bash scripts/ci/check-doc-zh-parity.sh [--verbose]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec python3 - "$ROOT_DIR" "$@" <<'PY'
import hashlib
import os
import re
import sys

ROOT = sys.argv[1]
VERBOSE = "--verbose" in sys.argv[2:]

SRC_DIR = os.path.join(ROOT, "docs")
DST_DIR = os.path.join(ROOT, "docs-zh")

# 根级文件对: (源文件, 中文版文件)。两者同在仓库根, 深度一致,
# 因此链接目标的相对路径在译文中保持不变。
ROOT_PAIRS = [
    ("CLAUDE.md", "CLAUDE_zh.md"),
    ("IMPLEMENTATION_GUIDE.md", "IMPLEMENTATION_GUIDE_zh.md"),
    ("SECURITY.md", "SECURITY_zh.md"),
    ("CONTRIBUTING.md", "CONTRIBUTING_zh.md"),
    ("Plans.md", "Plans_zh.md"),
    ("spec.md", "spec_zh.md"),
]

KANA = re.compile(r'[ぁ-んァ-ヶー]')
LINK = re.compile(r'\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
HEADING = re.compile(r'^(#{1,6})\s')
LIST_ITEM = re.compile(r'^\s*([-*+]|\d+[.)])\s')
INLINE_CODE = re.compile(r'`[^`]*`')


def parse(path):
    """提取文档结构特征。"""
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")

    in_code = False
    code_blocks = []
    current = None
    fence_langs = []
    headings = []
    links = []
    list_items = 0
    nonempty = 0
    table_pipes = []

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("```"):
            if not in_code:
                in_code = True
                fence_langs.append(stripped[3:].strip())
                current = []
            else:
                in_code = False
                code_blocks.append("\n".join(current))
                current = None
            continue

        if in_code:
            current.append(line)
            continue

        if not stripped:
            continue
        nonempty += 1

        heading = HEADING.match(line)
        if heading:
            headings.append(len(heading.group(1)))
            continue

        if LIST_ITEM.match(line):
            list_items += 1

        if "|" in line and stripped.startswith("|"):
            table_pipes.append(line.count("|"))
            continue

        for match in LINK.finditer(line):
            links.append(match.group(1))

    return {
        "headings": headings,
        "code_blocks": code_blocks,
        "fence_langs": fence_langs,
        "links": links,
        "list_items": list_items,
        "nonempty": nonempty,
        "table_pipes": table_pipes,
    }


def code_hashes(blocks):
    return [hashlib.sha256(b.encode("utf-8")).hexdigest()[:16] for b in blocks]


def find_sources():
    found = []
    for dirpath, _dirnames, filenames in os.walk(SRC_DIR):
        for name in filenames:
            if not name.endswith(".md"):
                continue
            full = os.path.join(dirpath, name)
            with open(full, encoding="utf-8") as fh:
                if KANA.search(fh.read()):
                    found.append(os.path.relpath(full, SRC_DIR))
    return sorted(found)


if not os.path.isdir(DST_DIR):
    print("FAIL: docs-zh/ 不存在")
    sys.exit(1)

sources = find_sources()
if not sources:
    print("FAIL: 未找到含日文的源文档")
    sys.exit(1)

failures = []
checked = 0


def check_pair(rel, src_path, dst_path):
    """比较一对源文件/译文, 就地追加 failures。"""
    global checked

    if not os.path.isfile(dst_path):
        failures.append((rel, "译文缺失", ""))
        return

    checked += 1
    src = parse(src_path)
    dst = parse(dst_path)

    if src["code_blocks"] != dst["code_blocks"]:
        failures.append((
            rel,
            "代码块内容与原文不一致",
            "src=%s dst=%s" % (
                ",".join(code_hashes(src["code_blocks"])),
                ",".join(code_hashes(dst["code_blocks"])),
            ),
        ))

    if src["fence_langs"] != dst["fence_langs"]:
        failures.append((
            rel,
            "代码围栏语言不一致",
            "src=%s dst=%s" % (",".join(src["fence_langs"]), ",".join(dst["fence_langs"])),
        ))

    if src["headings"] != dst["headings"]:
        failures.append((
            rel,
            "标题层级序列不一致",
            "src=%s dst=%s" % (src["headings"], dst["headings"]),
        ))

    if src["table_pipes"] != dst["table_pipes"]:
        failures.append((
            rel,
            "表格结构不一致",
            "src=%d行 dst=%d行" % (len(src["table_pipes"]), len(dst["table_pipes"])),
        ))

    if src["list_items"] != dst["list_items"]:
        failures.append((
            rel,
            "列表项数量不一致",
            "src=%d dst=%d" % (src["list_items"], dst["list_items"]),
        ))

    # 链接目标由 fix-doc-zh-links.py 负责重指向 (译文指向 docs-zh/、未翻译指向 docs/),
    # 因此这里只校验链接数量 (结构完整性), 不做逐目标比对。
    if len(src["links"]) != len(dst["links"]):
        failures.append((
            rel,
            "链接数量不一致",
            "src=%d个 dst=%d个" % (len(src["links"]), len(dst["links"])),
        ))

    if src["nonempty"] > 0:
        delta = abs(dst["nonempty"] - src["nonempty"]) * 100 // src["nonempty"]
        # 英文源译成中文时行数会显著压缩 (中文单行信息密度更高),
        # 因此对英文主导的源放宽到 45%, 日文/CJK 源维持 20%。
        with open(src_path, encoding="utf-8") as _fh:
            _src_text = _fh.read()
        _cjk = len(re.findall(r'[぀-ヿ一-鿿]', _src_text))
        _ascii = len(re.findall(r'[A-Za-z]', _src_text))
        limit = 45 if _ascii > _cjk else 20
        if delta > limit:
            failures.append((
                rel,
                "段落行数偏差过大 (阈值%d%%)" % limit,
                "src=%d dst=%d" % (src["nonempty"], dst["nonempty"]),
            ))

    # 残留日文假名检查仅针对正文。代码块按契约必须与原文逐字一致，
    # 因此代码块内的日文注释属于预期保留，不应计为"残留未翻译"。
    # 行内代码 (反引号包裹的触发器词/命令名/示例词) 同理属于引用原文，不计入。
    with open(dst_path, encoding="utf-8") as fh:
        _in_code = False
        jp_lines = 0
        for _line in fh:
            if _line.strip().startswith("```"):
                _in_code = not _in_code
                continue
            if _in_code:
                continue
            if KANA.search(INLINE_CODE.sub('', _line)):
                jp_lines += 1
    if jp_lines > 3:
        failures.append((rel, "译文残留日文假名 %d 行 (应逐句翻译)" % jp_lines, ""))

    if VERBOSE:
        print("  ok: %s" % rel)


for rel in sources:
    check_pair(rel, os.path.join(SRC_DIR, rel), os.path.join(DST_DIR, rel))

# ---- 根级文件对 (CLAUDE.md / spec.md / Plans.md 等) ----
# 这些文件在仓库根, 中文版同名加 _zh 后缀。它们不一定含日文
# (spec.md / IMPLEMENTATION_GUIDE.md / SECURITY.md 是英文源), 但既然
# 用户要求了中文版, 同样纳入结构一致性门禁。
for src_name, dst_name in ROOT_PAIRS:
    src_path = os.path.join(ROOT, src_name)
    if not os.path.isfile(src_path):
        failures.append((src_name, "源文件缺失", ""))
        continue
    check_pair(src_name, src_path, os.path.join(ROOT, dst_name))

total = len(sources) + len(ROOT_PAIRS)

print("")
if failures:
    for rel, reason, detail in failures:
        print("FAIL: %s — %s" % (rel, reason))
        if detail:
            print("        %s" % detail)
    print("")
    print("❌ 中文翻译结构一致性: %d 处不一致 (检查 %d/%d 个文件)"
          % (len(failures), checked, total))
    sys.exit(1)

print("✅ 中文翻译结构一致性: %d/%d 文件全部通过" % (checked, total))
PY

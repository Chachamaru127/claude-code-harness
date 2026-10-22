#!/usr/bin/env python3
"""sync-zh-code-blocks.py

把中文译文的 fenced code block 逐字替换为源文件的对应 block。

契约 (与 check-doc-zh-parity.sh 的 "代码块内容与原文不一致" 检查对应):
翻译文档中的代码块必须与源文件逐字一致。代码块内的注释也属于源文本,
不翻译 —— 译文读者按源文档的注释理解代码。

用法:
    python3 scripts/ci/sync-zh-code-blocks.py <src.md> <dst.md> [--check]

行为:
  - 块数不同 -> 报错退出 (需要人工重构, 不能自动对齐)
  - --check 只报告差异, 不写入
  - 默认写入 dst
"""

import argparse
import re
import sys

FENCE = re.compile(r'^\s*```')


def split_blocks(lines):
    """把行序列切成 (前置行, [(块体行, 围栏语言), ...], 后置行)。

    块体行不含围栏行本身。围栏语言从开围栏读取。
    """
    pre = []
    blocks = []
    post = []
    i = 0
    n = len(lines)
    while i < n:
        if FENCE.match(lines[i]):
            lang = lines[i].strip()[3:].strip()
            body = []
            i += 1
            while i < n and not FENCE.match(lines[i]):
                body.append(lines[i])
                i += 1
            if i >= n:
                # 未闭合的围栏: 原样保留剩余内容
                pre.extend(["\n".join([lang] + body)])
                return pre, blocks, post
            blocks.append((lang, body))
            i += 1  # 跳过闭围栏
            continue
        pre.append(lines[i])
        i += 1
    return pre, blocks, post


def rebuild(pre, blocks, post):
    out = list(pre)
    for lang, body in blocks:
        out.append("```" + lang)
        out.extend(body)
        out.append("```")
    out.extend(post)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    with open(args.src, encoding="utf-8") as fh:
        src_lines = fh.read().split("\n")
    with open(args.dst, encoding="utf-8") as fh:
        dst_lines = fh.read().split("\n")

    _, src_blocks, _ = split_blocks(src_lines)
    pre, dst_blocks, post = split_blocks(dst_lines)

    if len(src_blocks) != len(dst_blocks):
        print("FAIL: 代码块数量不同 src=%d dst=%d (需人工对齐)"
              % (len(src_blocks), len(dst_blocks)))
        return 1

    changed = 0
    new_blocks = []
    for (slang, sbody), (dlang, dbody) in zip(src_blocks, dst_blocks):
        if sbody != dbody:
            changed += 1
        new_blocks.append((dlang, sbody))

    if changed == 0:
        print("OK: 代码块已与原文逐字一致 (%d 块)" % len(src_blocks))
        return 0

    if args.check:
        print("DIFF: %d/%d 个代码块与原文不一致" % (changed, len(src_blocks)))
        return 1

    with open(args.dst, "w", encoding="utf-8") as fh:
        fh.write("\n".join(rebuild(pre, new_blocks, post)))
    print("已同步 %d/%d 个代码块为原文逐字内容" % (changed, len(src_blocks)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

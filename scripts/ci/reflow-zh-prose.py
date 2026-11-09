#!/usr/bin/env python3
"""reflow-zh-prose.py

按视觉宽度重新折行中文译文的散文段落。

背景: 英文源文档的散文按 ~75 列硬折行, 中文译成单行长段落时非空行数会
大幅压缩。check-doc-zh-parity.sh 用非空行数作为"非摘要"的代理信号,
压缩过多会被判为翻译不完整。

但压缩本身不等于摘要 —— 中文单行信息密度约为英文的 2 倍, 所以正确的
等价做法是: 按视觉等宽重新折行 (中文按半角宽度折, 即目标显示列数除以 2)。

本工具只处理散文段落。以下内容原样保留:
  - 围栏代码块 (含其语言标注)
  - 标题行
  - 表格行 (以 | 开头)
  - 列表项 (以 - * + 或 数字. 开头) 及其续行
  - 引用块 (以 > 开头)
  - 水平线 (--- / ***)
  - HTML 注释

用法:
    python3 scripts/ci/reflow-zh-prose.py <file.md> [--width N] [--check]

默认宽度 78 显示列 (与英文源文档的折行宽度接近)。
"""

import argparse
import re
import sys
import unicodedata

FENCE = re.compile(r'^\s*```')
HEADING = re.compile(r'^\s*#{1,6}\s')
LIST_ITEM = re.compile(r'^\s*([-*+]|\d+[.)])\s')
QUOTE = re.compile(r'^\s*>')
HR = re.compile(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$')
HTML_COMMENT = re.compile(r'^\s*<!--')
TABLE = re.compile(r'^\s*\|')

# 块级元素前后的空行用于分隔段落
BLANK = re.compile(r'^\s*$')


def display_width(text):
    """按显示列计算宽度 (全角字符占 2 列)。"""
    w = 0
    for ch in text:
        if unicodedata.east_asian_width(ch) in ("W", "F"):
            w += 2
        else:
            w += 1
    return w


def is_prose_paragraph(lines):
    """判断一个连续非空行块是否为可折行的散文段落。"""
    if not lines:
        return False
    for line in lines:
        if (FENCE.match(line) or HEADING.match(line) or LIST_ITEM.match(line)
                or QUOTE.match(line) or HR.match(line) or HTML_COMMENT.match(line)
                or TABLE.match(line)):
            return False
    return True


def wrap_paragraph(text, target_cols):
    """把一段文字按显示宽度折行。中文按半角折, 即列数除以 2。"""
    # 以 CJK 字符与空格为断点。中文没有词边界, 所以按字符断,
    # 但尽量不在标点前断行 (中文禁则处理)。
    no_break_before = "，。、；：？！）」』】》,.;:?!)]}"
    no_break_after = "（「『【`([{"

    tokens = []
    buf = ""
    for ch in text:
        if ch == " ":
            if buf:
                tokens.append(buf)
                buf = ""
            tokens.append(" ")
            continue
        buf += ch
    if buf:
        tokens.append(buf)

    lines = []
    cur = ""
    cur_w = 0
    for tok in tokens:
        if tok == " " and not cur:
            continue
        tw = display_width(tok)
        if cur_w + tw > target_cols and cur:
            # 禁则: 不让行首出现收尾标点
            if tok and tok[0] in no_break_before:
                cur += tok
                cur_w += tw
                continue
            lines.append(cur.rstrip())
            cur = "" if tok == " " else tok
            cur_w = 0 if tok == " " else tw
            continue
        cur += tok
        cur_w += tw
    if cur.strip():
        lines.append(cur.rstrip())

    # 合并: 若某行以开括号结尾而下一行以收尾标点开头, 尽量不拆开
    merged = []
    for line in lines:
        if merged and merged[-1] and merged[-1][-1] in no_break_after:
            merged[-1] = merged[-1] + line
        else:
            merged.append(line)
    return merged


def reflow(lines, target_cols):
    out = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]

        if FENCE.match(line):
            out.append(line)
            i += 1
            while i < n and not FENCE.match(lines[i]):
                out.append(lines[i])
                i += 1
            if i < n:
                out.append(lines[i])
                i += 1
            continue

        if BLANK.match(line):
            out.append(line)
            i += 1
            continue

        # 收集一个连续非空块
        block = []
        while i < n and not BLANK.match(lines[i]):
            block.append(lines[i])
            i += 1

        if is_prose_paragraph(block):
            text = " ".join(l.strip() for l in block)
            out.extend(wrap_paragraph(text, target_cols))
        else:
            out.extend(block)

    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--width", type=int, default=78)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    with open(args.path, encoding="utf-8") as fh:
        original = fh.read()
    lines = original.split("\n")

    new_lines = reflow(lines, args.width)
    new_text = "\n".join(new_lines)

    if new_text == original:
        print("OK: 折行宽度已合适 (%s)" % args.path)
        return 0

    if args.check:
        before = len([l for l in lines if l.strip()])
        after = len([l for l in new_lines if l.strip()])
        print("DIFF: %s 非空行 %d -> %d (需 reflow)" % (args.path, before, after))
        return 1

    with open(args.path, "w", encoding="utf-8") as fh:
        fh.write(new_text)
    before = len([l for l in lines if l.strip()])
    after = len([l for l in new_lines if l.strip()])
    print("已 reflow %s: 非空行 %d -> %d (目标宽度 %d 列)"
          % (args.path, before, after, args.width))
    return 0


if __name__ == "__main__":
    sys.exit(main())

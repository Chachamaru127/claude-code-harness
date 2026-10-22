#!/usr/bin/env python3
"""fix-doc-zh-links.py

docs-zh/ 译文的跨文档链接重指向。

背景: docs-zh/ 是 docs/ 的中文镜像, 但只有 108 个含日文的文档被翻译。
剩余 44 个纯英文文档 (以及非 .md 资源) 没有中文版, 译文里的链接必须
改指回 docs/ 下的原文件, 否则在 docs-zh/ 内点击会 404。

规则:
  - 链接目标是被翻译的 .md (镜像内有对应文件)  -> 保持不变
  - 链接目标是未翻译的 .md / 非 .md 资源       -> 重算为指向 docs/ 的相对路径
  - 链接目标在 docs/ 之外 (仓库根等)           -> 保持不变 (docs-zh/ 与 docs/ 同级, 深度一致)
  - 外链 / 纯锚点 / mailto                     -> 保持不变

Usage: python3 scripts/ci/fix-doc-zh-links.py [--dry-run]
"""

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = os.path.join(REPO, "docs")
DOCS_ZH = os.path.join(REPO, "docs-zh")

# Markdown 行内链接: [text](target) / [text](target "title")
LINK = re.compile(r'(\[[^\]]*\]\()([^)\s]+)((?:\s+"[^"]*")?\))')
# 图片: ![alt](target)
IMAGE = re.compile(r'(!\[[^\]]*\]\()([^)\s]+)((?:\s+"[^"]*")?\))')
# 引用式链接定义: [label]: target
REFDEF = re.compile(r'^(\s*\[[^\]]+\]:\s*)(\S+)(\s*)$')

SKIP_PREFIX = ("http://", "https://", "mailto:", "tel:", "data:", "#", "//")

# 根级中文文件 (与仓库根的英文版同名 + _zh 后缀)。
# README_zh.md / CHANGELOG_zh.md 有既存的语言版本链接语义
# (如 README_zh 同时链向"日语变更日志"与"英语变更日志"), 单独处理。
ROOT_ZH_FILES = (
    "README_zh.md",
    "CHANGELOG_zh.md",
)

# 新增的根级中文文件: 其中的同层链接统一改指中文版。
ROOT_ZH_FILES_NEW = (
    "CLAUDE_zh.md",
    "CONTRIBUTING_zh.md",
    "IMPLEMENTATION_GUIDE_zh.md",
    "SECURITY_zh.md",
    "Plans_zh.md",
    "spec_zh.md",
    "skills/routing-rules_zh.md",
)

# 根级文件之间的对应关系: 英文版文件名 -> 中文版文件名。
# 译文里链接到同层英文版时, 改指中文版。
ROOT_SIBLING_ZH = {
    "README.md": "README_zh.md",
    "CHANGELOG.md": "CHANGELOG_zh.md",
    "CHANGELOG_ja.md": "CHANGELOG_zh.md",
    "CLAUDE.md": "CLAUDE_zh.md",
    "CONTRIBUTING.md": "CONTRIBUTING_zh.md",
    "IMPLEMENTATION_GUIDE.md": "IMPLEMENTATION_GUIDE_zh.md",
    "SECURITY.md": "SECURITY_zh.md",
    "Plans.md": "Plans_zh.md",
    "spec.md": "spec_zh.md",
    "LICENSE.md": "LICENSE.zh.md",
    "skills/routing-rules.md": "skills/routing-rules_zh.md",
}


def is_external(target):
    return target.startswith(SKIP_PREFIX)


def resolve(zh_rel_dir, target_path):
    """把译文里的相对链接解析为 docs/ 下的相对路径。

    译文的目录结构与 docs/ 镜像一致, 所以以 docs/ 为基准解析。
    返回 None 表示目标在 docs/ 之外 (或解析失败)。
    """
    joined = os.path.normpath(os.path.join(zh_rel_dir, target_path))
    if joined == ".." or joined.startswith("../"):
        return None  # 指向 docs/ 之外
    return joined


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not os.path.isdir(DOCS_ZH):
        print("FAIL: docs-zh/ 不存在")
        return 1

    # 镜像内已翻译文件集合 (docs-zh/ 相对 docs/)
    translated = set()
    for dirpath, _dirs, files in os.walk(DOCS_ZH):
        for name in files:
            if not name.endswith(".md"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, DOCS_ZH)
            translated.add(rel)

    changes = []
    files_touched = set()

    for dirpath, _dirs, files in os.walk(DOCS_ZH):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            zh_path = os.path.join(dirpath, name)
            zh_rel = os.path.relpath(zh_path, DOCS_ZH)
            with open(zh_path, encoding="utf-8") as fh:
                lines = fh.read().split("\n")

            zh_dir = os.path.dirname(zh_rel)
            out_lines = []
            file_changed = False

            for lineno, line in enumerate(lines, 1):
                new_line = line
                for pattern in (LINK, IMAGE, REFDEF):
                    def repl(m, _dir=zh_dir, _rel=zh_rel, _ln=lineno):
                        target = m.group(2)
                        if is_external(target):
                            return m.group(0)
                        path_part = target.split("#", 1)[0]
                        if not path_part:
                            return m.group(0)  # 纯锚点
                        docs_rel = resolve(_dir, path_part)
                        if docs_rel is None:
                            return m.group(0)  # docs/ 之外
                        # 只处理 docs/ 下真实存在的目标。
                        # 不存在的多半是文档里的占位符示例 (如 `path`、
                        # `${CLAUDE_SKILL_DIR}/...`), 改写会破坏示例语义。
                        if not os.path.exists(os.path.join(DOCS, docs_rel)):
                            return m.group(0)
                        if docs_rel in translated:
                            return m.group(0)  # 镜像内有中文版
                        # 未翻译: 改指回 docs/ 下的原文件
                        back = os.path.relpath(os.path.join("docs", docs_rel), _dir)
                        if target.startswith("/"):
                            back = "/" + back
                        new_target = back + target[len(path_part):]
                        if new_target == target:
                            return m.group(0)
                        changes.append((_rel, _ln, target, new_target))
                        return m.group(1) + new_target + m.group(3)

                    new_line = pattern.sub(repl, new_line)

                if new_line != line:
                    file_changed = True
                out_lines.append(new_line)

            if file_changed:
                files_touched.add(zh_rel)
                if not args.dry_run:
                    with open(zh_path, "w", encoding="utf-8") as fh:
                        fh.write("\n".join(out_lines))

    for rel, lineno, old, new in changes:
        print("%s:%d  %s  ->  %s" % (rel, lineno, old, new))

    # ---- 根级中文文件 (README_zh.md / CHANGELOG_zh.md / *_zh.md) ----
    # 根级文件在仓库根, 链接到 docs/ 的译文应改指 docs-zh/;
    # 链接到同为根级且有中文版的文件时, 改指 *_zh.md。
    root_changes = []
    for name in ROOT_ZH_FILES + ROOT_ZH_FILES_NEW:
        root_path = os.path.join(REPO, name)
        if not os.path.isfile(root_path):
            continue
        # README_zh / CHANGELOG_zh 有既存的语言版本链接语义
        # (README_zh 同时链向"日语变更日志"与"英语变更日志"), 那里只做
        # 既有的日语 -> 中文 改写, 不动 CHANGELOG.md 之类的英文链接。
        legacy = name in ROOT_ZH_FILES
        with open(root_path, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        out_lines = []
        changed = False

        for lineno, line in enumerate(lines, 1):
            new_line = line
            for pattern in (LINK, IMAGE, REFDEF):
                def repl_root(m, _ln=lineno, _name=name, _legacy=legacy):
                    target = m.group(2)
                    if is_external(target):
                        return m.group(0)
                    path_part = target.split("#", 1)[0]
                    if not path_part:
                        return m.group(0)
                    new_target = None
                    if path_part.startswith("docs/"):
                        docs_rel = path_part[len("docs/"):]
                        if docs_rel in translated and os.path.isfile(
                                os.path.join(DOCS_ZH, docs_rel)):
                            new_target = "docs-zh/" + docs_rel
                    elif _legacy:
                        if path_part == "CHANGELOG_ja.md" and os.path.isfile(
                                os.path.join(REPO, "CHANGELOG_zh.md")):
                            new_target = "CHANGELOG_zh.md"
                        elif path_part == "LICENSE.md" \
                                and _name == "README_zh.md" \
                                and os.path.isfile(
                                    os.path.join(REPO, "LICENSE.zh.md")):
                            new_target = "LICENSE.zh.md"
                    elif path_part in ROOT_SIBLING_ZH:
                        candidate = ROOT_SIBLING_ZH[path_part]
                        # 指回自己 (自链接) 时保留英文原文件, 语义上是
                        # "看英文版", 而不是自指。
                        if candidate != _name and os.path.isfile(
                                os.path.join(REPO, candidate)):
                            new_target = candidate
                    if new_target is None:
                        return m.group(0)
                    new_target += target[len(path_part):]
                    if new_target == target:
                        return m.group(0)
                    root_changes.append((_name, _ln, target, new_target))
                    return m.group(1) + new_target + m.group(3)

                new_line = pattern.sub(repl_root, new_line)

            if new_line != line:
                changed = True
            out_lines.append(new_line)

        if changed:
            files_touched.add(name)
            if not args.dry_run:
                with open(root_path, "w", encoding="utf-8") as fh:
                    fh.write("\n".join(out_lines))

    for rel, lineno, old, new in root_changes:
        print("%s:%d  %s  ->  %s" % (rel, lineno, old, new))

    changes.extend(root_changes)
    print("")
    if args.dry_run:
        print("DRY-RUN: %d 处链接需重指向, 涉及 %d 个文件 (未写入)"
              % (len(changes), len(files_touched)))
    else:
        print("已重指向 %d 处链接, 涉及 %d 个文件" % (len(changes), len(files_touched)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# ======================================
# ベンチマーク outcome/transcript 採点（最小 grader）
# ======================================
#
# 目的:
# - 「プロセスが落ちなかったか」(exit_code) ではなく
#   「最終状態(outcome)が成功条件を満たしたか」を機械的に判定する。
# - transcript（出力/trace）も最低限チェックする。
#
# 出力:
# - stdout に JSON を1つだけ出力（ログは stderr）
#
# 依存:
# - python3

set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo '{"pass":false,"score":0,"task":"unknown","checks":[],"error":"python3_not_found"}'
  exit 0
fi

python3 - "$@" <<'PY'
import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Check:
    name: str
    status: str  # "pass" | "fail" | "skip"
    weight: float = 1.0
    required: bool = True
    details: str = ""


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def file_exists(project_dir: str, rel: str) -> Optional[str]:
    p = os.path.join(project_dir, rel)
    return p if os.path.isfile(p) else None


def score_from_checks(checks: List[Check]) -> float:
    relevant = [c for c in checks if c.status != "skip"]
    total = sum(c.weight for c in relevant)
    if total <= 0:
        return 0.0
    passed = sum(c.weight for c in relevant if c.status == "pass")
    return passed / total


def overall_pass(checks: List[Check]) -> bool:
    return all((not c.required) or (c.status == "pass") for c in checks if c.status != "skip")


def to_result(task: str, checks: List[Check], meta: dict, error: Optional[str] = None) -> dict:
    result = {
        "task": task,
        "pass": overall_pass(checks),
        "score": round(score_from_checks(checks), 4),
        "checks": [
            {
                "name": c.name,
                "status": c.status,
                "required": c.required,
                "weight": c.weight,
                "details": c.details,
            }
            for c in checks
        ],
        "meta": meta,
    }
    if error:
        result["error"] = error
    return result


def grade_plan_feature(project_dir: str) -> List[Check]:
    checks: List[Check] = []
    plans_rel = "Plans.md"
    plans_path = file_exists(project_dir, plans_rel)
    if not plans_path:
        checks.append(Check(name="plans_file_exists", status="fail", details=f"missing: {plans_rel}"))
        return checks

    checks.append(Check(name="plans_file_exists", status="pass", details=plans_rel))
    txt = read_text(plans_path)

    # "- [ ] " をタスクとしてカウント（Plans.md の形式に寄せる）
    tasks = re.findall(r"(?m)^\s*-\s*\[\s*\]\s+.+$", txt)
    checks.append(
        Check(
            name="checkbox_task_count>=3",
            status="pass" if len(tasks) >= 3 else "fail",
            details=f"found={len(tasks)}",
        )
    )

    # 要件語のゆるい検出（日本語/英語混在に耐える）
    hay = txt.lower()
    has_local = ("localstorage" in hay) or ("local storage" in hay)
    has_timeout = ("30" in hay) and (("timeout" in hay) or ("タイムアウト" in txt))
    has_auto_logout = ("自動ログアウト" in txt) or ("auto logout" in hay) or ("auto-logout" in hay)
    checks.append(
        Check(
            name="mentions_key_requirements",
            status="pass" if (has_local and has_timeout and has_auto_logout) else "fail",
            details=f"local={has_local}, timeout30={has_timeout}, auto_logout={has_auto_logout}",
        )
    )
    return checks


def grade_impl_utility(project_dir: str) -> List[Check]:
    checks: List[Check] = []
    rel = "src/utils/string-helpers.ts"
    path = file_exists(project_dir, rel)
    if not path:
        checks.append(Check(name="string_helpers_file_exists", status="fail", details=f"missing: {rel}"))
        return checks
    checks.append(Check(name="string_helpers_file_exists", status="pass", details=rel))

    txt = read_text(path)

    # 関数シグネチャ（多少の実装差異に耐える）
    patterns = {
        "truncate_signature": r"truncate\s*\(\s*str\s*:\s*string\s*,\s*maxLength\s*:\s*number\s*\)\s*:\s*string",
        "slugify_signature": r"slugify\s*\(\s*str\s*:\s*string\s*\)\s*:\s*string",
        "capitalize_signature": r"capitalize\s*\(\s*str\s*:\s*string\s*\)\s*:\s*string",
    }
    for name, pat in patterns.items():
        ok = re.search(pat, txt) is not None
        checks.append(Check(name=name, status="pass" if ok else "fail"))

    return checks


def grade_complex_feature(project_dir: str) -> List[Check]:
    checks: List[Check] = []
    files = [
        "src/models/user.ts",
        "src/repositories/user-repository.ts",
        "src/services/user-service.ts",
        "src/api/user-controller.ts",
        "src/utils/validators.ts",
    ]
    missing = []
    for rel in files:
        if file_exists(project_dir, rel):
            checks.append(Check(name=f"file_exists:{rel}", status="pass", details=rel, weight=0.5))
        else:
            missing.append(rel)
            checks.append(Check(name=f"file_exists:{rel}", status="fail", details=f"missing: {rel}", weight=0.5))

    # 最低限: export が全ファイルに含まれる（雑だが “空ファイル” を弾く）
    export_fail = []
    for rel in files:
        p = file_exists(project_dir, rel)
        if not p:
            continue
        txt = read_text(p)
        if "export" not in txt:
            export_fail.append(rel)

    checks.append(
        Check(
            name="exports_present_in_files",
            status="pass" if len(export_fail) == 0 and len(missing) == 0 else ("fail" if len(missing) == 0 else "skip"),
            required=False,
            details="; ".join(export_fail) if export_fail else "",
        )
    )
    return checks


def grade_parallel_review(project_dir: str, output_file: Optional[str], trace_file: Optional[str]) -> List[Check]:
    checks: List[Check] = []

    out_txt = ""
    if output_file and os.path.isfile(output_file):
        out_txt = read_text(output_file)
        checks.append(Check(name="output_file_exists", status="pass", details=os.path.basename(output_file)))
    else:
        checks.append(Check(name="output_file_exists", status="fail", details=str(output_file)))
        return checks

    # 3観点の存在（日本語/英語の揺れに耐える）
    has_sec = ("セキュリティ" in out_txt) or ("security" in out_txt.lower())
    has_quality = ("品質" in out_txt) or ("quality" in out_txt.lower())
    has_perf = ("パフォーマンス" in out_txt) or ("performance" in out_txt.lower())
    checks.append(
        Check(
            name="covers_3_aspects",
            status="pass" if (has_sec and has_quality and has_perf) else "fail",
            details=f"security={has_sec}, quality={has_quality}, performance={has_perf}",
        )
    )

    # 重大度ラベルの数（完全ではないが "問題列挙" の最低限）
    sev_hits = re.findall(r"(?i)\b(Critical|High|Medium|Low)\b", out_txt)
    checks.append(
        Check(
            name="severity_labels>=6",
            status="pass" if len(sev_hits) >= 6 else "fail",
            required=False,
            details=f"found={len(sev_hits)}",
        )
    )

    # 並列性の痕跡（trace がある場合のみ）
    if trace_file and os.path.isfile(trace_file):
        trace_txt = read_text(trace_file)
        has_task_tool = '"name":"Task"' in trace_txt
        has_subagent = '"subagent_type"' in trace_txt
        checks.append(
            Check(
                name="parallelism_detected_in_trace",
                status="pass" if (has_task_tool or has_subagent) else "fail",
                required=False,
                details=f"Task={has_task_tool}, subagent_type={has_subagent}",
            )
        )
    else:
        checks.append(Check(name="parallelism_detected_in_trace", status="skip", required=False, details="no trace"))

    return checks


def grade_impl_test(project_dir: str) -> List[Check]:
    """impl-test: src/utils/__tests__/string-helpers.test.ts のテスト作成を採点"""
    checks: List[Check] = []
    rel = "src/utils/__tests__/string-helpers.test.ts"
    path = file_exists(project_dir, rel)

    if not path:
        checks.append(Check(name="test_file_exists", status="fail", details=f"missing: {rel}"))
        return checks

    checks.append(Check(name="test_file_exists", status="pass", details=rel))
    txt = read_text(path)

    # describe ブロックの存在
    has_describe = re.search(r"\bdescribe\s*\(", txt) is not None
    checks.append(Check(name="has_describe_block", status="pass" if has_describe else "fail"))

    # it/test ブロックの数（6個以上が目標）
    test_matches = re.findall(r"\b(it|test)\s*\(", txt)
    test_count = len(test_matches)
    checks.append(
        Check(
            name="test_count>=6",
            status="pass" if test_count >= 6 else "fail",
            details=f"found={test_count}",
        )
    )

    # expect の存在（アサーションがある）
    has_expect = "expect(" in txt
    checks.append(Check(name="has_assertions", status="pass" if has_expect else "fail"))

    # エッジケースの考慮（空文字や長い文字列のテスト）
    has_edge_empty = ('""' in txt) or ("''" in txt) or ("empty" in txt.lower())
    has_edge_long = ("long" in txt.lower()) or (re.search(r'"[^"]{20,}"', txt) is not None)
    checks.append(
        Check(
            name="edge_cases_considered",
            status="pass" if (has_edge_empty or has_edge_long) else "fail",
            required=False,
            details=f"empty={has_edge_empty}, long={has_edge_long}",
        )
    )

    return checks


def grade_impl_refactor(project_dir: str) -> List[Check]:
    """impl-refactor: src/services/user-service.ts のリファクタリングを採点"""
    checks: List[Check] = []
    rel = "src/services/user-service.ts"
    path = file_exists(project_dir, rel)

    if not path:
        checks.append(Check(name="ts_file_exists", status="fail", details=f"missing: {rel}"))
        return checks

    checks.append(Check(name="ts_file_exists", status="pass", details=rel))
    txt = read_text(path)

    # 型定義（interface/type）の存在
    has_interface = re.search(r"\b(interface|type)\s+\w+", txt) is not None
    checks.append(Check(name="has_type_definitions", status="pass" if has_interface else "fail"))

    # try-catch の存在（エラーハンドリング）
    has_try_catch = "try" in txt and "catch" in txt
    checks.append(Check(name="has_error_handling", status="pass" if has_try_catch else "fail"))

    # async/await の使用（モダン化）
    has_async_await = ("async " in txt) and ("await " in txt)
    checks.append(
        Check(
            name="uses_async_await",
            status="pass" if has_async_await else "fail",
            required=False,
        )
    )

    # 関数の分割（複数の export function/const があるか）
    func_count = len(re.findall(r"\b(export\s+(async\s+)?function|export\s+const\s+\w+\s*=)", txt))
    checks.append(
        Check(
            name="function_count>=3",
            status="pass" if func_count >= 3 else "fail",
            required=False,
            details=f"found={func_count}",
        )
    )

    return checks


def grade_review_security(project_dir: str, output_file: Optional[str]) -> List[Check]:
    """review-security: セキュリティレビューの出力を採点"""
    checks: List[Check] = []

    out_txt = ""
    if output_file and os.path.isfile(output_file):
        out_txt = read_text(output_file)
        checks.append(Check(name="output_file_exists", status="pass", details=os.path.basename(output_file)))
    else:
        checks.append(Check(name="output_file_exists", status="fail", details=str(output_file)))
        return checks

    out_lower = out_txt.lower()

    # 問題検出数（セキュリティ関連キーワード）
    security_keywords = [
        "sql injection", "sqlインジェクション",
        "xss", "クロスサイト",
        "password", "パスワード",
        "authentication", "認証",
        "authorization", "認可",
        "vulnerability", "脆弱性",
        "injection", "インジェクション",
        "sensitive", "機密",
        "token", "トークン",
        "plaintext", "平文",
    ]
    found_issues = sum(1 for kw in security_keywords if kw in out_lower)
    checks.append(
        Check(
            name="security_issues>=3",
            status="pass" if found_issues >= 3 else "fail",
            details=f"keyword_hits={found_issues}",
        )
    )

    # 重大度分類
    sev_hits = re.findall(r"(?i)\b(Critical|High|Medium|Low|重大|高|中|低)\b", out_txt)
    checks.append(
        Check(
            name="has_severity_labels",
            status="pass" if len(sev_hits) >= 3 else "fail",
            details=f"found={len(sev_hits)}",
        )
    )

    # 修正案の提示
    fix_keywords = ["fix", "修正", "改善", "recommendation", "対策", "should", "べき", "consider", "検討"]
    has_fix = any(kw in out_lower for kw in fix_keywords)
    checks.append(
        Check(
            name="has_fix_recommendations",
            status="pass" if has_fix else "fail",
            required=False,
        )
    )

    # 行番号の特定（具体性）
    has_line_ref = re.search(r"(line\s*\d+|行\s*\d+|:\d+)", out_txt, re.IGNORECASE) is not None
    checks.append(
        Check(
            name="has_line_references",
            status="pass" if has_line_ref else "fail",
            required=False,
        )
    )

    return checks


def grade_review_quality(project_dir: str, output_file: Optional[str]) -> List[Check]:
    """review-quality: 品質レビューの出力を採点"""
    checks: List[Check] = []

    out_txt = ""
    if output_file and os.path.isfile(output_file):
        out_txt = read_text(output_file)
        checks.append(Check(name="output_file_exists", status="pass", details=os.path.basename(output_file)))
    else:
        checks.append(Check(name="output_file_exists", status="fail", details=str(output_file)))
        return checks

    out_lower = out_txt.lower()

    # 品質問題キーワード
    quality_keywords = [
        "readability", "可読性",
        "performance", "パフォーマンス",
        "rerender", "再レンダリング",
        "usememo", "usecallback",
        "dependency", "依存",
        "useeffect",
        "maintainability", "保守性",
        "best practice", "ベストプラクティス",
        "refactor", "リファクタリング",
        "complexity", "複雑",
        "inline style", "インラインスタイル",
    ]
    found_issues = sum(1 for kw in quality_keywords if kw in out_lower)
    checks.append(
        Check(
            name="quality_issues>=3",
            status="pass" if found_issues >= 3 else "fail",
            details=f"keyword_hits={found_issues}",
        )
    )

    # カテゴリ分類の存在
    category_patterns = [
        r"(category|カテゴリ|分類)",
        r"(可読性|readability|performance|パフォーマンス|保守性|maintainability)",
    ]
    has_category = any(re.search(pat, out_txt, re.IGNORECASE) for pat in category_patterns)
    checks.append(
        Check(
            name="has_categorization",
            status="pass" if has_category else "fail",
            required=False,
        )
    )

    # 改善提案（コードサンプル含む）
    has_code_sample = ("```" in out_txt) or ("import " in out_txt) or ("const " in out_txt)
    checks.append(
        Check(
            name="has_code_suggestions",
            status="pass" if has_code_sample else "fail",
            required=False,
        )
    )

    return checks


def grade_multi_file_refactor(project_dir: str) -> List[Check]:
    """multi-file-refactor: 複数ファイルリファクタリングを採点"""
    checks: List[Check] = []

    # 期待されるファイル
    expected_files = [
        ("src/services/user.service.ts", True),
        ("src/types/user.types.ts", True),
        ("src/errors/user.errors.ts", True),
        ("src/services/__tests__/user.service.test.ts", False),
    ]

    created_count = 0
    for rel, required in expected_files:
        path = file_exists(project_dir, rel)
        if path:
            checks.append(Check(name=f"file_exists:{rel}", status="pass", weight=0.5, required=required))
            created_count += 1
        else:
            checks.append(Check(name=f"file_exists:{rel}", status="fail", weight=0.5, required=required, details=f"missing: {rel}"))

    # 型定義ファイルの内容チェック
    types_path = file_exists(project_dir, "src/types/user.types.ts")
    if types_path:
        txt = read_text(types_path)
        has_interface = re.search(r"\binterface\s+(User|CreateUserDTO|UpdateUserDTO)", txt) is not None
        checks.append(
            Check(
                name="types_has_interfaces",
                status="pass" if has_interface else "fail",
                required=False,
            )
        )

    # エラークラスの継承チェック
    errors_path = file_exists(project_dir, "src/errors/user.errors.ts")
    if errors_path:
        txt = read_text(errors_path)
        extends_error = "extends Error" in txt
        checks.append(
            Check(
                name="errors_extend_error",
                status="pass" if extends_error else "fail",
                required=False,
            )
        )

    # テストファイルの構造チェック
    test_path = file_exists(project_dir, "src/services/__tests__/user.service.test.ts")
    if test_path:
        txt = read_text(test_path)
        has_describe = "describe(" in txt
        has_it = re.search(r"\b(it|test)\(", txt) is not None
        checks.append(
            Check(
                name="test_has_structure",
                status="pass" if (has_describe and has_it) else "fail",
                required=False,
                details=f"describe={has_describe}, it/test={has_it}",
            )
        )

    # 全体のファイル作成率
    checks.append(
        Check(
            name="files_created>=3",
            status="pass" if created_count >= 3 else "fail",
            details=f"created={created_count}/4",
        )
    )

    return checks


def grade_skill_routing(project_dir: str, output_file: Optional[str], trace_file: Optional[str]) -> List[Check]:
    """skill-routing: スキル評価フローを採点"""
    checks: List[Check] = []

    # 1. date-helpers.ts の作成チェック
    helpers_rel = "src/utils/date-helpers.ts"
    helpers_path = file_exists(project_dir, helpers_rel)
    if helpers_path:
        checks.append(Check(name="date_helpers_exists", status="pass", details=helpers_rel))
        txt = read_text(helpers_path)

        # 3つの関数シグネチャチェック
        funcs = ["formatDate", "parseDate", "isValidDate"]
        found_funcs = [f for f in funcs if f in txt]
        checks.append(
            Check(
                name="has_3_functions",
                status="pass" if len(found_funcs) >= 3 else "fail",
                details=f"found={found_funcs}",
            )
        )
    else:
        checks.append(Check(name="date_helpers_exists", status="fail", details=f"missing: {helpers_rel}"))

    # 2. テストファイルの作成チェック
    test_rel = "src/utils/__tests__/date-helpers.test.ts"
    test_path = file_exists(project_dir, test_rel)
    if test_path:
        checks.append(Check(name="test_file_exists", status="pass", details=test_rel))
        txt = read_text(test_path)
        has_tests = re.search(r"\b(it|test|describe)\(", txt) is not None
        checks.append(
            Check(
                name="test_has_assertions",
                status="pass" if has_tests else "fail",
                required=False,
            )
        )
    else:
        checks.append(Check(name="test_file_exists", status="fail", details=f"missing: {test_rel}"))

    # 3. レビュー出力チェック
    if output_file and os.path.isfile(output_file):
        out_txt = read_text(output_file)
        review_keywords = ["review", "レビュー", "改善", "suggestion", "指摘", "問題", "issue"]
        has_review = any(kw in out_txt.lower() for kw in review_keywords)
        checks.append(
            Check(
                name="has_review_output",
                status="pass" if has_review else "fail",
                required=False,
                details=f"review_found={has_review}",
            )
        )
    else:
        checks.append(Check(name="has_review_output", status="skip", required=False, details="no output file"))

    # 4. スキル起動の痕跡（trace がある場合のみ）
    if trace_file and os.path.isfile(trace_file):
        trace_txt = read_text(trace_file)
        has_impl = ("impl" in trace_txt.lower()) or ('"skill"' in trace_txt)
        has_review = ("review" in trace_txt.lower())
        has_verify = ("verify" in trace_txt.lower()) or ("test" in trace_txt.lower())
        checks.append(
            Check(
                name="skill_traces_detected",
                status="pass" if (has_impl or has_review or has_verify) else "fail",
                required=False,
                details=f"impl={has_impl}, review={has_review}, verify={has_verify}",
            )
        )
    else:
        checks.append(Check(name="skill_traces_detected", status="skip", required=False, details="no trace"))

    return checks


def main() -> int:
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--task", required=True)
    ap.add_argument("--project-dir", required=True)
    ap.add_argument("--output-file")
    ap.add_argument("--trace-file")
    args = ap.parse_args()

    task = args.task
    project_dir = args.project_dir

    meta = {
        "project_dir": project_dir,
        "output_file": args.output_file,
        "trace_file": args.trace_file,
    }

    try:
        if task == "plan-feature":
            checks = grade_plan_feature(project_dir)
        elif task == "impl-utility":
            checks = grade_impl_utility(project_dir)
        elif task == "impl-test":
            checks = grade_impl_test(project_dir)
        elif task == "impl-refactor":
            checks = grade_impl_refactor(project_dir)
        elif task == "complex-feature":
            checks = grade_complex_feature(project_dir)
        elif task == "parallel-review":
            checks = grade_parallel_review(project_dir, args.output_file, args.trace_file)
        elif task == "review-security":
            checks = grade_review_security(project_dir, args.output_file)
        elif task == "review-quality":
            checks = grade_review_quality(project_dir, args.output_file)
        elif task == "multi-file-refactor":
            checks = grade_multi_file_refactor(project_dir)
        elif task == "skill-routing":
            checks = grade_skill_routing(project_dir, args.output_file, args.trace_file)
        else:
            # 未知のタスクでも空ではなく基本チェックを返す
            checks = [Check(name="unknown_task", status="skip", required=False, details=f"no grader for: {task}")]
        res = to_result(task, checks, meta)
    except Exception as e:
        res = to_result(task, [], meta, error=f"grader_exception:{type(e).__name__}:{e}")

    sys.stdout.write(json.dumps(res, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY


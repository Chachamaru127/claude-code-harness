#!/usr/bin/env python3
"""
Eval Runner v4: SDK-Based Evaluation Harness

Claude Agent SDKを使用したヘッドレス評価システム。
UI操作やexpect依存を排除し、再現性と信頼性を確保する。
"""

import asyncio
import json
import os
import shutil
import tempfile
import uuid
import yaml
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any
import sys

# evals-v4 直下をモジュール解決に追加
EVALS_ROOT = Path(__file__).resolve().parent.parent
if str(EVALS_ROOT) not in sys.path:
    sys.path.insert(0, str(EVALS_ROOT))

from graders.code_grader import CodeGrader

# Claude Agent SDKのインポート
try:
    from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions
    from claude_agent_sdk.types import AssistantMessage, ResultMessage, ToolUseBlock
    HAS_SDK = True
except ImportError:
    print("Error: claude-agent-sdk not installed. Install with: pip install claude-agent-sdk")
    HAS_SDK = False
    sys.exit(1)


class EvalRunner:
    """評価ランナー: タスクを実行し、結果を収集する"""

    def __init__(
        self,
        tasks_dir: Path,
        results_dir: Path,
        plugin_dir: Optional[Path] = None,
        agent_model_provider: str = "default",
        glm_endpoint: Optional[str] = None,
        glm_model: Optional[str] = None,
        glm_api_key: Optional[str] = None,
        glm_env_file: Optional[Path] = None,
    ):
        self.tasks_dir = tasks_dir
        self.results_dir = results_dir
        self.plugin_dir = plugin_dir
        self.agent_model_provider = agent_model_provider
        self.glm_endpoint = glm_endpoint
        self.glm_model = glm_model
        self.glm_api_key = glm_api_key
        self.glm_env_file = glm_env_file
        self.results_dir.mkdir(parents=True, exist_ok=True)

    def _load_env_file(self, env_path: Path) -> Dict[str, str]:
        """簡易 .env パーサ（KEY=VALUEのみ）"""
        env_vars: Dict[str, str] = {}
        if not env_path.exists():
            return env_vars
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            env_vars[key.strip()] = value.strip().strip('"').strip("'")
        return env_vars

    def _build_agent_env(self) -> Dict[str, str]:
        """エージェント実行用の環境変数を構築"""
        if self.agent_model_provider != "glm":
            return {}

        env_vars: Dict[str, str] = {}
        if self.glm_env_file:
            env_vars.update(self._load_env_file(self.glm_env_file))

        api_key = (
            self.glm_api_key
            or env_vars.get("GLM_API_KEY")
            or os.environ.get("GLM_API_KEY")
        )
        if not api_key:
            raise RuntimeError("GLM_API_KEY is required for glm provider.")

        endpoint = self.glm_endpoint or "https://api.z.ai/api/anthropic"
        model = self.glm_model or "glm-4.7"

        env_vars.update(
            {
                "ANTHROPIC_BASE_URL": endpoint,
                "ANTHROPIC_AUTH_TOKEN": api_key,
                "ANTHROPIC_API_KEY": api_key,
                "ANTHROPIC_MODEL": model,
                "ANTHROPIC_DEFAULT_OPUS_MODEL": model,
                "ANTHROPIC_DEFAULT_SONNET_MODEL": model,
                "ANTHROPIC_DEFAULT_HAIKU_MODEL": model,
            }
        )
        return env_vars

    def _evaluate_reference(self, reference: Dict[str, Any], grading: Dict[str, Any]) -> Dict[str, Any]:
        """reference_solutionに基づいて合否を判定"""
        results: Dict[str, Any] = {}
        success = True

        for key, expected in reference.items():
            actual = grading.get(key)
            if actual is None:
                results[key] = {"expected": expected, "actual": None, "pass": False}
                success = False
                continue

            passed = False
            if isinstance(expected, bool):
                passed = (actual >= 1) if expected else (actual == 0)
            elif isinstance(expected, (int, float)):
                passed = actual >= expected
            elif isinstance(expected, str):
                match = re.match(r"^(>=|<=|=)\s*([0-9]+)$", expected.strip())
                if match:
                    op, num = match.groups()
                    num_val = float(num)
                    if op == ">=":
                        passed = actual >= num_val
                    elif op == "<=":
                        passed = actual <= num_val
                    elif op == "=":
                        passed = actual == num_val
            else:
                passed = False

            results[key] = {"expected": expected, "actual": actual, "pass": passed}
            if not passed:
                success = False

        return {"success": success, "checks": results}

    def _grade_task(self, task_config: Dict[str, Any], project_dir: Path) -> Dict[str, Any]:
        """タスク単位のグレーディング"""
        grader = CodeGrader(project_dir)
        grading: Dict[str, Any] = {}

        graders = task_config.get("graders", {}).get("code_based", [])
        # reference_solutionのキーも含めて採点
        reference_keys = list(task_config.get("reference_solution", {}).keys())
        all_graders = list(dict.fromkeys(list(graders) + reference_keys))

        for name in all_graders:
            if name == "refactoring_done":
                # setupファイルとの差分で判定
                setup_files = task_config.get("setup", {}).get("files", [])
                refactor_done = 0
                for file_cfg in setup_files:
                    path = project_dir / file_cfg.get("path", "")
                    original = file_cfg.get("content", "")
                    if path.exists():
                        try:
                            current = path.read_text(encoding="utf-8")
                            if current.strip() != original.strip():
                                refactor_done = 1
                                break
                        except Exception:
                            pass
                grading[name] = refactor_done
                continue
            method = getattr(grader, f"grade_{name}", None)
            if method:
                try:
                    grading[name] = method()
                except Exception:
                    grading[name] = 0
            else:
                grading[name] = 0

        reference = task_config.get("reference_solution", {})
        evaluation = self._evaluate_reference(reference, grading)
        return {"grading": grading, "evaluation": evaluation}

    def _resolve_plugin_root(self, plugin_dir: Path) -> Path:
        """プラグインのルートディレクトリを解決"""
        plugin_json = plugin_dir / ".claude-plugin" / "plugin.json"
        if plugin_json.exists():
            return plugin_dir

        # 1階層下に .claude-plugin/plugin.json がある場合
        candidates: List[Path] = []
        try:
            for child in plugin_dir.iterdir():
                if not child.is_dir():
                    continue
                if (child / ".claude-plugin" / "plugin.json").exists():
                    candidates.append(child)
        except Exception:
            return plugin_dir

        if not candidates:
            return plugin_dir

        # 名前が一致する候補を優先
        for candidate in candidates:
            try:
                data = json.loads(
                    (candidate / ".claude-plugin" / "plugin.json").read_text(
                        encoding="utf-8"
                    )
                )
                if data.get("name") == "claude-code-harness":
                    return candidate
            except Exception:
                continue

        # 先頭候補を採用
        return candidates[0]

    def load_task_yaml(self, yaml_path: Path) -> Dict[str, Any]:
        """タスクYAMLを読み込む"""
        with open(yaml_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)

    def create_isolated_env(self, base_dir: Path, task_id: str, iteration: int) -> Path:
        """クリーンな作業環境を作成"""
        work_dir = base_dir / f"{task_id}_iter_{iteration}"
        
        # 既存のディレクトリを削除
        if work_dir.exists():
            shutil.rmtree(work_dir)
        
        work_dir.mkdir(parents=True)
        
        # 基本ファイルを作成
        self._create_base_files(work_dir)
        
        return work_dir

    def _create_base_files(self, work_dir: Path):
        """基本ファイルを作成"""
        # package.json
        package_json = {
            "name": "eval-test-project",
            "version": "1.0.0",
            "type": "module",
            "scripts": {
                "build": "tsc",
                "test": "vitest run",
                "lint": "eslint src/"
            },
            "devDependencies": {
                "typescript": "^5.0.0",
                "vitest": "^1.0.0",
                "eslint": "^8.0.0"
            }
        }
        with open(work_dir / "package.json", 'w') as f:
            json.dump(package_json, f, indent=2)
        
        # tsconfig.json
        tsconfig = {
            "compilerOptions": {
                "target": "ES2022",
                "module": "ESNext",
                "moduleResolution": "node",
                "strict": True,
                "outDir": "dist"
            },
            "include": ["src/**/*"]
        }
        with open(work_dir / "tsconfig.json", 'w') as f:
            json.dump(tsconfig, f, indent=2)
        
        # src/index.ts
        (work_dir / "src").mkdir(exist_ok=True)
        with open(work_dir / "src/index.ts", 'w') as f:
            f.write("// Eval Test Project\nexport function main() {\n  console.log('Test project initialized');\n}\n")
        
        # CLAUDE.md
        with open(work_dir / "CLAUDE.md", 'w') as f:
            f.write("# Test Project for Evals\n\nThis is a test project for evaluating Claude Code plugin effectiveness.\n")

    def setup_task_files(self, work_dir: Path, task_config: Dict[str, Any]):
        """タスクのセットアップファイルを作成"""
        setup = task_config.get('setup', {})
        
        # ファイルの作成
        if 'files' in setup:
            for file_config in setup['files']:
                file_path = work_dir / file_config['path']
                file_path.parent.mkdir(parents=True, exist_ok=True)
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(file_config['content'])
        
        # トラップファイルの作成（guardrails用）
        if 'trap_files' in setup:
            for trap_config in setup['trap_files']:
                file_path = work_dir / trap_config['path']
                file_path.parent.mkdir(parents=True, exist_ok=True)
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(trap_config['content'])

    def _pick_option_label(self, question: Dict[str, Any]) -> str:
        options = question.get("options", [])
        if not options:
            return ""

        question_text = question.get("question", "")

        # 明示的な推奨があれば優先
        for opt in options:
            label = opt.get("label", "")
            description = opt.get("description", "")
            if "推奨" in label or "推奨" in description:
                return label

        # 質問文に応じたヒューリスティクス
        if "フレームワーク" in question_text:
            for opt in options:
                label = opt.get("label", "")
                if "Express" in label or "Fastify" in label:
                    return label

        if "対象ユーザー" in question_text or "誰が使" in question_text:
            for opt in options:
                label = opt.get("label", "")
                if "自分" in label:
                    return label

        if "モード" in question_text:
            for opt in options:
                label = opt.get("label", "")
                if "おまかせ" in label or "推奨" in label:
                    return label

        if "プロジェクト" in question_text and "種別" in question_text:
            for opt in options:
                label = opt.get("label", "")
                if "新規" in label:
                    return label

        return options[0].get("label", "")

    def _auto_answer_text(self, tool_input: Dict[str, Any]) -> str:
        questions = tool_input.get("questions", [])
        labels = []
        for question in questions:
            label = self._pick_option_label(question)
            if label:
                labels.append(label)
        if not labels:
            return "おまかせ"
        return "\n".join(labels)

    def _manual_harness_init(self, work_dir: Path):
        """/harness-init の代替（最小限のワークフロー/SSOTファイルを生成）"""
        plans_path = work_dir / "Plans.md"
        if not plans_path.exists():
            plans_path.write_text(
                "# Plans\n\n- cc:TODO 初期化されたタスク\n",
                encoding="utf-8",
            )

        agents_path = work_dir / "AGENTS.md"
        if not agents_path.exists():
            agents_path.write_text(
                "# AGENTS\n\n- Mode: Solo\n- Flow: Plan → Work → Review\n",
                encoding="utf-8",
            )

        claude_dir = work_dir / ".claude"
        claude_dir.mkdir(exist_ok=True)

        settings_path = claude_dir / "settings.json"
        if not settings_path.exists():
            settings_path.write_text(
                json.dumps({"permissionMode": "bypassPermissions"}, indent=2),
                encoding="utf-8",
            )

        memory_dir = claude_dir / "memory"
        memory_dir.mkdir(exist_ok=True)
        decisions_path = memory_dir / "decisions.md"
        if not decisions_path.exists():
            decisions_path.write_text("# Decisions\n\n", encoding="utf-8")

        patterns_path = memory_dir / "patterns.md"
        if not patterns_path.exists():
            patterns_path.write_text("# Patterns\n\n", encoding="utf-8")

        rules_dir = claude_dir / "rules"
        rules_dir.mkdir(exist_ok=True)
        test_quality = rules_dir / "test-quality.md"
        if not test_quality.exists():
            test_quality.write_text(
                "# Test Quality\n\n- Do not weaken tests.\n",
                encoding="utf-8",
            )

        impl_quality = rules_dir / "implementation-quality.md"
        if not impl_quality.exists():
            impl_quality.write_text(
                "# Implementation Quality\n\n- Do not stub logic.\n",
                encoding="utf-8",
            )

    async def _message_stream(self, message: Dict[str, Any]):
        yield message

    async def _run_prompt_with_client(
        self,
        client: ClaudeSDKClient,
        prompt: str,
        session_id: str,
        transcript: List[Dict[str, Any]],
    ) -> Optional[str]:
        result_text: Optional[str] = None
        await client.query(prompt=prompt, session_id=session_id)

        async for message in client.receive_response():
            transcript.append(
                {
                    "type": getattr(message, "type", "unknown"),
                    "content": str(message),
                    "timestamp": datetime.now().isoformat(),
                }
            )

            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, ToolUseBlock) and block.name == "AskUserQuestion":
                        answer_text = self._auto_answer_text(block.input)
                        user_message = {
                            "type": "user",
                            "message": {
                                "role": "user",
                                "content": answer_text,
                            },
                            "parent_tool_use_id": None,
                            "session_id": session_id,
                        }
                        transcript.append(
                            {
                                "type": "auto_answer",
                                "content": answer_text,
                                "timestamp": datetime.now().isoformat(),
                            }
                        )
                        await client.query(
                            prompt=self._message_stream(user_message),
                            session_id=session_id,
                        )

            if isinstance(message, ResultMessage):
                result_text = message.result if hasattr(message, "result") else None
                break
        return result_text

    async def run_task(
        self,
        task_config: Dict[str, Any],
        use_plugin: bool,
        work_dir: Path,
    ) -> Dict[str, Any]:
        """タスクを実行し、トランスクリプトを返す"""
        prompt = task_config['prompt']

        plugins = []
        plugin_root: Optional[Path] = None
        if use_plugin and self.plugin_dir:
            plugin_root = self._resolve_plugin_root(self.plugin_dir)
            plugins.append({"type": "local", "path": str(plugin_root)})

        agent_env = self._build_agent_env()

        # SDKオプションを設定
        options = ClaudeAgentOptions(
            system_prompt=(
                "claude_code\n\n"
                "【Auto-Answer Policy】\n"
                "- ユーザーへの質問はしない。\n"
                "- 不足情報は自分で決めて明記し、作業を進める。\n"
                "- AskUserQuestion は使わず、必要なら推奨案で進める。\n"
            ),
            allowed_tools=[
                "Read", "Write", "Glob", "Grep", "Bash", "Skill",
                "WebSearch", "WebFetch", "NotebookEdit"
            ],
            setting_sources=["project"] if use_plugin else [],
            plugins=plugins,
            cwd=str(work_dir),
            permission_mode="bypassPermissions",
            max_turns=50,
            env=agent_env,
        )
        
        # プラグインディレクトリを設定（with-pluginモード）
        if use_plugin and plugin_root:
            # プラグインをコピー
            # プラグインディレクトリは .claude-plugin/ を含むルートディレクトリ
            plugin_target = work_dir / ".claude-plugin"
            plugin_source = plugin_root / ".claude-plugin"
            
            # プラグインルートが指定されている場合、.claude-plugin サブディレクトリを探す
            if not plugin_source.exists() and plugin_root.name == ".claude-plugin":
                plugin_source = plugin_root
            
            if plugin_source.exists():
                if plugin_target.exists():
                    shutil.rmtree(plugin_target)
                shutil.copytree(plugin_source, plugin_target)
        
        # 実行開始時刻
        start_time = datetime.now()
        
        # トランスクリプトを収集
        transcript = []
        try:
            if self.agent_model_provider == "glm":
                transcript.append(
                    {
                        "type": "model_routing",
                        "content": json.dumps(
                            {
                                "provider": "glm",
                                "endpoint": agent_env.get("ANTHROPIC_BASE_URL"),
                                "model": agent_env.get("ANTHROPIC_MODEL"),
                            },
                            ensure_ascii=False,
                        ),
                        "timestamp": datetime.now().isoformat(),
                    }
                )
            session_id = f"eval-{uuid.uuid4()}"
            async with ClaudeSDKClient(options=options) as client:
                # with-pluginモードでは、まず /claude-code-harness:core:harness-init を試す
                if use_plugin:
                    init_result: Optional[str] = None
                    try:
                        init_result = await asyncio.wait_for(
                            self._run_prompt_with_client(
                                client,
                                "/claude-code-harness:core:harness-init おまかせ --mode=solo",
                                session_id,
                                transcript,
                            ),
                            timeout=120,
                        )
                    except asyncio.TimeoutError:
                        init_result = "timeout"

                    # それでもPlans/AGENTSが無ければ手動初期化
                    init_failed = bool(init_result and "Unknown skill" in init_result)
                    if (
                        init_failed
                        or not (work_dir / "Plans.md").exists()
                        or not (work_dir / "AGENTS.md").exists()
                    ):
                        self._manual_harness_init(work_dir)
                        transcript.append(
                            {
                                "type": "manual_init",
                                "content": "Plans.md/AGENTS.md created by fallback",
                                "timestamp": datetime.now().isoformat(),
                            }
                        )

                # タスクプロンプトを実行
                await self._run_prompt_with_client(
                    client, prompt, session_id, transcript
                )
        except Exception as e:
            transcript.append({
                "type": "error",
                "content": str(e),
                "timestamp": datetime.now().isoformat(),
            })
        
        # 実行終了時刻
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        return {
            "transcript": transcript,
            "duration_seconds": duration,
            "start_time": start_time.isoformat(),
            "end_time": end_time.isoformat(),
            "success": len([m for m in transcript if m.get('type') == 'error']) == 0,
        }

    def save_results(
        self,
        task_id: str,
        iteration: int,
        use_plugin: bool,
        task_config: Dict[str, Any],
        execution_result: Dict[str, Any],
        work_dir: Path,
    ):
        """結果を保存"""
        mode = "with-plugin" if use_plugin else "without-plugin"
        result_dir = self.results_dir / task_id / mode / f"iter_{iteration}"
        result_dir.mkdir(parents=True, exist_ok=True)
        
        # トランスクリプトを保存
        with open(result_dir / "transcript.json", 'w', encoding='utf-8') as f:
            json.dump(execution_result['transcript'], f, indent=2, ensure_ascii=False)
        
        # 作業ディレクトリをコピー（成果物の保存）
        if work_dir.exists():
            shutil.copytree(work_dir, result_dir / "project", dirs_exist_ok=True)

        # グレーディング
        grading_result = self._grade_task(task_config, result_dir / "project")
        evaluation_success = grading_result.get("evaluation", {}).get("success", False)

        # 実行結果を保存
        result_data = {
            "task_id": task_id,
            "iteration": iteration,
            "mode": mode,
            "task_config": task_config,
            "execution": {
                "duration_seconds": execution_result['duration_seconds'],
                "start_time": execution_result['start_time'],
                "end_time": execution_result['end_time'],
                "success": evaluation_success,
                "raw_success": execution_result['success'],
            },
            "grading": grading_result,
            "work_dir": str(work_dir),
        }
        
        with open(result_dir / "result.json", 'w', encoding='utf-8') as f:
            json.dump(result_data, f, indent=2, ensure_ascii=False)

    async def run_evaluation(
        self,
        task_yaml_path: Path,
        task_id: str,
        iterations: int = 1,
        base_work_dir: Optional[Path] = None,
    ):
        """評価を実行"""
        if not HAS_SDK:
            raise RuntimeError("Claude Agent SDK not available")
        
        # タスク定義を読み込み
        task_data = self.load_task_yaml(task_yaml_path)
        
        # タスクを検索
        tasks = task_data.get('tasks', [])
        task_config = next((t for t in tasks if t['id'] == task_id), None)
        
        if not task_config:
            raise ValueError(f"Task {task_id} not found in {task_yaml_path}")
        
        # 作業ディレクトリのベース
        if base_work_dir is None:
            base_work_dir = Path(tempfile.mkdtemp(prefix="eval_"))
        
        print(f"Running evaluation for task: {task_id}")
        print(f"Iterations: {iterations}")
        print(f"Base work dir: {base_work_dir}")
        
        # 各イテレーションを実行
        for iteration in range(1, iterations + 1):
            print(f"\n--- Iteration {iteration}/{iterations} ---")
            
            # with-plugin モード
            print("[with-plugin] Starting...")
            work_dir_with = self.create_isolated_env(base_work_dir, f"{task_id}_with", iteration)
            self.setup_task_files(work_dir_with, task_config)
            result_with = await self.run_task(task_config, use_plugin=True, work_dir=work_dir_with)
            self.save_results(task_id, iteration, True, task_config, result_with, work_dir_with)
            print(f"[with-plugin] Done (duration: {result_with['duration_seconds']:.2f}s)")
            
            # without-plugin モード
            print("[without-plugin] Starting...")
            work_dir_without = self.create_isolated_env(base_work_dir, f"{task_id}_without", iteration)
            self.setup_task_files(work_dir_without, task_config)
            result_without = await self.run_task(task_config, use_plugin=False, work_dir=work_dir_without)
            self.save_results(task_id, iteration, False, task_config, result_without, work_dir_without)
            print(f"[without-plugin] Done (duration: {result_without['duration_seconds']:.2f}s)")


async def main():
    """メイン関数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Eval Runner v4")
    parser.add_argument("--task-yaml", required=True, help="Path to task YAML file")
    parser.add_argument("--task-id", required=True, help="Task ID to run")
    parser.add_argument("--iterations", type=int, default=1, help="Number of iterations")
    parser.add_argument("--plugin-dir", help="Path to plugin directory")
    parser.add_argument("--results-dir", default="./results", help="Results directory")
    parser.add_argument("--work-dir", help="Base work directory (optional)")
    parser.add_argument(
        "--agent-model-provider",
        choices=["default", "glm"],
        default="default",
        help="Agent model provider (default or glm)",
    )
    parser.add_argument(
        "--glm-endpoint",
        default="https://api.z.ai/api/anthropic",
        help="GLM Anthropic-compatible endpoint",
    )
    parser.add_argument(
        "--glm-model",
        default="glm-4.7",
        help="GLM model name",
    )
    parser.add_argument(
        "--glm-api-key",
        help="GLM API key (overrides GLM_API_KEY env var)",
    )
    parser.add_argument(
        "--glm-env-file",
        help="Path to .env file containing GLM_API_KEY",
    )
    
    args = parser.parse_args()
    
    # パスを解決
    task_yaml_path = Path(args.task_yaml).resolve()
    results_dir = Path(args.results_dir).resolve()
    plugin_dir = Path(args.plugin_dir).resolve() if args.plugin_dir else None
    work_dir = Path(args.work_dir).resolve() if args.work_dir else None
    glm_env_file = Path(args.glm_env_file).resolve() if args.glm_env_file else None
    
    # ランナーを作成
    runner = EvalRunner(
        tasks_dir=task_yaml_path.parent,
        results_dir=results_dir,
        plugin_dir=plugin_dir,
        agent_model_provider=args.agent_model_provider,
        glm_endpoint=args.glm_endpoint,
        glm_model=args.glm_model,
        glm_api_key=args.glm_api_key,
        glm_env_file=glm_env_file,
    )
    
    # 評価を実行
    await runner.run_evaluation(
        task_yaml_path=task_yaml_path,
        task_id=args.task_id,
        iterations=args.iterations,
        base_work_dir=work_dir,
    )


if __name__ == "__main__":
    asyncio.run(main())

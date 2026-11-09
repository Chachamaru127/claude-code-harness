# 固定版QuintからTLCへ

RouteCLIの固定toolchainをこのrepoへ取り込んだもの。Quint 0.33.1、Apalache 0.62.4、TLC、Node 24、Java 21、Python 3.13以上を使う。依存はこのディレクトリだけへ置く。

来歴は `provenance.json`（routecli `b28a73c7`、6ファイルのsha256）。`versions.json` はQuintとApalacheの版、配布物とjarのSHA256を固定する。Node依存は `package-lock.json` で固定する。`.cache/` は明示した `prepare.py` が生成し、検査中の自動取得は行わない。

## 準備

```sh
npm ci --prefix formal/quint --ignore-scripts --no-audit --no-fund
python3 formal/quint/prepare.py
```

## このrepoの検査

模型と検査条件は `formal/baseline/route-setup-2026-11-08/` に置く。案件rootを `--routecli` に渡すと、`run_check.py` が `q_init` / `q_step` / `q_inv` を設定してTLCを実行する。Java 21を `JAVA_HOME` と `JOB_LEASE_JAVA` で明示する。

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"
python3 <route-project-setup>/scripts/run_check.py \
  --project . --input formal/baseline/route-setup-2026-11-08/report.json \
  --check C1 --routecli . --main MergeGate
```

結果は毎回未使用のパスへ保存する。生成補助 `build_report.py` は検査を実行しない。

## 変換経路

固定版Quintの `compile --target tlaplus` を使い、シリアライズの転送だけをRPCから公式Apalache CLIの `.qnt.json` ファイル入力へ変える。Quintの構文解析、型とeffect、flatten、初期状態のconvertInitはそのまま通る。常駐RPCや公開portは作らない。Quint CLIの `--out` はTLA+ではなく内部JSONを書くため使用しない。

Quint内部APIへの接点は `compile.cjs` の `compileToTlaplus` だけ。バージョンを固定し、更新時には正常、既知欠陥、状態遷移の同等性を確認する。RPCにあるfoldのLET引上げはこの経路に含まれない。該当する生成式は拒否する。一般的な全Quint構文との同等性を保証する経路ではない。

TLCは同じ固定jarから実行する。今回の安全性検査はdeadlockと進行性の検証を含まない。Quintの既定Apalache backendの有界検査を、全状態探索に読み替えない。

各実行は独立したプロセス群で90秒を上限とし、timeoutではその実行の子だけを停止して回収する。TLCの最大heapは1GiB。構文や起動の失敗は性質違反の反例と区別する。生成ファイルと出力は対象検査の証拠先へ保存する。

## 制約

- 結果は有限模型の範囲だけ。実装の全入力、進行性、実運用を保証しない。
- 上流RouteCLIのREADMEが前提とする job-lease 模型はこのrepoに無い。検査は `formal/baseline/` の模型だけを対象にする。
- toolchainのファイルは上流の固定版。ローカルで直すと `provenance.json` のhashと一致しなくなるため、修正は上流RouteCLIへ戻す。

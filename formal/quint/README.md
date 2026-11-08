# 固定版QuintからTLCへ

RouteCLIの形式仕様をQuintで保守し、有限状態をTLCで探索する。Node 24、Java 21、Python 3.13以上を使用。依存はこのディレクトリだけへ置く。

```sh
npm ci --prefix formal/quint --ignore-scripts --no-audit --no-fund
python3 formal/quint/prepare.py
python3 formal/job-lease/check.py selftest
python3 formal/job-lease/check.py verify
```

`versions.json`はQuintとApalacheのバージョン、配布物とjarのSHA256を固定する。Node依存はpackage-lock.jsonで固定。`.cache/`は明示したprepare.pyが生成し、検査中の自動取得は行わない。既存の配布アーカイブは`prepare.py --archive <path>`で再利用でき、同じhashを要求する。

## 変換経路

固定版Quintの`compile --target tlaplus`を使い、シリアライズの転送だけをRPCから公式Apalache CLIの`.qnt.json`ファイル入力へ変える。Quintの構文解析、型とeffect、flatten、初期状態のconvertInitはそのまま通る。常駐RPCや公開portは作らない。Quint CLIの`--out`はTLA+ではなく内部JSONを書くため使用せず、Apalacheが生成したTLA+を受け取る。

Quint内部APIへの接点はcompile.cjsのcompileToTlaplusだけ。バージョンを固定し、更新時には正常、既知欠陥、状態遷移の同等性を確認する。RPCにあるfoldのLET引上げはこの経路に含まれない。該当する生成式は拒否する。一般的な全Quint構文との同等性を保証する経路ではない。

TLCは同じ固定jarから実行する。初期状態q_init、次状態q_step、不変条件q_invを設定する。今回の安全性検査はdeadlockと進行性の検証を含まない。Quintの既定Apalache backendの有界検査を、全状態探索に読み替えない。

各実行は独立したプロセス群で90秒を上限とし、timeoutではその実行の子だけを停止して回収する。TLCの最大heapは1GiB。構文や起動の失敗は性質違反の反例とは区別する。生成ファイルと出力は対象検査の証拠先へ保存する。

## 別のプロジェクトへ

共有Skill create-formal-checkのreferences/quint-tlc.mdから使う。対象repoの承認済みcommitを固定して必要なファイルを取り込み、模型と実装をその案件へ対応付ける。上記のjob-lease模型を別案件へ置くだけでは、その案件を検証したことにならない。既存CIの対象変更に接続し、正常操作と欠陥の検出を確認する。

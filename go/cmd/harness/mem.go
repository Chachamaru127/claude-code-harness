package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"
)

// memHealthOutput は `bin/harness mem health` の JSON 出力スキーマ。
type memHealthOutput struct {
	Healthy bool   `json:"healthy"`
	Reason  string `json:"reason"`
}

// daemonProbe は harness-mem daemon への到達性確認。
// テスト注入のため package 変数。本番では probeHarnessMemDaemon を使う。
var daemonProbe = probeHarnessMemDaemon

// probeHarnessMemDaemon は HARNESS_MEM_HOST:HARNESS_MEM_PORT に TCP connect を試す。
// 既定 127.0.0.1:37888。接続失敗はそのまま error を返す（fail-silent な呼び出し側で処理）。
func probeHarnessMemDaemon() error {
	host := os.Getenv("HARNESS_MEM_HOST")
	if host == "" {
		host = "127.0.0.1"
	}
	port := os.Getenv("HARNESS_MEM_PORT")
	if port == "" {
		port = "37888"
	}
	addr := net.JoinHostPort(host, port)
	conn, err := net.DialTimeout("tcp", addr, 500*time.Millisecond)
	if err != nil {
		return err
	}
	_ = conn.Close()
	return nil
}

// runMem は `harness mem <subcommand>` を処理する。
func runMem(args []string) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Usage: harness mem <health>")
		os.Exit(1)
	}
	switch args[0] {
	case "health":
		runMemHealth(args[1:])
	default:
		fmt.Fprintf(os.Stderr, "Unknown mem subcommand: %s\n", args[0])
		os.Exit(1)
	}
}

// runMemHealth は `harness mem health` サブコマンドを実行する。
// ~/.claude-mem/ のファイルチェック後に daemon への TCP probe を行い、
// いずれかの段階で失敗したら unhealthy を返す。
// exit 0: healthy, exit 1: unhealthy
func runMemHealth(_ []string) {
	result, code := runMemHealthCheck()
	data, _ := json.Marshal(result)
	fmt.Printf("%s\n", data)
	os.Exit(code)
}

// runMemHealthCheck はヘルスチェックロジックを実行し、結果と exit code を返す。
// テストからも直接呼び出せるよう os.Exit を含まない形で分離する。
func runMemHealthCheck() (memHealthOutput, int) {
	home, err := os.UserHomeDir()
	if err != nil {
		return memHealthOutput{Healthy: false, Reason: "not-initialized"}, 1
	}

	claudeMem := filepath.Join(home, ".claude-mem")

	// ~/.claude-mem/ の存在チェック
	if _, err := os.Stat(claudeMem); os.IsNotExist(err) {
		return memHealthOutput{Healthy: false, Reason: "not-initialized"}, 1
	}

	// settings.json または supervisor.json のいずれかが読めるか
	settingsPath := filepath.Join(claudeMem, "settings.json")
	supervisorPath := filepath.Join(claudeMem, "supervisor.json")

	settingsOK := false
	if _, err := os.Stat(settingsPath); err == nil {
		settingsOK = true
	}
	supervisorOK := false
	if _, err := os.Stat(supervisorPath); err == nil {
		supervisorOK = true
	}

	if !settingsOK && !supervisorOK {
		return memHealthOutput{Healthy: false, Reason: "corrupted"}, 1
	}

	// daemon reachability probe: ファイルは揃っていても daemon 停止中は unhealthy
	if err := daemonProbe(); err != nil {
		return memHealthOutput{Healthy: false, Reason: "daemon-unreachable"}, 1
	}

	return memHealthOutput{Healthy: true, Reason: ""}, 0
}

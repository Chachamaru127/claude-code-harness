package hostgen

import "github.com/Chachamaru127/claude-code-harness/go/internal/runtimefloor"

// floor.policy.v1 fragment は 5 カテゴリ enum + 各カテゴリの human-readable
// 名前を持つ canonical floor policy。vendor hook JSON へ未知の top-level key
// として埋め込まず、host-neutral な監査・parity 検証で利用する。
type FloorFragment struct {
	Version    string             `json:"version"`
	Categories []FloorCategoryRow `json:"categories"`
}

type FloorCategoryRow struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// FloorPolicyFragment は runtimefloor.Category 一覧を取り、決定論的に
// FloorFragment を組み立てる。ID 順序は固定（runtimefloor.Category の
// 定義順序と一致）。
func FloorPolicyFragment() FloorFragment {
	return FloorFragment{
		Version: "floor.policy.v1",
		Categories: []FloorCategoryRow{
			{ID: string(runtimefloor.CategoryMoneyBilling), Name: "Money / Billing"},
			{ID: string(runtimefloor.CategoryEgress), Name: "External Network Egress"},
			{ID: string(runtimefloor.CategorySecretRead), Name: "Secret / Credential Read"},
			{ID: string(runtimefloor.CategoryProdDeploy), Name: "Production Deploy"},
			{ID: string(runtimefloor.CategoryWorktreeEscape), Name: "Worktree Escape"},
		},
	}
}

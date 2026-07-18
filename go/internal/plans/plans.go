// Package plans is the canonical kernel parser for Plans.md.
//
// Plans.md is a 5-column markdown table:
//
//	| Task | 内容 | DoD | Depends | Status |
//
// Status cells carry markers such as cc:TODO, cc:WIP, cc:完了, cc:done, cc:blocked.
//
// Unlike the historical scattered parsers, ParseMarkdown returns EVERY task row
// (including completed/done rows). Status filtering is a caller concern: callers
// that only want active rows filter on the returned Tags.
package plans

import (
	"bufio"
	"os"
	"regexp"
	"strings"
)

// Tags classifies a task row by its Status marker. A row may match none of these
// (e.g. an unrecognized status), in which case all booleans are false.
type Tags struct {
	Todo    bool `json:"todo"`
	Wip     bool `json:"wip"`
	Blocked bool `json:"blocked"`
	Done    bool `json:"done"`
}

// Task is one parsed task row from Plans.md.
//
// NOTE: the ID field is named TaskID (not ID) to stay drop-in compatible with
// the legacy hookhandler.planRow type, which is now a type alias of this struct.
// Existing code and tests construct rows with `{TaskID: ...}` and read `.TaskID`,
// so renaming would break callers/tests. See go/internal/hookhandler/pre_compact_save.go.
type Task struct {
	TaskID  string `json:"taskId"`
	Title   string `json:"title"`
	DoD     string `json:"dod"`
	Depends string `json:"depends"`
	Status  string `json:"status"`
	Tags    Tags   `json:"tags"`
}

// Status marker matchers. Case-insensitive, optional surrounding backtick.
var (
	reTodo    = regexp.MustCompile("(?i)`?cc:TODO`?")
	reWip     = regexp.MustCompile("(?i)`?cc:WIP`?|\\[in_progress\\]")
	reBlocked = regexp.MustCompile("(?i)`?cc:blocked`?|\\[blocked\\]")
	reDone    = regexp.MustCompile("(?i)`?cc:完了`?|`?cc:done`?")
)

// classifyStatus computes Tags from a Status cell string.
func classifyStatus(status string) Tags {
	return Tags{
		Todo:    reTodo.MatchString(status),
		Wip:     reWip.MatchString(status),
		Blocked: reBlocked.MatchString(status),
		Done:    reDone.MatchString(status),
	}
}

// IsWIPStatus reports whether a status value uses a canonical WIP marker.
// Callers outside this package should use this helper instead of maintaining
// another marker spelling/casing parser.
func IsWIPStatus(status string) bool {
	return classifyStatus(status).Wip
}

// ParseMarkdown parses every task row from Plans.md content (no status filter).
//
// Parsing rules (preserved verbatim from the proven getPlanRows logic):
//   - skip lines without '|'
//   - SplitPipeRow the line; need >= 5 cells
//   - cells[0] = TaskID; skip if it is "", "Task", or contains "---" (header/separator)
//   - Status   = trim(last cell)
//   - Depends  = trim(cells[last-1])
//   - Title    = trim(cells[1]) when present
//   - DoD      = trim(join(cells[2:last-2], "|"))
//
// Unlike getPlanRows, rows that match no status marker are NOT dropped; all task
// rows (Done rows included) are returned.
func ParseMarkdown(content string) []Task {
	var tasks []Task
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.Contains(line, "|") {
			continue
		}

		cells := SplitPipeRow(line)
		if len(cells) < 5 {
			continue
		}

		taskID := strings.TrimSpace(cells[0])
		if taskID == "" || taskID == "Task" || strings.Contains(taskID, "---") {
			continue
		}

		status := strings.TrimSpace(cells[len(cells)-1])
		depends := strings.TrimSpace(cells[len(cells)-2])
		title := ""
		if len(cells) > 2 {
			title = strings.TrimSpace(cells[1])
		}
		dod := ""
		if len(cells) > 3 {
			dod = strings.TrimSpace(strings.Join(cells[2:len(cells)-2], "|"))
		}

		tasks = append(tasks, Task{
			TaskID:  taskID,
			Title:   title,
			DoD:     dod,
			Depends: depends,
			Status:  status,
			Tags:    classifyStatus(status),
		})
	}
	return tasks
}

// ParseFile reads and parses a Plans.md file. Returns (nil, err) if unreadable.
func ParseFile(path string) ([]Task, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseMarkdown(string(data)), nil
}

// Find returns the task with the given ID, or nil if none matches.
func Find(tasks []Task, id string) *Task {
	for i := range tasks {
		if tasks[i].TaskID == id {
			return &tasks[i]
		}
	}
	return nil
}

// SplitPipeRow splits a markdown table row on '|', honoring escaped '\|'.
// Leading and trailing empty cells (from the outer table pipes) are trimmed.
func SplitPipeRow(line string) []string {
	const placeholder = "\x00PIPE\x00"
	escaped := strings.ReplaceAll(line, `\|`, placeholder)
	rawCells := strings.Split(escaped, "|")

	// 先頭・末尾の空セルを除去
	start := 0
	end := len(rawCells)
	if end > 0 && strings.TrimSpace(rawCells[0]) == "" {
		start = 1
	}
	if end > start && strings.TrimSpace(rawCells[end-1]) == "" {
		end--
	}
	cells := rawCells[start:end]

	for i, c := range cells {
		cells[i] = strings.ReplaceAll(c, placeholder, "|")
	}
	return cells
}

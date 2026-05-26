package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var migrationRequiredSkills = []string{
	"harness-plan",
	"harness-work",
	"harness-review",
	"harness-release",
	"harness-setup",
	"harness-sync",
	"breezing",
}

type migrationReportEnv struct {
	Home              string
	ClaudePluginCache string
	HarnessMemHome    string
}

type migrationReportEntry struct {
	Area             string
	Status           string
	Path             string
	Evidence         string
	Impact           string
	BackupLocation   string
	RollbackProposal string
	SupportBoundary  string
}

type existingUserMigrationReport struct {
	ProjectRoot        string
	DestructiveCleanup string
	Entries            []migrationReportEntry
}

type pluginManifestForMigration struct {
	Name    string          `json:"name"`
	Version string          `json:"version"`
	Skills  json.RawMessage `json:"skills"`
}

type pluginCacheHit struct {
	ManifestPath string
	Version      string
	SkillDirs    []string
}


func runMigrationReportCheck(projectRoot string) bool {
	report := buildExistingUserMigrationReport(projectRoot, migrationReportEnvFromOS())
	printExistingUserMigrationReport(report)
	return true
}

func migrationReportEnvFromOS() migrationReportEnv {
	home, _ := os.UserHomeDir()
	env := migrationReportEnv{
		Home: home,
	}
	if v := os.Getenv("CLAUDE_PLUGIN_CACHE"); v != "" {
		env.ClaudePluginCache = v
	} else if home != "" {
		env.ClaudePluginCache = filepath.Join(home, ".claude", "plugins", "cache")
	}
	if v := os.Getenv("HARNESS_MEM_HOME"); v != "" {
		env.HarnessMemHome = v
	} else if home != "" {
		env.HarnessMemHome = filepath.Join(home, ".harness-mem")
	}
	return env
}

func buildExistingUserMigrationReport(projectRoot string, env migrationReportEnv) existingUserMigrationReport {
	report := existingUserMigrationReport{
		ProjectRoot:        projectRoot,
		DestructiveCleanup: "disabled: this report never deletes plugin caches, skills, backups, symlinks, or harness-mem data",
	}

	currentVersion := readCurrentHarnessPluginVersion(projectRoot)
	pluginHits := findClaudeHarnessPluginCaches(env.ClaudePluginCache)
	report.Entries = append(report.Entries, reportClaudePluginCache(env.ClaudePluginCache, currentVersion, pluginHits))
	report.Entries = append(report.Entries, reportClaudeSlashEntries(pluginHits))

	report.Entries = append(report.Entries, reportHarnessMemState(projectRoot, env.HarnessMemHome))
	report.Entries = append(report.Entries, migrationReportEntry{
		Area:             "Destructive cleanup gate",
		Status:           "ok",
		Path:             projectRoot,
		Evidence:         report.DestructiveCleanup,
		Impact:           "Migration report is safe to run before deciding on cleanup.",
		BackupLocation:   "not applicable",
		RollbackProposal: "No rollback required because this command is report-only.",
		SupportBoundary:  "Cleanup and purge require a separate explicit confirmation gate.",
	})

	return report
}

func printExistingUserMigrationReport(report existingUserMigrationReport) {
	fmt.Println("Existing User Migration Report:")
	fmt.Println()
	fmt.Printf("  Project root: %s\n", report.ProjectRoot)
	fmt.Printf("  Destructive cleanup: %s\n", report.DestructiveCleanup)
	fmt.Println()
	for _, entry := range report.Entries {
		fmt.Printf("  [%s] %s\n", strings.ToUpper(entry.Status), entry.Area)
		if entry.Path != "" {
			fmt.Printf("    path: %s\n", entry.Path)
		}
		if entry.Evidence != "" {
			fmt.Printf("    evidence: %s\n", entry.Evidence)
		}
		if entry.Impact != "" {
			fmt.Printf("    impact: %s\n", entry.Impact)
		}
		if entry.BackupLocation != "" {
			fmt.Printf("    backup: %s\n", entry.BackupLocation)
		}
		if entry.RollbackProposal != "" {
			fmt.Printf("    rollback: %s\n", entry.RollbackProposal)
		}
		if entry.SupportBoundary != "" {
			fmt.Printf("    boundary: %s\n", entry.SupportBoundary)
		}
	}
}

func readCurrentHarnessPluginVersion(projectRoot string) string {
	manifestPath := filepath.Join(projectRoot, ".claude-plugin", "plugin.json")
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		return ""
	}
	var manifest pluginManifestForMigration
	if err := json.Unmarshal(data, &manifest); err != nil {
		return ""
	}
	return manifest.Version
}

func findClaudeHarnessPluginCaches(cacheRoot string) []pluginCacheHit {
	if cacheRoot == "" || !pathExists(cacheRoot) {
		return nil
	}
	var hits []pluginCacheHit
	_ = filepath.WalkDir(cacheRoot, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if rel, relErr := filepath.Rel(cacheRoot, path); relErr == nil && rel != "." && strings.Count(rel, string(os.PathSeparator)) > 6 {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Base(path) != "plugin.json" {
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return nil
		}
		var manifest pluginManifestForMigration
		if json.Unmarshal(data, &manifest) != nil {
			return nil
		}
		if manifest.Name != "claude-code-harness" && !strings.Contains(path, "claude-code-harness") {
			return nil
		}
		hits = append(hits, pluginCacheHit{
			ManifestPath: path,
			Version:      manifest.Version,
			SkillDirs:    resolveManifestSkillDirs(filepath.Dir(path), manifest),
		})
		return nil
	})
	sort.Slice(hits, func(i, j int) bool { return hits[i].ManifestPath < hits[j].ManifestPath })
	return hits
}

func resolveManifestSkillDirs(manifestDir string, manifest pluginManifestForMigration) []string {
	var dirs []string
	add := func(rel string) {
		rel = strings.TrimSpace(rel)
		if rel == "" {
			return
		}
		if filepath.IsAbs(rel) {
			dirs = append(dirs, rel)
			return
		}
		dirs = append(dirs, filepath.Clean(filepath.Join(manifestDir, rel)))
	}

	var one string
	if json.Unmarshal(manifest.Skills, &one) == nil {
		add(one)
	}
	var many []string
	if json.Unmarshal(manifest.Skills, &many) == nil {
		for _, rel := range many {
			add(rel)
		}
	}

	candidates := []string{
		filepath.Join(manifestDir, "skills"),
		filepath.Join(manifestDir, "..", "skills"),
	}
	for _, candidate := range candidates {
		if pathExists(candidate) {
			dirs = append(dirs, filepath.Clean(candidate))
		}
	}
	return uniqueStrings(dirs)
}

func reportClaudePluginCache(cacheRoot, currentVersion string, hits []pluginCacheHit) migrationReportEntry {
	if cacheRoot == "" || !pathExists(cacheRoot) {
		return migrationReportEntry{
			Area:             "Claude plugin cache",
			Status:           "not_observed",
			Path:             cacheRoot,
			Evidence:         "Claude plugin cache path was not present in this environment",
			Impact:           "No cache impact can be inferred from this report.",
			BackupLocation:   "Claude Code plugin manager cache",
			RollbackProposal: "Use /plugin update or /plugin uninstall; avoid manual cache deletion unless separately approved.",
			SupportBoundary:  "not_observed != absent",
		}
	}
	if len(hits) == 0 {
		return migrationReportEntry{
			Area:             "Claude plugin cache",
			Status:           "not_observed",
			Path:             cacheRoot,
			Evidence:         "No claude-code-harness plugin.json was found under the cache path",
			Impact:           "Claude cache status is unknown, not clean.",
			BackupLocation:   "Claude Code plugin manager cache",
			RollbackProposal: "Run /plugin list and /plugin update inside Claude Code to confirm the installed plugin.",
			SupportBoundary:  "not_observed != absent",
		}
	}
	var stale []string
	for _, hit := range hits {
		if currentVersion != "" && hit.Version != "" && hit.Version != currentVersion {
			stale = append(stale, fmt.Sprintf("%s version=%s current=%s", hit.ManifestPath, hit.Version, currentVersion))
		}
	}
	if len(stale) > 0 {
		return migrationReportEntry{
			Area:             "Claude plugin cache",
			Status:           "warn",
			Path:             cacheRoot,
			Evidence:         "stale plugin cache observed: " + strings.Join(stale, "; "),
			Impact:           "Claude Code may keep loading an older Harness plugin until the plugin manager updates it.",
			BackupLocation:   "Claude Code plugin manager cache",
			RollbackProposal: "Use /plugin update claude-code-harness or uninstall/reinstall through the plugin manager.",
			SupportBoundary:  "Report only; this command does not delete plugin cache entries.",
		}
	}
	return migrationReportEntry{
		Area:             "Claude plugin cache",
		Status:           "ok",
		Path:             cacheRoot,
		Evidence:         fmt.Sprintf("%d claude-code-harness cache manifest(s) observed without version drift", len(hits)),
		Impact:           "No stale cache evidence was observed.",
		BackupLocation:   "Claude Code plugin manager cache",
		RollbackProposal: "Keep using /plugin update for managed changes.",
	}
}

func reportClaudeSlashEntries(hits []pluginCacheHit) migrationReportEntry {
	if len(hits) == 0 {
		return migrationReportEntry{
			Area:             "Claude slash entries",
			Status:           "not_observed",
			Evidence:         "No cached Harness plugin skills were available to inspect",
			Impact:           "Missing slash entries cannot be ruled out.",
			RollbackProposal: "Run /plugin update followed by /harness-setup in Claude Code.",
			SupportBoundary:  "not_observed != absent",
		}
	}

	var missing []string
	for _, hit := range hits {
		for _, required := range migrationRequiredSkills {
			if !skillExistsInAnyDir(required, hit.SkillDirs) {
				missing = append(missing, fmt.Sprintf("%s missing %s", hit.ManifestPath, required))
			}
		}
	}
	if len(missing) > 0 {
		return migrationReportEntry{
			Area:             "Claude slash entries",
			Status:           "warn",
			Evidence:         strings.Join(missing, "; "),
			Impact:           "Commands such as /harness-plan or /harness-work may not resolve for existing users.",
			BackupLocation:   "Claude Code plugin manager cache",
			RollbackProposal: "Update or reinstall the plugin, then run /harness-setup; do not hand-delete unrelated user commands.",
		}
	}
	return migrationReportEntry{
		Area:             "Claude slash entries",
		Status:           "ok",
		Evidence:         "Required Harness skill entries are present in observed plugin cache skill directories",
		Impact:           "No missing slash entry evidence was observed.",
		RollbackProposal: "No action required.",
	}
}


func reportHarnessMemState(projectRoot, harnessMemHome string) migrationReportEntry {
	paths := []string{}
	projectState := filepath.Join(projectRoot, ".harness-mem", "state")
	if pathExists(projectState) {
		paths = append(paths, projectState)
	}
	for _, candidate := range []string{
		filepath.Join(harnessMemHome, "harness-mem.db"),
		filepath.Join(harnessMemHome, "runtime", "harness-mem"),
		filepath.Join(harnessMemHome, "config.json"),
	} {
		if pathExists(candidate) {
			paths = append(paths, candidate)
		}
	}
	if len(paths) == 0 {
		return migrationReportEntry{
			Area:             "harness-mem state",
			Status:           "not_observed",
			Path:             harnessMemHome,
			Evidence:         "No project or user harness-mem state was observed",
			Impact:           "No memory migration impact can be inferred.",
			BackupLocation:   harnessMemHome,
			RollbackProposal: "Run harness mem doctor if memory is expected; do not run purge unless explicitly confirmed.",
			SupportBoundary:  "not_observed != absent",
		}
	}
	sort.Strings(paths)
	return migrationReportEntry{
		Area:             "harness-mem state",
		Status:           "observed",
		Path:             harnessMemHome,
		Evidence:         strings.Join(paths, "; "),
		Impact:           "Memory continuity exists and must be preserved across tool migration.",
		BackupLocation:   harnessMemHome,
		RollbackProposal: "Keep the DB/state in place; use harness mem doctor for health and harness mem purge only with explicit confirmation.",
		SupportBoundary:  "The report does not read or delete the memory DB contents.",
	}
}


func skillExistsInAnyDir(skill string, dirs []string) bool {
	for _, dir := range dirs {
		if pathExists(filepath.Join(dir, skill, "SKILL.md")) {
			return true
		}
	}
	return false
}

func pathExists(path string) bool {
	if path == "" {
		return false
	}
	_, err := os.Lstat(path)
	return err == nil
}

func uniqueStrings(values []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, value := range values {
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		out = append(out, value)
	}
	sort.Strings(out)
	return out
}

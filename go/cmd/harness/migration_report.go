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
	CodexHome         string
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

type skillEntryForMigration struct {
	Path string
	Name string
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
	if v := os.Getenv("CODEX_HOME"); v != "" {
		env.CodexHome = v
	} else if home != "" {
		env.CodexHome = filepath.Join(home, ".codex")
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

	codexSkills := filepath.Join(env.CodexHome, "skills")
	report.Entries = append(report.Entries, reportDuplicateLocalSkills(codexSkills))
	report.Entries = append(report.Entries, reportOldSymlinks("Codex old symlinks", codexSkills, "Run scripts/setup-codex.sh --user to copy real skill directories; restore from CODEX_HOME backups if needed."))
	report.Entries = append(report.Entries, migrationReportEntry{
		Area:             "Codex backup path",
		Status:           "ok",
		Path:             filepath.Join(env.CodexHome, "backups", "setup-codex"),
		Evidence:         "scripts/setup-codex.sh stores replaced user-mode files outside the skill scan path",
		Impact:           "Existing Codex skills are moved aside before replacement instead of being deleted.",
		BackupLocation:   filepath.Join(env.CodexHome, "backups", "setup-codex"),
		RollbackProposal: "Move the backed-up skill or config entry back into CODEX_HOME after inspecting it.",
	})

	opencodeSkills := filepath.Join(projectRoot, ".opencode", "skills")
	report.Entries = append(report.Entries, reportOldSymlinks("OpenCode old symlinks", opencodeSkills, "Re-run scripts/setup-opencode.sh; inspect .opencode/*.backup.<timestamp> before restoring."))
	report.Entries = append(report.Entries, migrationReportEntry{
		Area:             "OpenCode backup path",
		Status:           "ok",
		Path:             filepath.Join(projectRoot, ".opencode"),
		Evidence:         "scripts/setup-opencode.sh creates timestamped backups such as .opencode/skills.backup.<timestamp> and .opencode/plugins/harness-bootstrap.mjs.backup.<timestamp>",
		Impact:           "Existing OpenCode files are moved aside before replacement.",
		BackupLocation:   ".opencode/*.backup.<timestamp>",
		RollbackProposal: "Move the timestamped backup back to its original path after confirming it belongs to Harness.",
	})

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
		if manifest.Name != "harness" && manifest.Name != "claude-code-harness" {
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
			Evidence:         "No harness or legacy claude-code-harness plugin.json was found under the cache path",
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
			RollbackProposal: "For harness, use /plugin update harness. For the old claude-code-harness ID, follow docs/onboarding/plugin-rename.md; update does not rename an installed plugin.",
			SupportBoundary:  "Report only; this command does not delete plugin cache entries.",
		}
	}
	return migrationReportEntry{
		Area:             "Claude plugin cache",
		Status:           "ok",
		Path:             cacheRoot,
		Evidence:         fmt.Sprintf("%d Harness cache manifest(s) observed without version drift", len(hits)),
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

func reportDuplicateLocalSkills(skillsDir string) migrationReportEntry {
	entries := readSkillEntries(skillsDir)
	if len(entries) == 0 {
		return migrationReportEntry{
			Area:             "Codex duplicate local skills",
			Status:           "not_observed",
			Path:             skillsDir,
			Evidence:         "No Codex skill entries were available to inspect",
			Impact:           "Duplicate local skills cannot be ruled out.",
			BackupLocation:   filepath.Join(filepath.Dir(skillsDir), "backups", "setup-codex"),
			RollbackProposal: "Run scripts/setup-codex.sh --user after reviewing CODEX_HOME.",
			SupportBoundary:  "not_observed != absent",
		}
	}
	byName := map[string][]string{}
	for _, entry := range entries {
		if entry.Name == "" {
			continue
		}
		byName[entry.Name] = append(byName[entry.Name], entry.Path)
	}
	var duplicates []string
	for name, paths := range byName {
		if len(paths) > 1 {
			sort.Strings(paths)
			duplicates = append(duplicates, fmt.Sprintf("%s => %s", name, strings.Join(paths, ",")))
		}
	}
	sort.Strings(duplicates)
	if len(duplicates) > 0 {
		return migrationReportEntry{
			Area:             "Codex duplicate local skills",
			Status:           "warn",
			Path:             skillsDir,
			Evidence:         strings.Join(duplicates, "; "),
			Impact:           "Codex may show duplicate aliases or route to an older skill body.",
			BackupLocation:   filepath.Join(filepath.Dir(skillsDir), "backups", "setup-codex"),
			RollbackProposal: "Run scripts/setup-codex.sh --user; it moves duplicate Harness skill aliases into backups before copying current skills.",
		}
	}
	return migrationReportEntry{
		Area:             "Codex duplicate local skills",
		Status:           "ok",
		Path:             skillsDir,
		Evidence:         "No duplicate SKILL.md frontmatter names observed",
		Impact:           "No duplicate local skill evidence was observed.",
		BackupLocation:   filepath.Join(filepath.Dir(skillsDir), "backups", "setup-codex"),
		RollbackProposal: "No action required.",
	}
}

func reportOldSymlinks(area, skillsDir, rollback string) migrationReportEntry {
	symlinks := findSymlinks(skillsDir)
	if !pathExists(skillsDir) {
		return migrationReportEntry{
			Area:             area,
			Status:           "not_observed",
			Path:             skillsDir,
			Evidence:         "Skill directory was not present",
			Impact:           "Symlink state cannot be inferred.",
			RollbackProposal: rollback,
			SupportBoundary:  "not_observed != absent",
		}
	}
	if len(symlinks) > 0 {
		return migrationReportEntry{
			Area:             area,
			Status:           "warn",
			Path:             skillsDir,
			Evidence:         strings.Join(symlinks, "; "),
			Impact:           "Symlinked skill installs can break on Windows or after moving the source checkout.",
			RollbackProposal: rollback,
		}
	}
	return migrationReportEntry{
		Area:             area,
		Status:           "ok",
		Path:             skillsDir,
		Evidence:         "No symlinked skill entries observed",
		Impact:           "No old symlink evidence was observed.",
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

func readSkillEntries(skillsDir string) []skillEntryForMigration {
	if !pathExists(skillsDir) {
		return nil
	}
	var entries []skillEntryForMigration
	children, err := os.ReadDir(skillsDir)
	if err != nil {
		return nil
	}
	for _, child := range children {
		if !child.IsDir() && child.Type()&os.ModeSymlink == 0 {
			continue
		}
		skillPath := filepath.Join(skillsDir, child.Name(), "SKILL.md")
		name := readSkillFrontmatterName(skillPath)
		if name == "" {
			continue
		}
		entries = append(entries, skillEntryForMigration{Path: filepath.Join(skillsDir, child.Name()), Name: name})
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Path < entries[j].Path })
	return entries
}

func readSkillFrontmatterName(skillPath string) string {
	data, err := os.ReadFile(skillPath)
	if err != nil {
		return ""
	}
	lines := strings.Split(string(data), "\n")
	inFrontmatter := false
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "---" {
			if !inFrontmatter {
				inFrontmatter = true
				continue
			}
			break
		}
		if !inFrontmatter || !strings.HasPrefix(trimmed, "name:") {
			continue
		}
		name := strings.TrimSpace(strings.TrimPrefix(trimmed, "name:"))
		return strings.Trim(name, `"'`)
	}
	return ""
}

func findSymlinks(root string) []string {
	if !pathExists(root) {
		return nil
	}
	children, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var symlinks []string
	for _, child := range children {
		if child.Type()&os.ModeSymlink == 0 {
			continue
		}
		path := filepath.Join(root, child.Name())
		target, err := os.Readlink(path)
		if err != nil {
			target = "unreadable"
		}
		if !isLikelyHarnessSymlink(child.Name(), target) {
			continue
		}
		status := "symlink"
		resolved := target
		if target != "unreadable" && !filepath.IsAbs(target) {
			resolved = filepath.Join(root, target)
		}
		if target == "unreadable" || !pathExists(resolved) {
			status = "broken symlink"
		}
		symlinks = append(symlinks, fmt.Sprintf("%s -> %s (%s)", path, target, status))
	}
	sort.Strings(symlinks)
	return symlinks
}

func isLikelyHarnessSymlink(name, target string) bool {
	for _, required := range migrationRequiredSkills {
		if name == required {
			return true
		}
	}
	combined := strings.ToLower(name + " " + target)
	return strings.Contains(combined, "claude-code-harness") ||
		strings.Contains(combined, "cc-harness") ||
		strings.Contains(combined, "/harness-") ||
		strings.HasPrefix(name, "harness-")
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

// Package shellscan provides shared, dependency-free scanning for shell command
// text used by the runtime floor and policy guardrail.
package shellscan

import (
	"path/filepath"
	"regexp"
	"strings"
)

var (
	interpreterNames = map[string]struct{}{
		"bash":    {},
		"sh":      {},
		"zsh":     {},
		"dash":    {},
		"ksh":     {},
		"python":  {},
		"python3": {},
		"perl":    {},
		"ruby":    {},
		"node":    {},
	}

	interpreterWrappers = map[string]struct{}{
		"command": {},
		"env":     {},
		"exec":    {},
		"nohup":   {},
		"sudo":    {},
	}

	macOSUserLibrary = regexp.MustCompile(`^/Users/[^/]+/Library(?:/|$)`)
)

// StripNonExecutableText removes line comments and document heredoc bodies.
// A heredoc body is retained when an interpreter command appears on its opener
// line, including a downstream pipeline such as "cat <<EOF | bash".
func StripNonExecutableText(command string) string {
	lines := strings.Split(command, "\n")
	out := make([]string, 0, len(lines))
	var terminator string
	var keepBody bool
	var outerSingle, outerDouble bool
	var bodySingle, bodyDouble bool

	for _, line := range lines {
		if terminator != "" {
			if strings.TrimSpace(line) == terminator {
				terminator = ""
				keepBody = false
				bodySingle = false
				bodyDouble = false
				continue
			}
			if keepBody {
				stripped, nextSingle, nextDouble := stripLineComment(line, bodySingle, bodyDouble)
				bodySingle = nextSingle
				bodyDouble = nextDouble
				out = append(out, stripped)
			}
			continue
		}

		stripped, nextSingle, nextDouble := stripLineComment(line, outerSingle, outerDouble)
		outerSingle = nextSingle
		outerDouble = nextDouble

		if heredocTerminator, ok := findHeredocTerminator(stripped); ok {
			terminator = heredocTerminator
			keepBody = openerRunsInterpreter(stripped)
		}
		out = append(out, stripped)
	}

	return strings.Join(out, "\n")
}

func stripLineComment(line string, inSingle, inDouble bool) (string, bool, bool) {
	escaped := false
	for i := 0; i < len(line); i++ {
		char := line[i]
		if escaped {
			escaped = false
			continue
		}
		if char == '\\' && !inSingle {
			escaped = true
			continue
		}
		switch {
		case char == '\'' && !inDouble:
			inSingle = !inSingle
		case char == '"' && !inSingle:
			inDouble = !inDouble
		case char == '#' && !inSingle && !inDouble:
			if i == 0 || line[i-1] == ' ' || line[i-1] == '\t' {
				return line[:i], inSingle, inDouble
			}
		}
	}
	return line, inSingle, inDouble
}

func findHeredocTerminator(line string) (string, bool) {
	inSingle := false
	inDouble := false
	escaped := false

	for i := 0; i+1 < len(line); i++ {
		char := line[i]
		if escaped {
			escaped = false
			continue
		}
		if char == '\\' && !inSingle {
			escaped = true
			continue
		}
		if char == '\'' && !inDouble {
			inSingle = !inSingle
			continue
		}
		if char == '"' && !inSingle {
			inDouble = !inDouble
			continue
		}
		if inSingle || inDouble || char != '<' || line[i+1] != '<' {
			continue
		}

		index := i + 2
		if index < len(line) && line[index] == '<' {
			continue
		}
		if index < len(line) && line[index] == '-' {
			index++
		}
		for index < len(line) && (line[index] == ' ' || line[index] == '\t') {
			index++
		}

		var quote byte
		if index < len(line) && (line[index] == '\'' || line[index] == '"') {
			quote = line[index]
			index++
		}
		if index >= len(line) || !isIdentifierStart(line[index]) {
			continue
		}

		start := index
		index++
		for index < len(line) && isIdentifierPart(line[index]) {
			index++
		}
		if quote != 0 && (index >= len(line) || line[index] != quote) {
			continue
		}
		return line[start:index], true
	}

	return "", false
}

func isIdentifierStart(char byte) bool {
	return char == '_' || char >= 'A' && char <= 'Z' || char >= 'a' && char <= 'z'
}

func isIdentifierPart(char byte) bool {
	return isIdentifierStart(char) || char >= '0' && char <= '9'
}

func openerRunsInterpreter(line string) bool {
	for _, segment := range splitCommandSegments(line) {
		if segmentRunsInterpreter(tokenize(segment)) {
			return true
		}
	}
	return false
}

func segmentRunsInterpreter(tokens []string) bool {
	for i := 0; i < len(tokens); i++ {
		token := commandName(tokens[i])
		if token == "" || isAssignment(tokens[i]) || isRedirectionToken(tokens[i]) {
			continue
		}
		if _, ok := interpreterNames[token]; ok {
			return true
		}
		if _, ok := interpreterWrappers[token]; ok {
			continue
		}
		return false
	}
	return false
}

func isAssignment(token string) bool {
	index := strings.IndexByte(token, '=')
	return index > 0 && !strings.ContainsAny(token[:index], `/\`)
}

// DangerousRemoval reports whether command contains a dangerous removal form
// and returns only the removal targets belonging to the same shell segment.
// Detection is the union of recursive rm, find -delete/-exec rm, and protected
// macOS removal paths.
func DangerousRemoval(command string) (bool, []string) {
	scannable := StripNonExecutableText(command)
	return dangerousRemoval(scannable, 0)
}

// RemovalContextIndeterminate reports whether shell execution can add removal
// targets, change the base of a relative target, or follow descendant symlinks
// beyond the paths returned by DangerousRemoval.
func RemovalContextIndeterminate(command string, targets []string) bool {
	relativeTarget := false
	for _, target := range targets {
		if !filepath.IsAbs(target) {
			relativeTarget = true
			break
		}
	}
	scannable := StripNonExecutableText(command)
	if strings.ContainsRune(scannable, '`') || containsConcurrentShellOperator(scannable, relativeTarget) {
		return true
	}
	return removalContextIndeterminate(scannable, relativeTarget, 0)
}

// containsConcurrentShellOperator reports whether command contains a shell
// operator that makes execution order or the removal target set unclear.
//
// treatPipeAsConcurrent narrows one case. A single `|` is only a hazard for the
// removal decision when a target is RELATIVE: pipeline stages run in subshells,
// so a stage could change the base directory a relative target resolves
// against. With every target absolute, the base cannot move, and each segment's
// removal targets are extracted independently (verified: `rm A | rm B` yields
// both A and B). Argument producers such as `xargs`, which really can add
// targets from stdin, are detected separately by removalContextIndeterminate
// and are unaffected by this parameter.
func containsConcurrentShellOperator(command string, treatPipeAsConcurrent bool) bool {
	inSingle := false
	inDouble := false
	escaped := false
	var previousSyntax byte
	for i := 0; i < len(command); i++ {
		char := command[i]
		if escaped {
			escaped = false
			previousSyntax = 0
			continue
		}
		if char == '\\' && !inSingle {
			escaped = true
			previousSyntax = 0
			continue
		}
		if char == '\'' && !inDouble {
			inSingle = !inSingle
			previousSyntax = 0
			continue
		}
		if char == '"' && !inSingle {
			inDouble = !inDouble
			previousSyntax = 0
			continue
		}
		if inSingle || inDouble {
			previousSyntax = 0
			continue
		}
		if (char == '<' || char == '>') && i+1 < len(command) && command[i+1] == '(' {
			return true
		}
		if char == '|' {
			if i+1 < len(command) && command[i+1] == '|' {
				i++
				previousSyntax = 0
				continue
			}
			if treatPipeAsConcurrent {
				return true
			}
			previousSyntax = char
			continue
		}
		if char == '&' {
			if previousSyntax == '<' || previousSyntax == '>' {
				previousSyntax = char
				continue
			}
			if i+1 < len(command) && command[i+1] == '&' {
				i++
				previousSyntax = 0
				continue
			}
			if i+1 < len(command) && command[i+1] == '>' {
				previousSyntax = char
				continue
			}
			return true
		}
		previousSyntax = char
	}
	return false
}

func removalContextIndeterminate(command string, relativeTarget bool, depth int) bool {
	priorNonRemovalSegment := false
	for _, segment := range splitCommandSegments(command) {
		tokens := tokenize(segment)
		findDangerous, _ := dangerousFind(tokens)
		rmDangerous, _ := dangerousRM(tokens)
		segmentDangerous, _ := dangerousRemoval(segment, 0)
		if segmentDangerous {
			// Do NOT gate priorNonRemovalSegment on relativeTarget. An absolute
			// target is not a stable target: a preceding segment can plant a
			// symlink at one of its components, leaving the path spelled the
			// same while it points somewhere else. That is the 133.10 breakout,
			// and `TestR05_PrecedingSegmentCanCreateExternalSymlink` plus
			// `preceding_segment_also_blocks_absolute_target_proof` pin it
			// (measured 2026-08-14: relaxing this made both fail).
			//
			// The cost is that any leading command — `cd`, `echo`, `ls` — makes
			// a recursive delete ask, which is how most command blocks start.
			// The remedy is on the caller's side (issue the delete as its own
			// tool call, or turn work-mode on), not a looser rule here.
			if priorNonRemovalSegment || !dangerousCommandDirectlyInvoked(tokens) {
				return true
			}
		} else if segmentCanChangeTargetResolution(tokens) {
			priorNonRemovalSegment = true
		}
		if (findDangerous || rmDangerous) && tokensContainShellExpansion(tokens) {
			return true
		}
		if relativeTarget && segmentCommandIsDynamic(tokens) {
			return true
		}

		for i, token := range tokens {
			if relativeTarget && strings.Contains(strings.ToLower(token), "chdir") {
				return true
			}
			switch commandName(token) {
			case "xargs", "parallel":
				return true
			case "cd", "chdir", "pushd", "popd":
				if relativeTarget {
					return true
				}
			case "env":
				if relativeTarget && envChangesDirectory(tokens[i+1:]) {
					return true
				}
			case "find":
				if findContextIndeterminate(tokens[i+1:]) {
					return true
				}
			}
		}

		if depth >= 4 {
			continue
		}
		for _, token := range tokens {
			if !strings.ContainsAny(token, " \t\r\n;&|()`") {
				continue
			}
			if removalContextIndeterminate(token, relativeTarget, depth+1) {
				return true
			}
		}
	}
	return false
}

func dangerousCommandDirectlyInvoked(tokens []string) bool {
	return dangerousCommandDirectlyInvokedWithFind(tokens, true)
}

func dangerousCommandDirectlyInvokedWithFind(tokens []string, allowFind bool) bool {
	for i, token := range tokens {
		if isAssignment(token) {
			return false
		}
		if isRedirectionToken(token) {
			continue
		}
		if strings.ContainsAny(token, `/\`) {
			return false
		}
		name := commandName(token)
		if _, wrapper := interpreterWrappers[name]; wrapper {
			continue
		}
		if name == "find" {
			return allowFind && findActionCommandsDirectlyInvoked(tokens[i+1:])
		}
		return name == "rm"
	}
	return false
}

func findActionCommandsDirectlyInvoked(tokens []string) bool {
	for i := 0; i < len(tokens); i++ {
		switch tokens[i] {
		case "-exec", "-execdir", "-ok", "-okdir":
		default:
			continue
		}

		end := i + 1
		for end < len(tokens) && tokens[end] != ";" && tokens[end] != "+" {
			end++
		}
		if end == len(tokens) || !dangerousCommandDirectlyInvokedWithFind(tokens[i+1:end], false) {
			return false
		}
		i = end
	}
	return true
}

func segmentCanChangeTargetResolution(tokens []string) bool {
	for _, token := range tokens {
		if isAssignment(token) {
			return true
		}
		if isRedirectionToken(token) {
			continue
		}
		return true
	}
	return false
}

func tokensContainShellExpansion(tokens []string) bool {
	for _, token := range tokens {
		if strings.ContainsAny(token, "$`*?[]{}") {
			return true
		}
	}
	return false
}

func segmentCommandIsDynamic(tokens []string) bool {
	for i, token := range tokens {
		if isAssignment(token) || isRedirectionToken(token) {
			continue
		}
		if strings.ContainsAny(token, "$`*?[]{}") {
			return true
		}
		if _, wrapper := interpreterWrappers[commandName(token)]; wrapper {
			return tokensContainShellExpansion(tokens[i+1:])
		}
		return false
	}
	return false
}

func envChangesDirectory(tokens []string) bool {
	for _, token := range tokens {
		if token == "-C" || strings.HasPrefix(token, "-C") && len(token) > len("-C") ||
			token == "--chdir" || strings.HasPrefix(token, "--chdir=") {
			return true
		}
	}
	return false
}

func findContextIndeterminate(tokens []string) bool {
	for _, token := range tokens {
		if findOptionFollowsSymlinks(token) || token == "-follow" ||
			token == "-files0-from" || strings.HasPrefix(token, "-files0-from=") {
			return true
		}
	}
	return false
}

func findOptionFollowsSymlinks(token string) bool {
	if token == "-L" {
		return true
	}
	if len(token) < 3 || token[0] != '-' {
		return false
	}
	options := token[1:]
	if fIndex := strings.IndexRune(options, 'f'); fIndex >= 0 {
		if strings.HasPrefix(token, "-files0-from") || !isBSDGlobalOptionSequence(options[:fIndex]) {
			return false
		}
		options = options[:fIndex]
	}
	return isBSDGlobalOptionSequence(options) && strings.ContainsRune(options, 'L')
}

func dangerousRemoval(command string, depth int) (bool, []string) {
	dangerous := false
	var targets []string

	for _, segment := range splitCommandSegments(command) {
		tokens := tokenize(segment)
		if len(tokens) == 0 {
			continue
		}

		segmentDangerous := false
		if findDangerous, findTargets := dangerousFind(tokens); findDangerous {
			dangerous = true
			segmentDangerous = true
			targets = appendUnique(targets, findTargets...)
			_, rmTargets := dangerousRM(tokens)
			for _, target := range rmTargets {
				if isFindPlaceholder(target) {
					continue
				}
				targets = appendUnique(targets, target)
			}
		}

		if !segmentDangerous {
			if rmDangerous, rmTargets := dangerousRM(tokens); rmDangerous {
				dangerous = true
				segmentDangerous = true
				targets = appendUnique(targets, rmTargets...)
			}
		}

		if segmentDangerous || depth >= 4 {
			continue
		}
		for _, token := range tokens {
			if !strings.ContainsAny(token, " \t\r\n;&|()`") {
				continue
			}
			nestedDangerous, nestedTargets := dangerousRemoval(token, depth+1)
			if !nestedDangerous {
				continue
			}
			dangerous = true
			targets = appendUnique(targets, nestedTargets...)
		}
	}

	if !dangerous {
		return false, nil
	}
	return true, targets
}

func dangerousRM(tokens []string) (bool, []string) {
	dangerous := false
	var targets []string

	for i, token := range tokens {
		if commandName(token) != "rm" {
			continue
		}

		recursive := false
		options := true
		var commandTargets []string
		for j := i + 1; j < len(tokens); j++ {
			arg := tokens[j]
			if isRedirectionToken(arg) {
				break
			}
			if options && arg == "--" {
				options = false
				continue
			}
			if options && strings.HasPrefix(arg, "--") {
				if strings.EqualFold(arg, "--recursive") {
					recursive = true
				}
				continue
			}
			if options && len(arg) > 1 && arg[0] == '-' {
				if strings.ContainsAny(arg[1:], "rR") {
					recursive = true
				}
				continue
			}
			commandTargets = append(commandTargets, arg)
		}

		macOSDangerous := false
		for _, target := range commandTargets {
			if isDangerousMacOSTarget(target) {
				macOSDangerous = true
				break
			}
		}
		if recursive || macOSDangerous {
			dangerous = true
			targets = appendUnique(targets, commandTargets...)
		}
	}

	return dangerous, targets
}

func dangerousFind(tokens []string) (bool, []string) {
	for i, token := range tokens {
		if commandName(token) != "find" {
			continue
		}

		dangerous := false
		for j := i + 1; j < len(tokens); j++ {
			switch tokens[j] {
			case "-delete":
				dangerous = true
			case "-exec", "-execdir":
				for k := j + 1; k < len(tokens) && tokens[k] != ";" && tokens[k] != "+"; k++ {
					if commandName(tokens[k]) == "rm" {
						dangerous = true
						break
					}
				}
			}
			if dangerous {
				break
			}
		}
		if !dangerous {
			continue
		}

		var targets []string
		options := true
		for j := i + 1; j < len(tokens); j++ {
			arg := tokens[j]
			if options && arg == "--" {
				options = false
				continue
			}
			if options {
				if attachedRoot, needsNext, ok := parseFindFileRootOption(arg); ok {
					if needsNext && j+1 < len(tokens) {
						j++
						targets = append(targets, tokens[j])
					} else if attachedRoot != "" {
						targets = append(targets, attachedRoot)
					}
					continue
				}
			}
			if options && isFindGlobalOption(arg) {
				if arg == "-D" && j+1 < len(tokens) {
					j++
				}
				continue
			}
			if isFindExpressionStart(arg) {
				break
			}
			targets = append(targets, arg)
			options = false
		}
		if len(targets) == 0 {
			targets = []string{"."}
		}
		return true, targets
	}
	return false, nil
}

func isFindGlobalOption(token string) bool {
	if token == "-H" || token == "-L" || token == "-P" ||
		token == "-D" || strings.HasPrefix(token, "-D") || strings.HasPrefix(token, "-O") {
		return true
	}
	if len(token) < 2 || token[0] != '-' {
		return false
	}
	return isBSDGlobalOptionSequence(token[1:])
}

func parseFindFileRootOption(token string) (attachedRoot string, needsNext bool, ok bool) {
	if len(token) < 2 || token[0] != '-' || strings.HasPrefix(token, "-files0-from") {
		return "", false, false
	}
	options := token[1:]
	fIndex := strings.IndexRune(options, 'f')
	if fIndex < 0 || !isBSDGlobalOptionSequence(options[:fIndex]) {
		return "", false, false
	}
	attachedRoot = options[fIndex+1:]
	return attachedRoot, attachedRoot == "", true
}

func isBSDGlobalOptionSequence(options string) bool {
	for _, option := range options {
		if !strings.ContainsRune("EHLPXdsx", option) {
			return false
		}
	}
	return true
}

func isFindExpressionStart(token string) bool {
	return strings.HasPrefix(token, "-") || token == "!" || token == "(" || token == ")"
}

func isFindPlaceholder(target string) bool {
	return target == "{}" || target == ";" || target == "+"
}

func isDangerousMacOSTarget(target string) bool {
	prefixes := []string{
		"/private/etc",
		"/private/var",
		"/private/tmp",
		"/private/home",
		"/System",
		"/Library/LaunchDaemons",
		"/Library/LaunchAgents",
		"/Library/Preferences",
		"/Library/Keychains",
		"~/Library",
	}
	for _, prefix := range prefixes {
		if target == prefix || strings.HasPrefix(target, prefix+"/") {
			return true
		}
	}
	return macOSUserLibrary.MatchString(target)
}

func commandName(token string) string {
	token = strings.TrimSpace(token)
	if token == "" {
		return ""
	}
	return strings.ToLower(filepath.Base(token))
}

func isRedirectionToken(token string) bool {
	switch token {
	case "<", ">", "<<", ">>", "&>", ">&", "&>>":
		return true
	default:
		return false
	}
}

func appendUnique(targets []string, additions ...string) []string {
	seen := make(map[string]struct{}, len(targets)+len(additions))
	for _, target := range targets {
		seen[target] = struct{}{}
	}
	for _, target := range additions {
		if target == "" {
			continue
		}
		if _, ok := seen[target]; ok {
			continue
		}
		seen[target] = struct{}{}
		targets = append(targets, target)
	}
	return targets
}

func splitCommandSegments(command string) []string {
	var segments []string
	start := 0
	inSingle := false
	inDouble := false
	escaped := false

	flush := func(end int) {
		if segment := strings.TrimSpace(command[start:end]); segment != "" {
			segments = append(segments, segment)
		}
	}

	for i := 0; i < len(command); i++ {
		char := command[i]
		if escaped {
			escaped = false
			continue
		}
		if char == '\\' && !inSingle {
			escaped = true
			continue
		}
		if char == '\'' && !inDouble {
			inSingle = !inSingle
			continue
		}
		if char == '"' && !inSingle {
			inDouble = !inDouble
			continue
		}
		if inSingle || inDouble {
			continue
		}

		width := 0
		switch char {
		case '\n', ';', '|', '(', ')', '`':
			width = 1
			if i+1 < len(command) && command[i+1] == char {
				width = 2
			}
		case '&':
			// `&>` / `&>>` are redirections, not background or `&&`.
			if i+1 < len(command) && command[i+1] == '>' {
				continue
			}
			width = 1
			if i+1 < len(command) && command[i+1] == '&' {
				width = 2
			}
		}
		if width == 0 {
			continue
		}
		flush(i)
		i += width - 1
		start = i + 1
	}
	flush(len(command))
	return segments
}

func tokenize(segment string) []string {
	var tokens []string
	var current strings.Builder
	inSingle := false
	inDouble := false
	escaped := false

	flush := func() {
		if current.Len() == 0 {
			return
		}
		tokens = append(tokens, current.String())
		current.Reset()
	}

	for i := 0; i < len(segment); i++ {
		char := segment[i]
		if escaped {
			escaped = false
			if char != '\n' {
				current.WriteByte(char)
			}
			continue
		}
		if char == '\\' && !inSingle {
			escaped = true
			continue
		}
		if char == '\'' && !inDouble {
			inSingle = !inSingle
			continue
		}
		if char == '"' && !inSingle {
			inDouble = !inDouble
			continue
		}
		if !inSingle && !inDouble {
			if char == ' ' || char == '\t' || char == '\r' || char == '\n' {
				flush()
				continue
			}
			if char == '&' && i+1 < len(segment) && segment[i+1] == '>' {
				flush()
				token := "&>"
				i++
				if i+1 < len(segment) && segment[i+1] == '>' {
					token = "&>>"
					i++
				}
				tokens = append(tokens, token)
				continue
			}
			if char == '<' || char == '>' {
				flush()
				token := string(char)
				if i+1 < len(segment) && segment[i+1] == char {
					token += string(char)
					i++
				} else if char == '>' && i+1 < len(segment) && segment[i+1] == '&' {
					token = ">&"
					i++
				}
				tokens = append(tokens, token)
				continue
			}
		}
		current.WriteByte(char)
	}
	if escaped {
		current.WriteByte('\\')
	}
	flush()
	return tokens
}

// VerbInvocation is one invocation of a named command after shell tokenization.
// Redirects holds operators only ("<", ">", "<<", ">>"), not their targets.
// Secret-path vocabulary does not belong here; callers classify the result.
type VerbInvocation struct {
	Positional []string
	Redirects  []string
}

// InspectVerbInvocations returns each invocation of verb in command.
// verb is matched as a command basename (case-insensitive) after assignments
// and interpreter wrappers. ok is false when a redirect cannot be paired with
// a target (callers should fail closed).
func InspectVerbInvocations(command, verb string) (invocations []VerbInvocation, ok bool) {
	want := strings.ToLower(strings.TrimSpace(verb))
	if want == "" {
		return nil, false
	}
	for _, segment := range splitCommandSegments(command) {
		inv, found, segmentOK := inspectSegmentVerb(tokenize(segment), want)
		if !segmentOK {
			return nil, false
		}
		if found {
			invocations = append(invocations, inv)
		}
	}
	return invocations, true
}

// InspectEgressInvocations limits arguments to their shell segment and ignores
// verb mentions in ordinary command arguments. For command launchers and shell
// control flow, retain conservative scanning rather than silently permitting a
// nested invocation whose executable position cannot be resolved statically.
func InspectEgressInvocations(command, verb string) ([]VerbInvocation, bool) {
	return inspectEgressInvocations(command, strings.ToLower(verb), 0)
}

func inspectEgressInvocations(command, want string, depth int) ([]VerbInvocation, bool) {
	if depth > 4 {
		return nil, false
	}
	var invocations []VerbInvocation
	for _, segment := range splitCommandSegments(command) {
		tokens := tokenize(segment)
		// Expansions can execute even when the outer command is echo/printf.
		for _, tok := range tokens {
			if strings.Contains(tok, "$(") || strings.ContainsRune(tok, '`') {
				nested, ok := inspectEgressInvocations(tok, want, depth+1)
				if !ok {
					return nil, false
				}
				invocations = append(invocations, nested...)
			}
		}
		conservative := false
		for i := 0; i < len(tokens); i++ {
			tok := tokens[i]
			if isRedirectionToken(tok) {
				if i+1 >= len(tokens) || isRedirectionToken(tokens[i+1]) {
					return nil, false
				}
				i++
				continue
			}
			if isAssignment(tok) {
				continue
			}
			name := commandName(tok)
			if name == want {
				inv, ok := parseVerbArgs(tokens[i+1:])
				if !ok {
					return nil, false
				}
				invocations = append(invocations, inv)
				break
			}
			_, wrapper := interpreterWrappers[name]
			_, interpreter := interpreterNames[name]
			switch name {
			case "if", "then", "elif", "else", "while", "until", "do", "!", "{",
				"time", "timeout", "nice", "xargs", "parallel", "find", "eval":
				conservative = true
			}
			conservative = conservative || wrapper || interpreter
			if !conservative {
				break
			}
			if strings.ContainsAny(tok, " \t\r\n;&|()`") {
				nested, ok := inspectEgressInvocations(tok, want, depth+1)
				if !ok {
					return nil, false
				}
				invocations = append(invocations, nested...)
			}
		}
	}
	return invocations, true
}

func inspectSegmentVerb(tokens []string, want string) (VerbInvocation, bool, bool) {
	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]
		if isAssignment(tok) {
			continue
		}
		if isRedirectionToken(tok) {
			if i+1 >= len(tokens) || isRedirectionToken(tokens[i+1]) {
				return VerbInvocation{}, false, false
			}
			i++
			continue
		}
		name := commandName(tok)
		if _, wrap := interpreterWrappers[name]; wrap {
			continue
		}
		if name != want {
			return VerbInvocation{}, false, true
		}
		inv, parseOK := parseVerbArgs(tokens[i+1:])
		return inv, true, parseOK
	}
	return VerbInvocation{}, false, true
}

func parseVerbArgs(tokens []string) (VerbInvocation, bool) {
	var inv VerbInvocation
	options := true
	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]
		if isRedirectionToken(tok) {
			if i+1 >= len(tokens) || isRedirectionToken(tokens[i+1]) {
				return VerbInvocation{}, false
			}
			inv.Redirects = append(inv.Redirects, tok)
			i++
			continue
		}
		if options && tok == "--" {
			options = false
			continue
		}
		if options && len(tok) > 1 && tok[0] == '-' {
			continue
		}
		inv.Positional = append(inv.Positional, tok)
	}
	return inv, true
}

package runtimefloor

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

// Frozen egress implementation and all helpers from origin/main 5ae202d45ad3e060e1e5678c7151b9cbdc75f4a4
// Only symbol names are prefixed. Keep independent of production helpers so
// future changes cannot silently alter both sides of the differential test.
var (
	mainEgressToolPattern       = regexp.MustCompile(`(?i)\b(?:curl|wget|nc|scp|rsync)\b`)
	mainUrlPattern              = regexp.MustCompile(`(?i)(?:https?|ftp)://([^\s/]+)`)
	mainRemoteHostPattern       = regexp.MustCompile(`(?i)(?:^|\s)(?:[\w.-]+@)?([a-z0-9][\w.-]*\.[a-z]{2,})(?::|/|\s|$)`)
	mainSchemelessHostAuthority = regexp.MustCompile(`(?i)^(?:[\w.-]+@)?([a-z0-9][\w.-]*\.[a-z]{2,})(?::\d+)?$`)
)

func mainStop(category Category, pattern, detail string) Decision {
	return Decision{
		Stopped:  true,
		Category: category,
		Pattern:  pattern,
		Reason:   fmt.Sprintf("runtime action hard floor: %s (%s)", detail, pattern),
	}
}

func mainCheckEgress(cmd string, _ Context) Decision {
	if !mainEgressToolPattern.MatchString(cmd) {
		return Decision{}
	}
	if mainEgressFloorExempted() {
		return Decision{}
	}

	lower := strings.ToLower(cmd)

	for _, match := range mainUrlPattern.FindAllStringSubmatch(cmd, -1) {
		host := strings.ToLower(strings.TrimSpace(match[1]))
		if host == "" {
			continue
		}
		host = strings.TrimSuffix(host, ":")
		if !mainIsAllowlistedHost(host) {
			return mainStop(CategoryEgress, match[0],
				"external network egress requires human approval")
		}
	}

	if strings.Contains(lower, "scp ") || strings.Contains(lower, "rsync ") {
		for _, match := range mainRemoteHostPattern.FindAllStringSubmatch(cmd, -1) {
			host := strings.ToLower(match[1])
			if !mainIsAllowlistedHost(host) {
				return mainStop(CategoryEgress, match[0],
					"remote copy/sync requires human approval")
			}
		}
	}

	if strings.Contains(lower, "nc ") {
		fields := strings.Fields(cmd)
		for i, field := range fields {
			if strings.EqualFold(field, "nc") && i+1 < len(fields) {
				host := strings.ToLower(fields[i+1])
				if !mainIsAllowlistedHost(host) {
					return mainStop(CategoryEgress, "nc "+host,
						"network connection to non-allowlisted host requires human approval")
				}
			}
		}
	}

	if decision := mainCheckCurlWgetSchemelessHosts(cmd); decision.Stopped {
		return decision
	}

	return Decision{}
}

func mainEgressFloorExempted() bool {
	return strings.EqualFold(strings.TrimSpace(os.Getenv("HARNESS_RUNTIME_FLOOR_EGRESS")), "off")
}

func mainCheckCurlWgetSchemelessHosts(cmd string) Decision {
	fields := strings.Fields(cmd)
	for i, field := range fields {
		if !strings.EqualFold(field, "curl") && !strings.EqualFold(field, "wget") {
			continue
		}
		for j := i + 1; j < len(fields); j++ {
			token := fields[j]
			if strings.HasPrefix(token, "-") {
				continue
			}
			authority := mainExtractHostAuthority(token)
			if authority == "" || mainIsAllowlistedHost(authority) {
				continue
			}
			if mainSchemelessHostAuthority.MatchString(authority) {
				return mainStop(CategoryEgress, token,
					"external network egress requires human approval")
			}
		}
	}
	return Decision{}
}

func mainExtractHostAuthority(token string) string {
	token = strings.Trim(token, `"'`)
	if slash := strings.Index(token, "/"); slash >= 0 {
		token = token[:slash]
	}
	return strings.ToLower(token)
}

func mainIsAllowlistedHost(host string) bool {
	host = strings.Trim(host, `"'`)
	host = strings.TrimSuffix(host, ":")
	if host == "localhost" || host == "127.0.0.1" {
		return true
	}
	if strings.HasPrefix(host, "localhost:") || strings.HasPrefix(host, "127.0.0.1:") {
		return true
	}
	return false
}

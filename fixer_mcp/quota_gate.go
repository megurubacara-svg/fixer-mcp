package main

import (
	"bytes"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type ProviderQuota struct {
	PercentLeft int
	ResetDelay  time.Duration
}

type QuotaGate interface {
	CheckQuota(providerName string) (ProviderQuota, bool, error)
}

type checkMyLimitsGate struct{}

var DefaultQuotaGate QuotaGate = &checkMyLimitsGate{}

func (g *checkMyLimitsGate) CheckQuota(providerName string) (ProviderQuota, bool, error) {
	cmd := exec.Command("check-my-limits")
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	if err := cmd.Run(); err != nil {
		return ProviderQuota{}, false, err
	}
	return parseCheckMyLimitsOutput(stdout.String(), providerName)
}

func parseCheckMyLimitsOutput(output, providerName string) (ProviderQuota, bool, error) {
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.Contains(strings.ToLower(line), strings.ToLower(providerName)) {
			parts := strings.Split(line, "│")
			if len(parts) < 4 {
				continue
			}
			limit5h := strings.TrimSpace(parts[2])
			if strings.Contains(limit5h, "—") {
				limit7d := strings.TrimSpace(parts[3])
				return parseQuotaCell(limit7d)
			}
			q5, found, err := parseQuotaCell(limit5h)
			if !found || err != nil || q5.PercentLeft == 0 {
				return q5, found, err
			}
			limit7d := strings.TrimSpace(parts[3])
			q7, found7, _ := parseQuotaCell(limit7d)
			if found7 && q7.PercentLeft == 0 {
				return q7, true, nil
			}
			return q5, true, nil
		}
	}
	return ProviderQuota{}, false, nil
}

func parseQuotaCell(cell string) (ProviderQuota, bool, error) {
	pctRe := regexp.MustCompile(`(\d+)%\s+left`)
	m := pctRe.FindStringSubmatch(cell)
	if m == nil {
		return ProviderQuota{}, false, nil
	}
	pct, _ := strconv.Atoi(m[1])

	resetRe := regexp.MustCompile(`reset in (?:(\d+)d\s*)?(?:(\d+)h\s*)?(?:(\d+)m\s*)?(?:(\d+)s)?`)
	rm := resetRe.FindStringSubmatch(cell)
	var delay time.Duration
	if rm != nil {
		d, _ := strconv.Atoi(rm[1])
		h, _ := strconv.Atoi(rm[2])
		mStr, _ := strconv.Atoi(rm[3])
		s, _ := strconv.Atoi(rm[4])
		delay = time.Duration(d)*24*time.Hour + time.Duration(h)*time.Hour + time.Duration(mStr)*time.Minute + time.Duration(s)*time.Second
	}
	return ProviderQuota{PercentLeft: pct, ResetDelay: delay}, true, nil
}

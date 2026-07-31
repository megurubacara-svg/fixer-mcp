package main

import (
	"crypto/sha256"
	"fmt"
	"os"
	"strings"
	"time"
)

const fixerMCPBuildIDEnv = "FIXER_MCP_BUILD_ID"

var (
	mcpRunningBuildID  = detectMCPRunningBuildID()
	mcpProcessIdentity = fmt.Sprintf("pid:%d:start:%d", os.Getpid(), time.Now().UTC().UnixNano())
)

func detectMCPRunningBuildID() string {
	if configured := strings.TrimSpace(os.Getenv(fixerMCPBuildIDEnv)); configured != "" {
		return configured
	}
	executable, err := os.Executable()
	if err != nil {
		return "unresolved-executable"
	}
	payload, err := os.ReadFile(executable)
	if err != nil {
		return "unresolved-executable"
	}
	digest := sha256.Sum256(payload)
	return fmt.Sprintf("sha256:%x", digest[:])
}

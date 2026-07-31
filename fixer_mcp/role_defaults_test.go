package main

import (
	"strings"
	"testing"
)

func TestDefaultRolePrepromptUsesProviderNeutralOrchestrationRule(t *testing.T) {
	if !strings.Contains(defaultRolePreprompt, "current provider's built-in subagent") {
		t.Fatal("default role preprompt must use provider-neutral orchestration wording")
	}
	if strings.Contains(strings.ToLower(defaultRolePreprompt), "antigravity's built-in") {
		t.Fatal("default role preprompt must not hard-code Antigravity")
	}
	if !strings.Contains(defaultRolePreprompt, "Fixer MCP Netrunner waves") {
		t.Fatal("default role preprompt must route orchestration through Netrunner waves")
	}
}

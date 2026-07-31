package main

import (
	"strings"
	"testing"
)

func TestResolveRuntimeLaunchEnvForcesPythonBytecodeGuard(t *testing.T) {
	tests := []struct {
		name    string
		baseEnv []string
	}{
		{name: "missing", baseEnv: []string{"PATH=/usr/bin"}},
		{name: "hostile inherited value", baseEnv: []string{"PATH=/usr/bin", pythonNoBytecodeEnv + "=0"}},
		{name: "duplicate inherited values", baseEnv: []string{pythonNoBytecodeEnv + "=", pythonNoBytecodeEnv + "=false", "LANG=C"}},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			resolved, err := resolveRuntimeLaunchEnv(t.TempDir(), test.baseEnv)
			if err != nil {
				t.Fatalf("resolve runtime launch env: %v", err)
			}
			matches := 0
			for _, entry := range resolved {
				if strings.HasPrefix(entry, pythonNoBytecodeEnv+"=") {
					matches++
					if entry != pythonNoBytecodeEnv+"=1" {
						t.Fatalf("unexpected bytecode guard %q", entry)
					}
				}
			}
			if matches != 1 {
				t.Fatalf("expected exactly one bytecode guard, got %d in %v", matches, resolved)
			}
		})
	}
}

func TestReplaceEnvSliceValuePreservesUnrelatedEntries(t *testing.T) {
	resolved := replaceEnvSliceValue([]string{"A=1", "B=2", "A=old"}, "A", "new")
	if got := envSliceToMap(resolved); got["A"] != "new" || got["B"] != "2" || len(resolved) != 2 {
		t.Fatalf("unexpected replaced environment: %v", resolved)
	}
}

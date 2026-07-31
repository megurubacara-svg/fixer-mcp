package dashboardapi

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestOverseerHistoryDiscoversProviderThreadsWithSourceMetadata(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()
	cwd := repo.currentProjectCWD
	home := userHomeDir()
	slug := providerProjectSlug(cwd)

	writeOverseerFixture(t, filepath.Join(home, ".codex", "sessions", "overseer-source.jsonl"), strings.Join([]string{
		`{"timestamp":"2026-07-20T10:00:00Z","type":"session_meta","payload":{"id":"codex-overseer-source","cwd":` + mustJSON(t, cwd) + `,"timestamp":"2026-07-20T10:00:00Z"}}`,
		`{"timestamp":"2026-07-20T10:01:00Z","type":"turn_context","payload":{"model":"gpt-5.6-sol","effort":"high"}}`,
		`{"timestamp":"2026-07-20T10:02:00Z","type":"response_item","payload":{"text":"Activate skill ` + "`$init-overseer`" + ` immediately."}}`,
	}, "\n"))
	writeOverseerFixture(t, filepath.Join(home, ".claude", "projects", slug, "claude-overseer.jsonl"),
		`{"sessionId":"claude-overseer","model":"opus","timestamp":"2026-07-20T11:00:00Z","message":{"content":"Activate skill `+"`$init-overseer`"+` immediately."}}`)
	writeOverseerFixture(t, filepath.Join(home, ".factory", "sessions", slug, "droid-overseer.jsonl"),
		`{"id":"droid-overseer","model":"glm-5.1","reasoning":"high","title":"Droid Overseer","message":"Activate skill `+"`$init-overseer`"+` immediately."}`)
	writeOverseerFixture(t, filepath.Join(home, ".junie", "sessions", "index.jsonl"),
		`{"sessionId":"junie-overseer","projectDir":`+mustJSON(t, cwd)+`,"model":"kimi-k2.6","taskName":"Junie Overseer","createdAt":"2026-07-20T12:00:00Z","updatedAt":"2026-07-20T12:30:00Z"}`)
	writeOverseerFixture(t, filepath.Join(home, ".junie", "sessions", "junie-overseer", "state.json"),
		`{"prompt":"Activate skill `+"`$init-overseer`"+` immediately."}`)
	writeOverseerFixture(t, filepath.Join(home, ".gemini", "antigravity-cli", "history.jsonl"),
		`{"workspace":`+mustJSON(t, cwd)+`,"conversationId":"agy-overseer","display":"Antigravity Overseer"}`)
	writeOverseerFixture(t, filepath.Join(home, ".gemini", "antigravity-cli", "conversations", "agy-overseer.db"),
		"Use the `init-overseer` skill immediately.\n")
	hash := md5.Sum([]byte(cwd))
	writeOverseerFixture(t, filepath.Join(home, ".kimi", "sessions", hex.EncodeToString(hash[:]), "kimi-overseer", "context.jsonl"),
		`{"model":"kimi-k2.7-code","message":"Activate skill `+"`$init-overseer`"+` immediately."}`)

	history, err := repo.OverseerHistory(context.Background())
	if err != nil {
		t.Fatalf("load Overseer history: %v", err)
	}
	byBackend := map[string]OverseerThreadSummary{}
	byExternalID := map[string]OverseerThreadSummary{}
	for _, thread := range history.Threads {
		byBackend[thread.Backend] = thread
		byExternalID[thread.ExternalSessionID] = thread
	}
	for _, backend := range []string{"codex", "claude", "droid", "junie", "antigravity", "kimi-code"} {
		thread, ok := byBackend[backend]
		if !ok {
			t.Fatalf("expected %s Overseer thread, got %+v", backend, history.Threads)
		}
		if thread.ExternalSessionID == "" || thread.Model == "" || thread.Reasoning == "" {
			t.Fatalf("expected identity and model metadata for %s, got %+v", backend, thread)
		}
		if thread.SpawnCWD != cwd || thread.Origin == "" {
			t.Fatalf("expected source cwd/origin for %s, got %+v", backend, thread)
		}
	}
	sourceCodex := byExternalID["codex-overseer-source"]
	if sourceCodex.Model != "gpt-5.6-sol" || sourceCodex.Reasoning != "high" {
		t.Fatalf("expected parsed Codex model metadata, got %+v", sourceCodex)
	}
}

func TestBuildOverseerLaunchPlanPreservesLockedRoleAndProviderResume(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	createPlan, err := repo.BuildOverseerLaunchPlan(OverseerLaunchInput{
		CWD:       repo.currentProjectCWD,
		Backend:   "droid",
		Model:     "glm-5.1",
		Reasoning: "high",
	})
	if err != nil {
		t.Fatalf("build create plan: %v", err)
	}
	if createPlan.Mode != "create" || createPlan.Prompt != overseerSkillMarker {
		t.Fatalf("unexpected create plan: %+v", createPlan)
	}
	if createPlan.Environment["FIXER_MCP_LOCKED_ROLE"] != "overseer" || createPlan.Environment["FIXER_MCP_DEFAULT_CWD"] != repo.currentProjectCWD {
		t.Fatalf("missing locked-role environment: %+v", createPlan.Environment)
	}
	if len(createPlan.RequiredMCPs) != 1 || createPlan.RequiredMCPs[0] != "fixer_mcp" {
		t.Fatalf("expected forced fixer_mcp selection, got %+v", createPlan.RequiredMCPs)
	}

	for _, backend := range []string{"codex", "claude", "droid", "antigravity", "junie", "kimi-code"} {
		plan, err := repo.BuildOverseerLaunchPlan(OverseerLaunchInput{
			CWD:               repo.currentProjectCWD,
			Backend:           backend,
			ExternalSessionID: "opaque-session-42",
		})
		if err != nil {
			t.Fatalf("build %s resume plan: %v", backend, err)
		}
		if plan.Mode != "resume" || plan.Backend != backend || plan.Prompt != "" {
			t.Fatalf("unexpected %s resume plan: %+v", backend, plan)
		}
		if !strings.Contains(strings.Join(plan.Command, " "), "opaque-session-42") {
			t.Fatalf("%s resume command lost external identity: %v", backend, plan.Command)
		}
		raw, _ := json.Marshal(plan)
		if strings.Contains(strings.ToLower(string(raw)), "api_key") || strings.Contains(strings.ToLower(string(raw)), "token") {
			t.Fatalf("secret-like data leaked into launch plan: %s", raw)
		}
	}
}

func TestBuildOverseerLaunchPlanCreateCommandBackendMatrix(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	backends := []string{"codex", "claude", "droid", "antigravity", "junie", "kimi-code"}
	for _, backend := range backends {
		t.Run(backend, func(t *testing.T) {
			plan, err := repo.BuildOverseerLaunchPlan(OverseerLaunchInput{
				CWD:       repo.currentProjectCWD,
				Backend:   backend,
				Model:     "matrix-model",
				Reasoning: "default",
			})
			if err != nil {
				t.Fatalf("build %s create plan: %v", backend, err)
			}
			if plan.Mode != "create" || plan.Prompt != overseerSkillMarker {
				t.Fatalf("unexpected %s create plan: %+v", backend, plan)
			}
			if !strings.Contains(strings.Join(plan.Command, " "), overseerSkillMarker) {
				t.Fatalf("%s create command lost init-overseer prompt: %v", backend, plan.Command)
			}
			if plan.Environment["FIXER_MCP_LOCKED_ROLE"] != "overseer" || plan.Environment["FIXER_MCP_DEFAULT_CWD"] != repo.currentProjectCWD {
				t.Fatalf("missing locked-role environment for %s: %+v", backend, plan.Environment)
			}
			if len(plan.RequiredMCPs) != 1 || plan.RequiredMCPs[0] != "fixer_mcp" {
				t.Fatalf("expected forced fixer_mcp selection for %s, got %+v", backend, plan.RequiredMCPs)
			}
			raw, _ := json.Marshal(plan)
			lower := strings.ToLower(string(raw))
			if strings.Contains(lower, "api_key") || strings.Contains(lower, "token") || strings.Contains(lower, "secret") {
				t.Fatalf("secret-like data leaked into %s create plan: %s", backend, raw)
			}
		})
	}
}

func TestBuildOverseerLaunchPlanRejectsUnsafeCWDAndUnknownBackend(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()
	if _, err := repo.BuildOverseerLaunchPlan(OverseerLaunchInput{CWD: "relative/path", Backend: "codex"}); err == nil {
		t.Fatal("expected relative cwd rejection")
	}
	if _, err := repo.BuildOverseerLaunchPlan(OverseerLaunchInput{CWD: repo.currentProjectCWD, Backend: "unknown"}); err == nil {
		t.Fatal("expected unknown backend rejection")
	}
}

func writeOverseerFixture(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(content+"\n"), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func mustJSON(t *testing.T, value string) string {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("marshal fixture value: %v", err)
	}
	return string(raw)
}

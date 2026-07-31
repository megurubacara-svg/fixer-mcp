package dashboardapi

import (
	"context"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestFixerThreadsListsAllSupportedProviderStores(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	project, err := repo.requireProject(context.Background(), 1)
	if err != nil {
		t.Fatalf("load project: %v", err)
	}
	home := os.Getenv("HOME")
	seedProviderFixerThreadFixtures(t, home, project.CWD)

	response, err := repo.FixerThreads(context.Background(), 1)
	if err != nil {
		t.Fatalf("FixerThreads: %v", err)
	}
	if !response.Supported {
		t.Fatalf("expected supported response: %+v", response)
	}
	if response.CWD != project.CWD {
		t.Fatalf("expected project cwd %q, got %q", project.CWD, response.CWD)
	}

	wantProviders := map[string]bool{
		"codex": true, "antigravity": true, "claude": true,
		"kimi-code": true, "droid": true, "junie": true,
	}
	for _, thread := range response.Threads {
		delete(wantProviders, thread.Backend)
		if thread.ExternalID == "" || thread.Model == "" {
			t.Fatalf("thread omitted session/model metadata: %+v", thread)
		}
		if thread.CWD != project.CWD {
			t.Fatalf("thread %s/%s omitted cwd metadata: %+v", thread.Backend, thread.ExternalID, thread)
		}
	}
	if len(wantProviders) != 0 {
		t.Fatalf("missing provider threads: %v; got %+v", wantProviders, response.Threads)
	}
}

func TestFixerChatBindingIncludesNonCodexFixerHistory(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	project, err := repo.requireProject(context.Background(), 1)
	if err != nil {
		t.Fatalf("load project: %v", err)
	}
	seedProviderFixerThreadFixtures(t, os.Getenv("HOME"), project.CWD)

	binding, err := repo.FixerChatBinding(context.Background(), 1)
	if err != nil {
		t.Fatalf("FixerChatBinding: %v", err)
	}
	providers := map[string]bool{}
	for _, session := range binding.Sessions {
		providers[session.Backend] = true
	}
	for _, provider := range supportedFixerThreadProviders {
		if !providers[provider] {
			t.Fatalf("expected %s in fixer chat binding, got %v", provider, providers)
		}
	}
}

func seedProviderFixerThreadFixtures(t *testing.T, home string, cwd string) {
	t.Helper()
	marker := "Activate skill `$init-fixer` immediately."
	slug := providerProjectStoreSlug(cwd)
	writeFixtureFile(t, filepath.Join(home, ".claude", "projects", slug, "claude-session.jsonl"),
		fmt.Sprintf("{\"sessionId\":\"claude-session\",\"cwd\":%q,\"timestamp\":\"2026-07-20T10:00:00Z\",\"model\":\"sonnet\",\"message\":{\"content\":%q}}\n", cwd, marker))
	writeFixtureFile(t, filepath.Join(home, ".factory", "sessions", slug, "droid-session.jsonl"),
		fmt.Sprintf("{\"id\":\"droid-session\",\"cwd\":%q,\"timestamp\":\"2026-07-20T11:00:00Z\",\"sessionTitle\":\"Droid Fixer\",\"model\":\"kimi-k2.7-code\",\"content\":%q}\n", cwd, marker))

	hash := md5.Sum([]byte(filepath.Clean(cwd)))
	kimiPath := filepath.Join(home, ".kimi", "sessions", hex.EncodeToString(hash[:]), "kimi-session", "context.jsonl")
	writeFixtureFile(t, kimiPath, fmt.Sprintf("{\"role\":\"user\",\"content\":%q,\"model\":\"kimi-k2.7-code\"}\n", marker))

	junieRoot := filepath.Join(home, ".junie", "sessions")
	writeFixtureFile(t, filepath.Join(junieRoot, "index.jsonl"),
		fmt.Sprintf("{\"sessionId\":\"junie-session\",\"projectDir\":%q,\"taskName\":\"Junie Fixer\",\"model\":\"kimi-k2.6\",\"createdAt\":\"2026-07-20T12:00:00Z\",\"updatedAt\":\"2026-07-20T12:30:00Z\"}\n", cwd))
	writeFixtureFile(t, filepath.Join(junieRoot, "junie-session", "state.json"), fmt.Sprintf("{\"prompt\":%q}\n", marker))

	agyRoot := filepath.Join(home, ".gemini", "antigravity-cli")
	writeFixtureFile(t, filepath.Join(agyRoot, "history.jsonl"),
		fmt.Sprintf("{\"conversationId\":\"agy-session\",\"workspace\":%q,\"display\":\"Antigravity Fixer\",\"model\":\"Gemini 3.5 Flash\",\"timestamp\":\"2026-07-20T13:00:00Z\"}\n", cwd))
	writeFixtureFile(t, filepath.Join(agyRoot, "conversations", "agy-session.pb"), "binary-prefix\n"+marker+"\nbinary-suffix")
}

func writeFixtureFile(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

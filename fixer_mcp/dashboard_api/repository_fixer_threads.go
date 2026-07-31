package dashboardapi

import (
	"bufio"
	"bytes"
	"context"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// FixerThreadSummary is the provider-neutral repository contract used by the
// Fixer Chat feature. Shared HTTP routing can expose it without teaching the
// Flutter client about provider-specific history stores.
type FixerThreadSummary struct {
	ExternalID     string `json:"external_id"`
	Headline       string `json:"headline"`
	Status         string `json:"status"`
	AgentRole      string `json:"agent_role"`
	Backend        string `json:"backend"`
	Model          string `json:"model,omitempty"`
	Reasoning      string `json:"reasoning,omitempty"`
	CWD            string `json:"cwd"`
	StartedAt      string `json:"started_at,omitempty"`
	LastActivityAt string `json:"last_activity_at,omitempty"`
	BindingSource  string `json:"binding_source"`
	SessionLogPath string `json:"session_log_path,omitempty"`
	Transcript     bool   `json:"transcript_available"`
}

type FixerThreadsResponse struct {
	ProjectID   int                  `json:"project_id"`
	ProjectName string               `json:"project_name"`
	CWD         string               `json:"cwd"`
	Supported   bool                 `json:"supported"`
	Providers   []string             `json:"providers"`
	Threads     []FixerThreadSummary `json:"threads"`
}

var supportedFixerThreadProviders = []string{
	"codex", "antigravity", "claude", "kimi-code", "droid", "junie",
}

// FixerThreads returns historical Fixer threads from every locally supported
// CLI store. It is deliberately repository-only so route/composition owners can
// wire it without creating a dependency on launcher internals.
func (r *Repository) FixerThreads(ctx context.Context, projectID int) (FixerThreadsResponse, error) {
	project, err := r.requireProject(ctx, projectID)
	if err != nil {
		return FixerThreadsResponse{}, err
	}

	aliasNotes := r.loadFixerResumeAliasNotes(ctx, projectID)
	activeID := r.loadActiveAutonomousFixerSessionID(ctx, projectID, project.CWD)
	codexSessions, _ := loadCodexChatSessions(project.CWD, activeID, aliasNotes)
	threads := make([]FixerThreadSummary, 0, len(codexSessions)+12)
	for _, session := range codexSessions {
		if session.AgentRole != "fixer" {
			continue
		}
		threads = append(threads, fixerThreadFromChatSession(session, project.CWD))
	}
	threads = append(threads, loadHistoricalProviderFixerThreads(userHomeDir(), project.CWD)...)
	threads = dedupeAndSortFixerThreads(threads)

	return FixerThreadsResponse{
		ProjectID:   project.ID,
		ProjectName: project.Name,
		CWD:         project.CWD,
		Supported:   len(threads) > 0,
		Providers:   append([]string(nil), supportedFixerThreadProviders...),
		Threads:     threads,
	}, nil
}

func fixerThreadFromChatSession(session codexChatSession, cwd string) FixerThreadSummary {
	return FixerThreadSummary{
		ExternalID:     session.SessionID,
		Headline:       session.Headline,
		Status:         session.Status,
		AgentRole:      session.AgentRole,
		Backend:        session.Backend,
		Model:          session.Model,
		Reasoning:      session.Reasoning,
		CWD:            cwd,
		StartedAt:      session.StartedAt,
		LastActivityAt: session.LastActivityAt,
		BindingSource:  session.BindingSource,
		SessionLogPath: session.SessionLogPath,
		Transcript:     session.Transcript,
	}
}

func loadNonCodexFixerChatSessions(homeDir string, projectCWD string) []codexChatSession {
	threads := loadHistoricalProviderFixerThreads(homeDir, projectCWD)
	sessions := make([]codexChatSession, 0, len(threads))
	for _, thread := range threads {
		sessions = append(sessions, codexChatSession{
			SessionID:      thread.ExternalID,
			CWD:            thread.CWD,
			StartedAt:      thread.StartedAt,
			LastActivityAt: thread.LastActivityAt,
			Backend:        thread.Backend,
			Model:          thread.Model,
			Reasoning:      thread.Reasoning,
			AgentRole:      "fixer",
			BindingSource:  thread.BindingSource,
			SessionLogPath: thread.SessionLogPath,
			SessionLog:     thread.SessionLogPath != "",
			Status:         thread.Status,
			Headline:       thread.Headline,
			Transcript:     thread.Transcript,
		})
	}
	return sessions
}

func loadHistoricalProviderFixerThreads(homeDir string, projectCWD string) []FixerThreadSummary {
	threads := []FixerThreadSummary{}
	projectSlug := providerProjectStoreSlug(projectCWD)
	threads = append(threads, loadFlatJSONLFixerThreads(
		"claude",
		filepath.Join(homeDir, ".claude", "projects", projectSlug),
		projectCWD,
	)...)
	threads = append(threads, loadFlatJSONLFixerThreads(
		"droid",
		filepath.Join(homeDir, ".factory", "sessions", projectSlug),
		projectCWD,
	)...)
	threads = append(threads, loadKimiFixerThreads(homeDir, projectCWD)...)
	threads = append(threads, loadJunieFixerThreads(homeDir, projectCWD)...)
	threads = append(threads, loadAntigravityFixerThreads(homeDir, projectCWD)...)
	return dedupeAndSortFixerThreads(threads)
}

var nonAlphanumericStoreSlug = regexp.MustCompile(`[^A-Za-z0-9]+`)

func providerProjectStoreSlug(cwd string) string {
	return nonAlphanumericStoreSlug.ReplaceAllString(filepath.Clean(cwd), "-")
}

func loadFlatJSONLFixerThreads(backend string, directory string, projectCWD string) []FixerThreadSummary {
	paths, _ := filepath.Glob(filepath.Join(directory, "*.jsonl"))
	threads := make([]FixerThreadSummary, 0, len(paths))
	for _, path := range paths {
		thread, ok := inspectProviderJSONL(path, backend, projectCWD, strings.TrimSuffix(filepath.Base(path), filepath.Ext(path)))
		if ok {
			threads = append(threads, thread)
		}
	}
	return threads
}

func inspectProviderJSONL(path string, backend string, projectCWD string, fallbackID string) (FixerThreadSummary, bool) {
	file, err := os.Open(path)
	if err != nil {
		return FixerThreadSummary{}, false
	}
	defer file.Close()

	thread := FixerThreadSummary{
		ExternalID:     fallbackID,
		Headline:       fallbackHeadline("fixer", fallbackID),
		Status:         "history",
		AgentRole:      "fixer",
		Backend:        backend,
		CWD:            filepath.Clean(projectCWD),
		BindingSource:  backend + "_session_log",
		SessionLogPath: path,
		Transcript:     true,
	}
	info, _ := file.Stat()
	if info != nil {
		thread.StartedAt = info.ModTime().UTC().Format(time.RFC3339Nano)
		thread.LastActivityAt = thread.StartedAt
	}

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	roleLines := map[string]int{}
	lineIndex := 0
	for scanner.Scan() {
		raw := append([]byte(nil), scanner.Bytes()...)
		if lineIndex < maxRoleMarkerLines {
			collectProviderRoleMarkers(string(raw), lineIndex, roleLines)
		}
		if lineIndex < 500 {
			var record map[string]any
			if json.Unmarshal(raw, &record) == nil {
				populateThreadFromRecord(&thread, record, projectCWD)
			}
		}
		lineIndex++
	}
	if classifyProviderRole(roleLines) != "fixer" {
		return FixerThreadSummary{}, false
	}
	if strings.TrimSpace(thread.ExternalID) == "" {
		thread.ExternalID = fallbackID
	}
	if thread.Headline == "" || strings.Contains(thread.Headline, fallbackID) {
		thread.Headline = fallbackHeadline("fixer", thread.ExternalID)
	}
	return thread, true
}

func populateThreadFromRecord(thread *FixerThreadSummary, record map[string]any, projectCWD string) {
	if value := directString(record, "cwd", "projectDir", "workspace", "work_dir"); value != "" {
		if filepath.Clean(value) != filepath.Clean(projectCWD) {
			return
		}
		thread.CWD = filepath.Clean(value)
	}
	if value := directString(record, "sessionId", "conversationId"); value != "" {
		thread.ExternalID = value
	} else if value := directString(record, "id"); value != "" && thread.ExternalID == "" {
		thread.ExternalID = value
	}
	if value := recursiveString(record, "model", "modelName", "model_id"); value != "" && thread.Model == "" {
		thread.Model = value
	}
	if value := recursiveString(record, "reasoning", "effort", "reasoning_effort"); value != "" && thread.Reasoning == "" {
		thread.Reasoning = value
	}
	if value := directString(record, "sessionTitle", "title", "taskName", "display"); value != "" {
		thread.Headline = firstLineOrFallback(value, thread.Headline)
	}
	if value := directString(record, "timestamp", "createdAt", "startTime"); value != "" && thread.StartedAt == "" {
		thread.StartedAt = value
	}
	if value := directString(record, "updatedAt", "lastUpdated", "timestamp"); value != "" {
		thread.LastActivityAt = value
	}
}

func directString(record map[string]any, keys ...string) string {
	for _, key := range keys {
		if value, ok := record[key].(string); ok && strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func recursiveString(value any, keys ...string) string {
	wanted := map[string]bool{}
	for _, key := range keys {
		wanted[key] = true
	}
	var walk func(any) string
	walk = func(current any) string {
		switch typed := current.(type) {
		case map[string]any:
			for key, item := range typed {
				if wanted[key] {
					if text, ok := item.(string); ok && strings.TrimSpace(text) != "" {
						return strings.TrimSpace(text)
					}
				}
			}
			for _, item := range typed {
				if found := walk(item); found != "" {
					return found
				}
			}
		case []any:
			for _, item := range typed {
				if found := walk(item); found != "" {
					return found
				}
			}
		}
		return ""
	}
	return walk(value)
}

func collectProviderRoleMarkers(text string, line int, firstLines map[string]int) {
	markers := map[string][]string{
		"fixer":     {fixerSkillMarker, "`init-fixer`", "/init-fixer", "`start-fixer`", "/start-fixer"},
		"overseer":  {overseerSkillMarker, "`init-overseer`", "/init-overseer", "`start-overseer`", "/start-overseer"},
		"netrunner": {netrunnerSkillMarker, "`run-manual-netrunner`", "/run-manual-netrunner", "`start-netrunner`", "/start-netrunner"},
	}
	for role, variants := range markers {
		if _, exists := firstLines[role]; exists {
			continue
		}
		for _, marker := range variants {
			if strings.Contains(text, marker) {
				firstLines[role] = line
				break
			}
		}
	}
}

func classifyProviderRole(firstLines map[string]int) string {
	selected := ""
	selectedLine := maxRoleMarkerLines + 1
	for _, role := range []string{"fixer", "overseer", "netrunner"} {
		if line, ok := firstLines[role]; ok && line < selectedLine {
			selected = role
			selectedLine = line
		}
	}
	return selected
}

func loadKimiFixerThreads(homeDir string, projectCWD string) []FixerThreadSummary {
	hash := md5.Sum([]byte(filepath.Clean(projectCWD)))
	projectRoot := filepath.Join(homeDir, ".kimi", "sessions", hex.EncodeToString(hash[:]))
	sessionDirs, _ := filepath.Glob(filepath.Join(projectRoot, "*"))
	threads := []FixerThreadSummary{}
	for _, sessionDir := range sessionDirs {
		info, err := os.Stat(sessionDir)
		if err != nil || !info.IsDir() {
			continue
		}
		paths, _ := filepath.Glob(filepath.Join(sessionDir, "context*.jsonl"))
		paths = append(paths, filepath.Join(sessionDir, "wire.jsonl"))
		for _, path := range paths {
			thread, ok := inspectProviderJSONL(path, "kimi-code", projectCWD, filepath.Base(sessionDir))
			if ok {
				thread.ExternalID = filepath.Base(sessionDir)
				threads = append(threads, thread)
				break
			}
		}
	}
	return threads
}

func loadJunieFixerThreads(homeDir string, projectCWD string) []FixerThreadSummary {
	indexPath := filepath.Join(homeDir, ".junie", "sessions", "index.jsonl")
	file, err := os.Open(indexPath)
	if err != nil {
		return nil
	}
	defer file.Close()

	threads := []FixerThreadSummary{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		var record map[string]any
		if json.Unmarshal(scanner.Bytes(), &record) != nil || filepath.Clean(directString(record, "projectDir")) != filepath.Clean(projectCWD) {
			continue
		}
		sessionID := directString(record, "sessionId")
		if sessionID == "" {
			continue
		}
		sessionDir := filepath.Join(filepath.Dir(indexPath), sessionID)
		markerPath := filepath.Join(sessionDir, "state.json")
		if _, err := os.Stat(markerPath); err != nil {
			markerPath = filepath.Join(sessionDir, "events.jsonl")
		}
		raw, err := os.ReadFile(markerPath)
		if err != nil || roleFromRawProviderContent(raw) != "fixer" {
			continue
		}
		thread := FixerThreadSummary{
			ExternalID:     sessionID,
			Headline:       firstLineOrFallback(directString(record, "taskName", "title"), fallbackHeadline("fixer", sessionID)),
			Status:         "history",
			AgentRole:      "fixer",
			Backend:        "junie",
			Model:          recursiveString(record, "model", "modelName"),
			Reasoning:      recursiveString(record, "reasoning", "effort"),
			CWD:            filepath.Clean(projectCWD),
			StartedAt:      directString(record, "createdAt"),
			LastActivityAt: directString(record, "updatedAt"),
			BindingSource:  "junie_session_index",
			SessionLogPath: markerPath,
			Transcript:     strings.HasSuffix(markerPath, ".jsonl"),
		}
		threads = append(threads, thread)
	}
	return threads
}

func loadAntigravityFixerThreads(homeDir string, projectCWD string) []FixerThreadSummary {
	root := filepath.Join(homeDir, ".gemini", "antigravity-cli")
	historyPath := filepath.Join(root, "history.jsonl")
	file, err := os.Open(historyPath)
	if err != nil {
		return nil
	}
	defer file.Close()

	threads := []FixerThreadSummary{}
	seen := map[string]bool{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		var record map[string]any
		if json.Unmarshal(scanner.Bytes(), &record) != nil || filepath.Clean(directString(record, "workspace")) != filepath.Clean(projectCWD) {
			continue
		}
		conversationID := directString(record, "conversationId")
		if conversationID == "" || seen[conversationID] {
			continue
		}
		seen[conversationID] = true
		conversationPath := ""
		for _, ext := range []string{".db", ".pb"} {
			candidate := filepath.Join(root, "conversations", conversationID+ext)
			if _, err := os.Stat(candidate); err == nil {
				conversationPath = candidate
				break
			}
		}
		if conversationPath == "" {
			continue
		}
		raw, err := os.ReadFile(conversationPath)
		if err != nil || roleFromRawProviderContent(raw) != "fixer" {
			continue
		}
		updated := directString(record, "updatedAt", "timestamp")
		if updated == "" {
			if info, err := os.Stat(conversationPath); err == nil {
				updated = info.ModTime().UTC().Format(time.RFC3339Nano)
			}
		}
		threads = append(threads, FixerThreadSummary{
			ExternalID:     conversationID,
			Headline:       firstLineOrFallback(directString(record, "display", "title"), fallbackHeadline("fixer", conversationID)),
			Status:         "history",
			AgentRole:      "fixer",
			Backend:        "antigravity",
			Model:          recursiveString(record, "model", "modelName"),
			Reasoning:      recursiveString(record, "reasoning", "effort"),
			CWD:            filepath.Clean(projectCWD),
			StartedAt:      directString(record, "createdAt", "timestamp"),
			LastActivityAt: updated,
			BindingSource:  "antigravity_conversation_store",
			SessionLogPath: conversationPath,
			Transcript:     true,
		})
	}
	return threads
}

func roleFromRawProviderContent(raw []byte) string {
	firstLines := map[string]int{}
	for _, line := range bytes.Split(raw, []byte{'\n'}) {
		collectProviderRoleMarkers(string(line), len(firstLines), firstLines)
	}
	return classifyProviderRole(firstLines)
}

func dedupeAndSortFixerThreads(threads []FixerThreadSummary) []FixerThreadSummary {
	seen := map[string]bool{}
	filtered := make([]FixerThreadSummary, 0, len(threads))
	for _, thread := range threads {
		key := thread.Backend + "\x00" + thread.ExternalID
		if thread.ExternalID == "" || seen[key] {
			continue
		}
		seen[key] = true
		filtered = append(filtered, thread)
	}
	sort.SliceStable(filtered, func(i, j int) bool {
		return filtered[i].LastActivityAt > filtered[j].LastActivityAt
	})
	return filtered
}

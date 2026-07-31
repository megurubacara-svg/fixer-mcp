package dashboardapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

var (
	ErrPlannedWaveInitializeUnavailable = errors.New("governed planned-wave Initialize is unavailable")
	ErrPlannedWaveInitializeRejected    = errors.New("governed planned-wave Initialize was rejected")
)

type fixerMCPCommandSpec struct {
	name string
	args []string
	dir  string
}

func (r *Repository) plannedWaveInitializeRouteAvailable(project projectRecord) bool {
	if r == nil || r.plannedWaveInitializer == nil || r.plannedWaveInitializerAvailable == nil {
		return false
	}
	return r.plannedWaveInitializerAvailable(project)
}

func (r *Repository) canInitializePlannedWaveThroughFixerMCP(project projectRecord) bool {
	_, err := resolveFixerMCPCommand(project)
	return err == nil
}

func resolveFixerMCPCommand(project projectRecord) (fixerMCPCommandSpec, error) {
	if configured := strings.TrimSpace(os.Getenv("FIXER_MCP_BINARY")); configured != "" {
		if info, err := os.Stat(configured); err == nil && !info.IsDir() {
			return fixerMCPCommandSpec{name: configured, dir: filepath.Dir(configured)}, nil
		}
		return fixerMCPCommandSpec{}, fmt.Errorf("%w: FIXER_MCP_BINARY does not identify a file", ErrPlannedWaveInitializeUnavailable)
	}
	projectBinary := filepath.Join(project.CWD, "fixer_mcp", "fixer_mcp")
	if info, err := os.Stat(projectBinary); err == nil && !info.IsDir() {
		return fixerMCPCommandSpec{name: projectBinary, dir: filepath.Dir(projectBinary)}, nil
	}
	if binary, err := exec.LookPath("fixer_mcp"); err == nil {
		return fixerMCPCommandSpec{name: binary, dir: filepath.Dir(binary)}, nil
	}
	goModuleRoot := filepath.Join(project.CWD, "fixer_mcp")
	if _, err := os.Stat(filepath.Join(goModuleRoot, "go.mod")); err == nil {
		if goBinary, lookErr := exec.LookPath("go"); lookErr == nil {
			return fixerMCPCommandSpec{name: goBinary, args: []string{"run", "."}, dir: goModuleRoot}, nil
		}
	}
	return fixerMCPCommandSpec{}, fmt.Errorf("%w: no fixer_mcp binary or runnable source tree was found", ErrPlannedWaveInitializeUnavailable)
}

func (r *Repository) initializePlannedWaveThroughFixerMCP(ctx context.Context, project projectRecord, planID int) (int, error) {
	spec, err := resolveFixerMCPCommand(project)
	if err != nil {
		return 0, err
	}
	command := exec.CommandContext(ctx, spec.name, spec.args...)
	command.Dir = spec.dir
	command.Env = environmentWithOverrides(os.Environ(), map[string]string{
		"FIXER_DB_PATH":          r.databasePath,
		"FIXER_MCP_LOCKED_ROLE":  "fixer",
		"FIXER_MCP_DEFAULT_ROLE": "",
		"FIXER_MCP_DEFAULT_CWD":  "",
		"FIXER_MCP_AUTO_AUTH":    "",
		"FIXER_MCP_TOOL_PROFILE": "",
	})
	client := mcp.NewClient(&mcp.Implementation{Name: "dashboard-api", Version: "v1.0.0"}, nil)
	session, err := client.Connect(ctx, &mcp.CommandTransport{Command: command}, nil)
	if err != nil {
		return 0, fmt.Errorf("%w: start Fixer MCP bridge: %v", ErrPlannedWaveInitializeUnavailable, err)
	}
	defer session.Close()

	authResult, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name: "assume_role",
		Arguments: map[string]any{
			"role": "fixer",
			"cwd":  project.CWD,
		},
	})
	if err != nil {
		return 0, fmt.Errorf("%w: authenticate project Fixer: %v", ErrPlannedWaveInitializeUnavailable, err)
	}
	if authResult.IsError {
		return 0, fmt.Errorf("%w: authenticate project Fixer: %s", ErrPlannedWaveInitializeUnavailable, mcpToolFailureText(authResult))
	}

	result, err := session.CallTool(ctx, &mcp.CallToolParams{
		Name:      "initialize_planned_netrunner_wave",
		Arguments: map[string]any{"plan_id": planID},
	})
	if err != nil {
		return 0, fmt.Errorf("%w: %v", ErrPlannedWaveInitializeRejected, err)
	}
	if result.IsError {
		return 0, fmt.Errorf("%w: %s", ErrPlannedWaveInitializeRejected, mcpToolFailureText(result))
	}
	var output struct {
		WaveID int `json:"wave_id"`
	}
	if err := decodeMCPStructuredResult(result, &output); err != nil {
		return 0, fmt.Errorf("%w: decode governed Initialize result: %v", ErrPlannedWaveInitializeUnavailable, err)
	}
	if output.WaveID <= 0 {
		return 0, fmt.Errorf("%w: governed Initialize returned no wave_id", ErrPlannedWaveInitializeUnavailable)
	}
	return output.WaveID, nil
}

func environmentWithOverrides(base []string, overrides map[string]string) []string {
	resolved := make([]string, 0, len(base)+len(overrides))
	for _, entry := range base {
		key, _, found := strings.Cut(entry, "=")
		if found {
			if _, replaced := overrides[key]; replaced {
				continue
			}
		}
		resolved = append(resolved, entry)
	}
	for key, value := range overrides {
		if value != "" {
			resolved = append(resolved, key+"="+value)
		}
	}
	return resolved
}

func decodeMCPStructuredResult(result *mcp.CallToolResult, target any) error {
	if result == nil {
		return fmt.Errorf("empty MCP result")
	}
	if result.StructuredContent != nil {
		payload, err := json.Marshal(result.StructuredContent)
		if err != nil {
			return err
		}
		return json.Unmarshal(payload, target)
	}
	for _, content := range result.Content {
		if text, ok := content.(*mcp.TextContent); ok && strings.TrimSpace(text.Text) != "" {
			return json.Unmarshal([]byte(text.Text), target)
		}
	}
	return fmt.Errorf("MCP result has no structured content")
}

func mcpToolFailureText(result *mcp.CallToolResult) string {
	if result == nil {
		return "empty MCP result"
	}
	for _, content := range result.Content {
		if text, ok := content.(*mcp.TextContent); ok && strings.TrimSpace(text.Text) != "" {
			return strings.TrimSpace(text.Text)
		}
	}
	return "tool returned an unspecified error"
}

func (r *Repository) InitializeMissionControlPlannedWave(ctx context.Context, projectID int, planID int) (InitializeMissionControlPlannedWaveResponse, error) {
	project, err := r.requireProject(ctx, projectID)
	if err != nil {
		return InitializeMissionControlPlannedWaveResponse{}, err
	}
	var found int
	if err := r.db.QueryRowContext(ctx, "SELECT id FROM planned_wave WHERE id = ? AND project_id = ?", planID, projectID).Scan(&found); err != nil {
		return InitializeMissionControlPlannedWaveResponse{}, err
	}
	if !r.plannedWaveInitializeRouteAvailable(project) {
		return InitializeMissionControlPlannedWaveResponse{}, ErrPlannedWaveInitializeUnavailable
	}
	waveID, err := r.plannedWaveInitializer(ctx, project, planID)
	if err != nil {
		return InitializeMissionControlPlannedWaveResponse{}, err
	}
	snapshot, err := r.ProjectMissionControlWaves(ctx, projectID)
	if err != nil {
		return InitializeMissionControlPlannedWaveResponse{}, err
	}
	response := InitializeMissionControlPlannedWaveResponse{
		Status: "success", ProjectID: projectID, PlanID: planID, WaveID: waveID,
	}
	for _, plan := range snapshot.PlannedWaves {
		if plan.PlanID == planID {
			response.PlannedWave = plan
			break
		}
	}
	for _, wave := range snapshot.Waves {
		if wave.WaveID == waveID {
			response.Wave = wave
			break
		}
	}
	if response.PlannedWave.PlanID == 0 || response.Wave.WaveID == 0 || response.PlannedWave.InitializedWaveID != waveID {
		return InitializeMissionControlPlannedWaveResponse{}, fmt.Errorf("%w: initialized read model is incomplete", ErrPlannedWaveInitializeUnavailable)
	}
	return response, nil
}

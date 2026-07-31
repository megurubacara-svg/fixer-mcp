package dashboardapi

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	defaultPreviewProvider = "dashboard_stub"
	defaultPreviewTTL      = time.Hour
)

var (
	ErrPreviewNotFound = errors.New("preview not found")
	ErrSandboxNotFound = errors.New("sandbox not found")
	ErrSandboxConflict = errors.New("sandbox conflict")
)

type previewRecord struct {
	ID               int
	OrderID          int
	WorktreePath     string
	BranchName       string
	SourceProjectCWD string
	BaseRevision     string
	SandboxStatus    string
	PreviewProvider  string
	PreviewToken     string
	PreviewURL       string
	PreviewExpiresAt string
}

type PreviewResponse struct {
	Status  string            `json:"status"`
	OrderID int               `json:"order_id"`
	Sandbox SandboxDescriptor `json:"sandbox"`
	Message string            `json:"message,omitempty"`
}

func ensureSandboxTable(ctx context.Context, db *sql.DB) error {
	_, err := db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS order_sandbox (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			order_id INTEGER NOT NULL,
			project_id INTEGER NOT NULL,
			session_id INTEGER NOT NULL,
			source_project_cwd TEXT NOT NULL DEFAULT '',
			worktree_path TEXT NOT NULL,
			branch_name TEXT NOT NULL DEFAULT '',
			base_revision TEXT NOT NULL DEFAULT '',
			sandbox_status TEXT NOT NULL,
			preview_provider TEXT NOT NULL,
			preview_token TEXT NOT NULL UNIQUE,
			preview_url TEXT NOT NULL,
			preview_expires_at TEXT NOT NULL,
			created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
		);
		CREATE INDEX IF NOT EXISTS order_sandbox_order_idx ON order_sandbox(order_id);
		CREATE INDEX IF NOT EXISTS order_sandbox_session_idx ON order_sandbox(session_id);
	`)
	return err
}

func runGit(ctx context.Context, cwd string, args ...string) (string, error) {
	commandArgs := append([]string{"-C", cwd}, args...)
	cmd := exec.CommandContext(ctx, "git", commandArgs...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message != "" {
			return "", fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, message)
		}
		return "", fmt.Errorf("git %s: %w", strings.Join(args, " "), err)
	}
	return strings.TrimSpace(string(output)), nil
}

func gitProjectRoot(ctx context.Context, path string) (string, error) {
	root, err := runGit(ctx, path, "rev-parse", "--show-toplevel")
	if err != nil {
		return "", err
	}
	return normalizeProjectCWD(root)
}

func orderSourceProjectCWD(ctx context.Context, repo *Repository, input AcceptOrderInput) (string, bool, error) {
	for _, candidate := range []string{input.SourceProjectCWD, input.SourceProjectRoot} {
		if strings.TrimSpace(candidate) == "" {
			continue
		}
		root, err := gitProjectRoot(ctx, candidate)
		if err != nil {
			return "", true, fmt.Errorf("source project is not a Git repository: %w", err)
		}
		return root, true, nil
	}

	// ProjectRoot and ProjectCWD were used by the first order API as a plain
	// project path. Treat them as a source only when they are Git repositories,
	// preserving the old non-Git projection behavior.
	for _, candidate := range []string{input.ProjectRoot, input.ProjectCWD} {
		if strings.TrimSpace(candidate) == "" {
			continue
		}
		if root, err := gitProjectRoot(ctx, candidate); err == nil {
			return root, true, nil
		}
	}
	if strings.TrimSpace(repo.currentProjectCWD) != "" {
		if root, err := gitProjectRoot(ctx, repo.currentProjectCWD); err == nil {
			return root, true, nil
		}
	}
	return "", false, nil
}

func orderProjectCWD(input AcceptOrderInput, sourceProjectCWD string) (string, error) {
	raw := strings.TrimSpace(input.ProjectCWD)
	if raw == "" && sourceProjectCWD == "" {
		raw = strings.TrimSpace(input.ProjectRoot)
	}
	if raw == "" {
		raw = strings.TrimSpace(input.CWD)
	}
	if raw == "" || (sourceProjectCWD != "" && samePath(raw, sourceProjectCWD)) {
		base := strings.TrimSpace(input.WorktreeRoot)
		if base == "" {
			base = filepath.Join(sourceProjectCWD, ".fixer-orders")
		}
		raw = filepath.Join(base, "order-"+strconv.Itoa(input.OrderID))
	}
	return normalizeOrderProjectCWD(raw)
}

func normalizeOrderProjectCWD(raw string) (string, error) {
	clean := filepath.Clean(strings.TrimSpace(raw))
	parent := filepath.Dir(clean)
	if resolvedParent, err := filepath.EvalSymlinks(parent); err == nil {
		clean = filepath.Join(resolvedParent, filepath.Base(clean))
	}
	return normalizeProjectCWD(clean)
}

func samePath(left, right string) bool {
	leftPath, leftErr := normalizeProjectCWD(left)
	rightPath, rightErr := normalizeProjectCWD(right)
	return leftErr == nil && rightErr == nil && leftPath == rightPath
}

func orderBranchName(input AcceptOrderInput) string {
	branch := strings.TrimSpace(input.BranchName)
	if branch == "" {
		return "orders/order-" + strconv.Itoa(input.OrderID)
	}
	branch = strings.Trim(branch, "/")
	branch = strings.Map(func(r rune) rune {
		switch {
		case r == ' ' || r == '\t' || r == '\n':
			return '-'
		case r == ':' || r == '~' || r == '^' || r == '?' || r == '*' || r == '[':
			return '-'
		default:
			return r
		}
	}, branch)
	if branch == "" || strings.HasPrefix(branch, "-") || strings.HasPrefix(branch, ".") {
		return "orders/order-" + strconv.Itoa(input.OrderID)
	}
	return branch
}

func previewTTL(input AcceptOrderInput) time.Duration {
	seconds := input.PreviewTTLSeconds
	if seconds <= 0 {
		seconds, _ = strconv.Atoi(strings.TrimSpace(os.Getenv("FIXER_PREVIEW_TTL_SECONDS")))
	}
	if seconds <= 0 {
		return defaultPreviewTTL
	}
	return time.Duration(seconds) * time.Second
}

func newPreviewDescriptor(input AcceptOrderInput) (string, PreviewDescriptor, error) {
	tokenBytes := make([]byte, 18)
	if _, err := rand.Read(tokenBytes); err != nil {
		return "", PreviewDescriptor{}, fmt.Errorf("create preview token: %w", err)
	}
	token := hex.EncodeToString(tokenBytes)
	provider := strings.TrimSpace(input.PreviewProvider)
	if provider == "" {
		provider = strings.TrimSpace(os.Getenv("FIXER_PREVIEW_PROVIDER"))
	}
	if provider == "" {
		provider = defaultPreviewProvider
	}
	expiresAt := time.Now().UTC().Add(previewTTL(input)).Format(time.RFC3339)
	baseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("FIXER_PREVIEW_BASE_URL")), "/")
	previewURL := "/api/previews/" + token
	if baseURL != "" {
		previewURL = baseURL + previewURL
	}
	return token, PreviewDescriptor{
		URL:       previewURL,
		Provider:  provider,
		Status:    "issued",
		ExpiresAt: expiresAt,
	}, nil
}

func provisionOrderSandbox(ctx context.Context, input AcceptOrderInput, sourceProjectCWD string, projectCWD string) (SandboxDescriptor, bool, error) {
	token, preview, err := newPreviewDescriptor(input)
	if err != nil {
		return SandboxDescriptor{}, false, err
	}
	descriptor := SandboxDescriptor{
		PreviewToken: token,
		Status:       "not_configured",
		WorktreePath: projectCWD,
		Preview:      preview,
	}
	if sourceProjectCWD == "" {
		return descriptor, false, nil
	}

	branchName := orderBranchName(input)
	if _, err := runGit(ctx, sourceProjectCWD, "check-ref-format", "--branch", branchName); err != nil {
		return SandboxDescriptor{}, false, fmt.Errorf("invalid sandbox branch %q: %w", branchName, err)
	}
	baseRevision, err := runGit(ctx, sourceProjectCWD, "rev-parse", "HEAD")
	if err != nil {
		return SandboxDescriptor{}, false, fmt.Errorf("resolve sandbox base revision: %w", err)
	}
	descriptor.Status = "ready"
	descriptor.SourceProjectCWD = sourceProjectCWD
	descriptor.BranchName = branchName
	descriptor.BaseRevision = baseRevision

	created := false
	if _, statErr := os.Stat(projectCWD); statErr == nil {
		worktrees, listErr := runGit(ctx, sourceProjectCWD, "worktree", "list", "--porcelain")
		if listErr != nil || !containsGitWorktree(worktrees, projectCWD) {
			if listErr != nil {
				return SandboxDescriptor{}, false, fmt.Errorf("inspect existing sandbox worktree: %w", listErr)
			}
			return SandboxDescriptor{}, false, fmt.Errorf("%w: sandbox path already exists and is not a Git worktree: %s", ErrSandboxConflict, projectCWD)
		}
		if actualBranch := gitWorktreeBranch(worktrees, projectCWD); actualBranch != branchName {
			return SandboxDescriptor{}, false, fmt.Errorf("%w: sandbox path is already attached to branch %q, requested %q", ErrSandboxConflict, actualBranch, branchName)
		}
	} else if os.IsNotExist(statErr) {
		if err := os.MkdirAll(filepath.Dir(projectCWD), 0o755); err != nil {
			return SandboxDescriptor{}, false, fmt.Errorf("create sandbox parent: %w", err)
		}
		if _, err := runGit(ctx, sourceProjectCWD, "worktree", "add", "-b", branchName, projectCWD, baseRevision); err != nil {
			return SandboxDescriptor{}, false, fmt.Errorf("create sandbox worktree: %w", err)
		}
		created = true
	} else {
		return SandboxDescriptor{}, false, fmt.Errorf("inspect sandbox path: %w", statErr)
	}

	descriptor.Preview.Status = "issued"
	descriptor.WorktreeExists = true
	descriptor.BranchExists = true
	return descriptor, created, nil
}

func containsGitWorktree(worktrees string, target string) bool {
	return gitWorktreeBranch(worktrees, target) != "" || containsDetachedGitWorktree(worktrees, target)
}

func containsDetachedGitWorktree(worktrees string, target string) bool {
	for _, line := range strings.Split(worktrees, "\n") {
		if strings.HasPrefix(line, "worktree ") && samePath(strings.TrimPrefix(line, "worktree "), target) {
			return true
		}
	}
	return false
}

func gitWorktreeBranch(worktrees string, target string) string {
	found := false
	for _, line := range strings.Split(worktrees, "\n") {
		if strings.HasPrefix(line, "worktree ") {
			found = samePath(strings.TrimPrefix(line, "worktree "), target)
			continue
		}
		if found && strings.HasPrefix(line, "branch ") {
			return strings.TrimPrefix(line, "branch refs/heads/")
		}
		if found && strings.TrimSpace(line) == "" {
			return ""
		}
	}
	return ""
}

func (r *Repository) insertOrderSandbox(ctx context.Context, tx *sql.Tx, input AcceptOrderInput, projectID int, sessionID int, descriptor SandboxDescriptor) (SandboxDescriptor, error) {
	if descriptor.PreviewToken == "" {
		return SandboxDescriptor{}, errors.New("sandbox preview token is required")
	}
	preview := descriptor.Preview
	result, err := tx.ExecContext(ctx, `
		INSERT INTO order_sandbox (
			order_id, project_id, session_id, source_project_cwd, worktree_path,
			branch_name, base_revision, sandbox_status, preview_provider,
			preview_token, preview_url, preview_expires_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		input.OrderID,
		projectID,
		sessionID,
		descriptor.SourceProjectCWD,
		descriptor.WorktreePath,
		descriptor.BranchName,
		descriptor.BaseRevision,
		descriptor.Status,
		preview.Provider,
		descriptor.PreviewToken,
		preview.URL,
		preview.ExpiresAt,
	)
	if err != nil {
		return SandboxDescriptor{}, err
	}
	sandboxID, err := result.LastInsertId()
	if err != nil {
		return SandboxDescriptor{}, err
	}
	descriptor.ID = int(sandboxID)
	return descriptor, nil
}

func (r *Repository) previewByToken(ctx context.Context, token string) (PreviewResponse, error) {
	if err := ensureSandboxTable(ctx, r.dbWrite); err != nil {
		return PreviewResponse{}, err
	}
	var record previewRecord
	err := r.db.QueryRowContext(ctx, `
		SELECT id, order_id, worktree_path, branch_name, source_project_cwd,
		       base_revision, sandbox_status, preview_provider, preview_token,
		       preview_url, preview_expires_at
		FROM order_sandbox WHERE preview_token = ?`, token).Scan(
		&record.ID,
		&record.OrderID,
		&record.WorktreePath,
		&record.BranchName,
		&record.SourceProjectCWD,
		&record.BaseRevision,
		&record.SandboxStatus,
		&record.PreviewProvider,
		&record.PreviewToken,
		&record.PreviewURL,
		&record.PreviewExpiresAt,
	)
	if err == sql.ErrNoRows {
		return PreviewResponse{}, ErrPreviewNotFound
	}
	if err != nil {
		return PreviewResponse{}, err
	}
	expiresAt, err := time.Parse(time.RFC3339, record.PreviewExpiresAt)
	if err != nil {
		return PreviewResponse{}, fmt.Errorf("parse preview expiry: %w", err)
	}
	status := "ready"
	message := "sandbox preview metadata"
	if record.SandboxStatus == "removed" {
		status = "removed"
		message = "sandbox has been torn down"
	}
	if time.Now().UTC().After(expiresAt) {
		status = "expired"
		message = "preview URL has expired"
	}
	return PreviewResponse{
		Status:  status,
		OrderID: record.OrderID,
		Message: message,
		Sandbox: SandboxDescriptor{
			ID:               record.ID,
			Status:           record.SandboxStatus,
			SourceProjectCWD: record.SourceProjectCWD,
			WorktreePath:     record.WorktreePath,
			BranchName:       record.BranchName,
			BaseRevision:     record.BaseRevision,
			WorktreeExists:   record.SandboxStatus != "removed",
			BranchExists:     record.SandboxStatus != "removed",
			Preview: PreviewDescriptor{
				URL:       record.PreviewURL,
				Provider:  record.PreviewProvider,
				Status:    status,
				ExpiresAt: record.PreviewExpiresAt,
			},
		},
	}, nil
}

type sandboxRecord struct {
	ID               int
	OrderID          int
	ProjectID        int
	SessionID        int
	SourceProjectCWD string
	WorktreePath     string
	BranchName       string
	BaseRevision     string
	SandboxStatus    string
	PreviewProvider  string
	PreviewToken     string
	PreviewURL       string
	PreviewExpiresAt string
}

func (r *Repository) loadOrderSandbox(ctx context.Context, orderID int) (sandboxRecord, error) {
	if orderID <= 0 {
		return sandboxRecord{}, fmt.Errorf("order_id is required")
	}
	if err := ensureSandboxTable(ctx, r.dbWrite); err != nil {
		return sandboxRecord{}, err
	}
	var record sandboxRecord
	err := r.db.QueryRowContext(ctx, `
		SELECT id, order_id, project_id, session_id, source_project_cwd,
		       worktree_path, branch_name, base_revision, sandbox_status,
		       preview_provider, preview_token, preview_url, preview_expires_at
		FROM order_sandbox
		WHERE order_id = ?
		ORDER BY id DESC
		LIMIT 1`, orderID).Scan(
		&record.ID,
		&record.OrderID,
		&record.ProjectID,
		&record.SessionID,
		&record.SourceProjectCWD,
		&record.WorktreePath,
		&record.BranchName,
		&record.BaseRevision,
		&record.SandboxStatus,
		&record.PreviewProvider,
		&record.PreviewToken,
		&record.PreviewURL,
		&record.PreviewExpiresAt,
	)
	if err == sql.ErrNoRows {
		return sandboxRecord{}, ErrSandboxNotFound
	}
	if err != nil {
		return sandboxRecord{}, err
	}
	return record, nil
}

func sandboxDescriptorFromRecord(record sandboxRecord) (SandboxDescriptor, error) {
	if strings.TrimSpace(record.PreviewExpiresAt) == "" {
		return SandboxDescriptor{}, errors.New("sandbox preview expiry is missing")
	}
	if _, err := time.Parse(time.RFC3339, record.PreviewExpiresAt); err != nil {
		return SandboxDescriptor{}, fmt.Errorf("parse sandbox preview expiry: %w", err)
	}
	return SandboxDescriptor{
		PreviewToken:     record.PreviewToken,
		ID:               record.ID,
		Status:           record.SandboxStatus,
		SourceProjectCWD: record.SourceProjectCWD,
		WorktreePath:     record.WorktreePath,
		BranchName:       record.BranchName,
		BaseRevision:     record.BaseRevision,
		Preview: PreviewDescriptor{
			URL:       record.PreviewURL,
			Provider:  record.PreviewProvider,
			Status:    "issued",
			ExpiresAt: record.PreviewExpiresAt,
		},
	}, nil
}

func gitBranchExists(ctx context.Context, sourceProjectCWD string, branchName string) bool {
	if strings.TrimSpace(sourceProjectCWD) == "" || strings.TrimSpace(branchName) == "" {
		return false
	}
	_, err := runGit(ctx, sourceProjectCWD, "show-ref", "--verify", "--quiet", "refs/heads/"+branchName)
	return err == nil
}

func inspectSandboxRecord(ctx context.Context, record sandboxRecord) (SandboxDescriptor, error) {
	descriptor, err := sandboxDescriptorFromRecord(record)
	if err != nil {
		return SandboxDescriptor{}, err
	}
	if record.SandboxStatus == "removed" {
		descriptor.Preview.Status = "revoked"
		return descriptor, nil
	}
	if strings.TrimSpace(record.SourceProjectCWD) == "" {
		descriptor.Status = "not_configured"
		descriptor.Preview.Status = "issued"
		return descriptor, nil
	}
	worktrees, err := runGit(ctx, record.SourceProjectCWD, "worktree", "list", "--porcelain")
	if err != nil {
		return SandboxDescriptor{}, fmt.Errorf("inspect sandbox worktrees: %w", err)
	}
	_, statErr := os.Stat(record.WorktreePath)
	descriptor.WorktreeExists = containsGitWorktree(worktrees, record.WorktreePath) && statErr == nil
	descriptor.BranchExists = gitBranchExists(ctx, record.SourceProjectCWD, record.BranchName)
	worktreeBranch := gitWorktreeBranch(worktrees, record.WorktreePath)
	if descriptor.WorktreeExists && descriptor.BranchExists && worktreeBranch == record.BranchName {
		descriptor.Status = "ready"
		descriptor.Preview.Status = "issued"
		return descriptor, nil
	}
	descriptor.Status = "missing"
	descriptor.Preview.Status = "unavailable"
	return descriptor, nil
}

// CreateOrderSandbox provisions an isolated Git worktree and records the
// resulting branch and preview token. It is idempotent for an active order:
// retrying a create request returns the recorded sandbox instead of trying to
// create a second worktree at the same path.
func (r *Repository) CreateOrderSandbox(ctx context.Context, input AcceptOrderInput) (SandboxActionResponse, error) {
	if input.OrderID <= 0 {
		return SandboxActionResponse{}, fmt.Errorf("order_id is required")
	}
	if existing, err := r.loadOrderSandbox(ctx, input.OrderID); err == nil && existing.SandboxStatus != "removed" {
		descriptor, inspectErr := inspectSandboxRecord(ctx, existing)
		if inspectErr != nil {
			return SandboxActionResponse{}, inspectErr
		}
		if descriptor.Status == "ready" || descriptor.Status == "not_configured" {
			return SandboxActionResponse{
				Status:  "success",
				OrderID: input.OrderID,
				Sandbox: descriptor,
				Message: "sandbox already exists",
			}, nil
		}
	} else if err != nil && !errors.Is(err, ErrSandboxNotFound) {
		return SandboxActionResponse{}, err
	}

	sourceProjectCWD, _, err := orderSourceProjectCWD(ctx, r, input)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	projectCWD, err := orderProjectCWD(input, sourceProjectCWD)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	descriptor, worktreeCreated, err := provisionOrderSandbox(ctx, input, sourceProjectCWD, projectCWD)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	defer func() {
		if worktreeCreated {
			_, _ = runGit(context.Background(), sourceProjectCWD, "worktree", "remove", "--force", projectCWD)
		}
	}()

	tx, err := r.dbWrite.BeginTx(ctx, nil)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	defer func() { _ = tx.Rollback() }()
	descriptor, err = r.insertOrderSandbox(ctx, tx, input, input.ProjectID, input.SessionID, descriptor)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	if err := tx.Commit(); err != nil {
		return SandboxActionResponse{}, err
	}
	worktreeCreated = false
	return SandboxActionResponse{
		Status:  "success",
		OrderID: input.OrderID,
		Sandbox: descriptor,
	}, nil
}

func (r *Repository) InspectOrderSandbox(ctx context.Context, orderID int) (SandboxActionResponse, error) {
	record, err := r.loadOrderSandbox(ctx, orderID)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	descriptor, err := inspectSandboxRecord(ctx, record)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	return SandboxActionResponse{
		Status:  "success",
		OrderID: orderID,
		Sandbox: descriptor,
	}, nil
}

// PreviewOrder returns the current preview metadata for the latest sandbox
// recorded for an order. Token-based preview lookup remains available for
// clients that only have the public preview URL.
func (r *Repository) PreviewOrder(ctx context.Context, orderID int) (PreviewResponse, error) {
	record, err := r.loadOrderSandbox(ctx, orderID)
	if err != nil {
		return PreviewResponse{}, err
	}
	return r.previewByToken(ctx, record.PreviewToken)
}

// TeardownOrderSandbox removes only the worktree and branch recorded for the
// order. A non-force teardown refuses dirty worktrees; force is required when
// callers explicitly want Git to discard uncommitted changes.
func (r *Repository) TeardownOrderSandbox(ctx context.Context, orderID int, input TeardownSandboxInput) (SandboxActionResponse, error) {
	record, err := r.loadOrderSandbox(ctx, orderID)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	descriptor, err := inspectSandboxRecord(ctx, record)
	if err != nil {
		return SandboxActionResponse{}, err
	}
	if record.SandboxStatus == "removed" {
		return SandboxActionResponse{
			Status:  "success",
			OrderID: orderID,
			Sandbox: descriptor,
			Message: "sandbox already torn down",
		}, nil
	}

	if strings.TrimSpace(record.SourceProjectCWD) != "" {
		if descriptor.WorktreeExists {
			args := []string{"worktree", "remove"}
			if input.Force {
				args = append(args, "--force")
			}
			args = append(args, record.WorktreePath)
			if _, err := runGit(ctx, record.SourceProjectCWD, args...); err != nil {
				return SandboxActionResponse{}, fmt.Errorf("%w: teardown sandbox worktree: %v", ErrSandboxConflict, err)
			}
		} else if _, statErr := os.Stat(record.WorktreePath); statErr == nil {
			return SandboxActionResponse{}, fmt.Errorf("%w: sandbox path exists but is not a recorded Git worktree: %s", ErrSandboxConflict, record.WorktreePath)
		}
		if gitBranchExists(ctx, record.SourceProjectCWD, record.BranchName) {
			branchArgs := []string{"branch", "-d", record.BranchName}
			if input.Force {
				branchArgs[1] = "-D"
			}
			if _, err := runGit(ctx, record.SourceProjectCWD, branchArgs...); err != nil {
				return SandboxActionResponse{}, fmt.Errorf("%w: teardown sandbox branch: %v", ErrSandboxConflict, err)
			}
		}
	}

	if _, err := r.dbWrite.ExecContext(ctx,
		`UPDATE order_sandbox SET sandbox_status = 'removed' WHERE order_id = ?`, orderID); err != nil {
		return SandboxActionResponse{}, err
	}
	descriptor.Status = "removed"
	descriptor.WorktreeExists = false
	descriptor.BranchExists = false
	descriptor.Preview.Status = "revoked"
	return SandboxActionResponse{
		Status:  "success",
		OrderID: orderID,
		Sandbox: descriptor,
		Message: "sandbox torn down",
	}, nil
}

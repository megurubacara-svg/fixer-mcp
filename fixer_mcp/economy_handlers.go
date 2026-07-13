package main

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

const (
	defaultProjectBalanceCurrency = "usd"
	defaultBalanceLedgerLimit     = 50
	maxBalanceLedgerLimit         = 200
)

type ProjectSpendAuthorityRecord struct {
	Enabled        bool   `json:"enabled"`
	AllowanceUnits int64  `json:"allowance_units"`
	UpdatedAt      string `json:"updated_at,omitempty"`
}

type ProjectBalanceRecord struct {
	ProjectId    int                         `json:"project_id"`
	BalanceUnits int64                       `json:"balance_units"`
	Currency     string                      `json:"currency"`
	Authority    ProjectSpendAuthorityRecord `json:"authority"`
	UpdatedAt    string                      `json:"updated_at,omitempty"`
}

type BalanceLedgerRecord struct {
	Id         int    `json:"id"`
	ProjectId  int    `json:"project_id"`
	DeltaUnits int64  `json:"delta_units"`
	Kind       string `json:"kind"`
	Reason     string `json:"reason"`
	ActorRole  string `json:"actor_role"`
	CreatedAt  string `json:"created_at"`
}

type GetProjectBalanceInput struct {
	ProjectId int `json:"project_id,omitempty" jsonschema:"Optional project ID when called by overseer; fixer uses the bound project."`
}

type GetProjectBalanceOutput struct {
	BalanceUnits int64                       `json:"balance_units"`
	Currency     string                      `json:"currency"`
	Authority    ProjectSpendAuthorityRecord `json:"authority"`
	ProjectId    int                         `json:"project_id"`
}

type CreditProjectBalanceInput struct {
	ProjectId   int    `json:"project_id" jsonschema:"Project ID to credit. Overseer only."`
	AmountUnits int64  `json:"amount_units" jsonschema:"Positive integer minor units to add to the project balance."`
	Reason      string `json:"reason" jsonschema:"Audit reason for the credit."`
}

type CreditProjectBalanceOutput struct {
	Status  string               `json:"status"`
	Balance ProjectBalanceRecord `json:"balance"`
	Ledger  BalanceLedgerRecord  `json:"ledger"`
}

type SetFixerSpendAuthorityInput struct {
	ProjectId      int    `json:"project_id" jsonschema:"Project ID whose Fixer spend authority is being set. Overseer only."`
	Enabled        bool   `json:"enabled" jsonschema:"Whether Fixer spend authority is enabled."`
	AllowanceUnits int64  `json:"allowance_units" jsonschema:"Non-negative remaining allowance the Fixer may spend without another grant."`
	Reason         string `json:"reason" jsonschema:"Audit reason for the authority update."`
}

type SetFixerSpendAuthorityOutput struct {
	Status    string                      `json:"status"`
	Authority ProjectSpendAuthorityRecord `json:"authority"`
	Ledger    BalanceLedgerRecord         `json:"ledger"`
	ProjectId int                         `json:"project_id"`
}

type RecordFixerSpendInput struct {
	AmountUnits int64  `json:"amount_units" jsonschema:"Positive integer minor units to spend from the current project."`
	Reason      string `json:"reason" jsonschema:"Audit reason for the spend."`
}

type RecordFixerSpendOutput struct {
	Status  string               `json:"status"`
	Balance ProjectBalanceRecord `json:"balance"`
	Ledger  BalanceLedgerRecord  `json:"ledger"`
}

type GetBalanceLedgerInput struct {
	ProjectId int `json:"project_id,omitempty" jsonschema:"Optional project ID when called by overseer; fixer uses the bound project."`
	Limit     int `json:"limit,omitempty" jsonschema:"Optional max recent ledger rows to return. Defaults to 50, max 200."`
}

type GetBalanceLedgerOutput struct {
	ProjectId int                   `json:"project_id"`
	Ledger    []BalanceLedgerRecord `json:"ledger"`
}

func resolveEconomyProjectID(projectID int) (int, error) {
	switch authorizedRole {
	case "fixer":
		if authorizedProjectId <= 0 {
			return 0, fmt.Errorf("project context is unavailable")
		}
		if projectID > 0 && projectID != authorizedProjectId {
			return 0, fmt.Errorf("access denied: project_id does not match current project")
		}
		return authorizedProjectId, nil
	case "overseer":
		if projectID <= 0 {
			return 0, fmt.Errorf("project_id is required for overseer")
		}
		exists, err := projectExists(projectID)
		if err != nil {
			return 0, err
		}
		if !exists {
			return 0, sql.ErrNoRows
		}
		return projectID, nil
	default:
		return 0, fmt.Errorf("access denied: requires fixer or overseer role")
	}
}

func normalizeEconomyReason(raw string) (string, error) {
	reason := strings.Join(strings.Fields(strings.TrimSpace(raw)), " ")
	if reason == "" {
		return "", fmt.Errorf("reason is required")
	}
	return reason, nil
}

func normalizePositiveUnits(amount int64, field string) error {
	if amount <= 0 {
		return fmt.Errorf("%s must be positive", field)
	}
	return nil
}

func normalizeBalanceLedgerLimit(limit int) int {
	if limit <= 0 {
		return defaultBalanceLedgerLimit
	}
	if limit > maxBalanceLedgerLimit {
		return maxBalanceLedgerLimit
	}
	return limit
}

func fetchProjectBalanceRecord(projectID int) (ProjectBalanceRecord, error) {
	record := ProjectBalanceRecord{
		ProjectId: projectID,
		Currency:  defaultProjectBalanceCurrency,
		Authority: ProjectSpendAuthorityRecord{
			Enabled:        false,
			AllowanceUnits: 0,
		},
	}

	err := db.QueryRow(
		`SELECT balance_units,
		        COALESCE(NULLIF(TRIM(currency), ''), ?),
		        updated_at
		 FROM project_balance
		 WHERE project_id = ?`,
		defaultProjectBalanceCurrency,
		projectID,
	).Scan(&record.BalanceUnits, &record.Currency, &record.UpdatedAt)
	if err != nil && err != sql.ErrNoRows {
		return ProjectBalanceRecord{}, err
	}

	var enabledInt int
	err = db.QueryRow(
		`SELECT enabled,
		        allowance_units,
		        updated_at
		 FROM fixer_spend_authority
		 WHERE project_id = ?`,
		projectID,
	).Scan(&enabledInt, &record.Authority.AllowanceUnits, &record.Authority.UpdatedAt)
	if err != nil && err != sql.ErrNoRows {
		return ProjectBalanceRecord{}, err
	}
	record.Authority.Enabled = enabledInt != 0

	return record, nil
}

func fetchBalanceLedgerByID(ledgerID int64) (BalanceLedgerRecord, error) {
	var record BalanceLedgerRecord
	err := db.QueryRow(
		`SELECT id,
		        project_id,
		        delta_units,
		        kind,
		        reason,
		        actor_role,
		        created_at
		 FROM balance_ledger
		 WHERE id = ?`,
		ledgerID,
	).Scan(
		&record.Id,
		&record.ProjectId,
		&record.DeltaUnits,
		&record.Kind,
		&record.Reason,
		&record.ActorRole,
		&record.CreatedAt,
	)
	return record, err
}

func insertBalanceLedger(tx *sql.Tx, projectID int, deltaUnits int64, kind string, reason string, actorRole string) (int64, error) {
	res, err := tx.Exec(
		`INSERT INTO balance_ledger (project_id, delta_units, kind, reason, actor_role)
		 VALUES (?, ?, ?, ?, ?)`,
		projectID,
		deltaUnits,
		kind,
		reason,
		actorRole,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func GetProjectBalance(ctx context.Context, req *mcp.CallToolRequest, input GetProjectBalanceInput) (*mcp.CallToolResult, GetProjectBalanceOutput, error) {
	if authorizedRole != "fixer" && authorizedRole != "overseer" {
		return &mcp.CallToolResult{IsError: true}, GetProjectBalanceOutput{}, fmt.Errorf("access denied: requires fixer or overseer role")
	}

	projectID, err := resolveEconomyProjectID(input.ProjectId)
	if err == sql.ErrNoRows {
		return &mcp.CallToolResult{IsError: true}, GetProjectBalanceOutput{}, fmt.Errorf("project not found")
	}
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, GetProjectBalanceOutput{}, err
	}

	record, err := fetchProjectBalanceRecord(projectID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, GetProjectBalanceOutput{}, fmt.Errorf("DB query error: %v", err)
	}

	return nil, GetProjectBalanceOutput{
		ProjectId:    projectID,
		BalanceUnits: record.BalanceUnits,
		Currency:     record.Currency,
		Authority:    record.Authority,
	}, nil
}

func CreditProjectBalance(ctx context.Context, req *mcp.CallToolRequest, input CreditProjectBalanceInput) (*mcp.CallToolResult, CreditProjectBalanceOutput, error) {
	if authorizedRole != "overseer" {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("access denied: requires overseer role")
	}
	if err := normalizePositiveUnits(input.AmountUnits, "amount_units"); err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, err
	}
	reason, err := normalizeEconomyReason(input.Reason)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, err
	}
	projectID, err := resolveEconomyProjectID(input.ProjectId)
	if err == sql.ErrNoRows {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("project not found")
	}
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, err
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("DB transaction error: %v", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	if _, err := tx.Exec(
		`INSERT INTO project_balance (project_id, balance_units, currency, updated_at)
		 VALUES (?, ?, ?, CURRENT_TIMESTAMP)
		 ON CONFLICT(project_id) DO UPDATE SET
		     balance_units = balance_units + excluded.balance_units,
		     currency = COALESCE(NULLIF(TRIM(project_balance.currency), ''), excluded.currency),
		     updated_at = CURRENT_TIMESTAMP`,
		projectID,
		input.AmountUnits,
		defaultProjectBalanceCurrency,
	); err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("DB upsert error: %v", err)
	}

	ledgerID, err := insertBalanceLedger(tx, projectID, input.AmountUnits, "credit", reason, authorizedRole)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("DB ledger insert error: %v", err)
	}

	if err := tx.Commit(); err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("DB commit error: %v", err)
	}
	committed = true

	balance, err := fetchProjectBalanceRecord(projectID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("DB query error: %v", err)
	}
	ledger, err := fetchBalanceLedgerByID(ledgerID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, CreditProjectBalanceOutput{}, fmt.Errorf("DB ledger query error: %v", err)
	}

	return nil, CreditProjectBalanceOutput{Status: "success", Balance: balance, Ledger: ledger}, nil
}

func SetFixerSpendAuthority(ctx context.Context, req *mcp.CallToolRequest, input SetFixerSpendAuthorityInput) (*mcp.CallToolResult, SetFixerSpendAuthorityOutput, error) {
	if authorizedRole != "overseer" {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("access denied: requires overseer role")
	}
	if input.AllowanceUnits < 0 {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("allowance_units must be non-negative")
	}
	reason, err := normalizeEconomyReason(input.Reason)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, err
	}
	projectID, err := resolveEconomyProjectID(input.ProjectId)
	if err == sql.ErrNoRows {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("project not found")
	}
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, err
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB transaction error: %v", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	var previousAllowance int64
	if err := tx.QueryRow("SELECT allowance_units FROM fixer_spend_authority WHERE project_id = ?", projectID).Scan(&previousAllowance); err != nil && err != sql.ErrNoRows {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB query error: %v", err)
	}

	enabledInt := 0
	if input.Enabled {
		enabledInt = 1
	}
	if _, err := tx.Exec(
		`INSERT INTO fixer_spend_authority (project_id, enabled, allowance_units, updated_at)
		 VALUES (?, ?, ?, CURRENT_TIMESTAMP)
		 ON CONFLICT(project_id) DO UPDATE SET
		     enabled = excluded.enabled,
		     allowance_units = excluded.allowance_units,
		     updated_at = CURRENT_TIMESTAMP`,
		projectID,
		enabledInt,
		input.AllowanceUnits,
	); err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB upsert error: %v", err)
	}

	ledgerID, err := insertBalanceLedger(tx, projectID, input.AllowanceUnits-previousAllowance, "authority_grant", reason, authorizedRole)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB ledger insert error: %v", err)
	}

	if err := tx.Commit(); err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB commit error: %v", err)
	}
	committed = true

	balance, err := fetchProjectBalanceRecord(projectID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB query error: %v", err)
	}
	ledger, err := fetchBalanceLedgerByID(ledgerID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SetFixerSpendAuthorityOutput{}, fmt.Errorf("DB ledger query error: %v", err)
	}

	return nil, SetFixerSpendAuthorityOutput{
		Status:    "success",
		ProjectId: projectID,
		Authority: balance.Authority,
		Ledger:    ledger,
	}, nil
}

func RecordFixerSpend(ctx context.Context, req *mcp.CallToolRequest, input RecordFixerSpendInput) (*mcp.CallToolResult, RecordFixerSpendOutput, error) {
	if authorizedRole != "fixer" {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("access denied: requires fixer role")
	}
	if authorizedProjectId <= 0 {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("project context is unavailable")
	}
	if err := normalizePositiveUnits(input.AmountUnits, "amount_units"); err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, err
	}
	reason, err := normalizeEconomyReason(input.Reason)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, err
	}
	projectID := authorizedProjectId

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB transaction error: %v", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	var balanceUnits int64
	if err := tx.QueryRow("SELECT balance_units FROM project_balance WHERE project_id = ?", projectID).Scan(&balanceUnits); err != nil {
		if err != sql.ErrNoRows {
			return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB query error: %v", err)
		}
		balanceUnits = 0
	}

	var enabledInt int
	var allowanceUnits int64
	if err := tx.QueryRow("SELECT enabled, allowance_units FROM fixer_spend_authority WHERE project_id = ?", projectID).Scan(&enabledInt, &allowanceUnits); err != nil {
		if err != sql.ErrNoRows {
			return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB query error: %v", err)
		}
		enabledInt = 0
		allowanceUnits = 0
	}

	if enabledInt == 0 {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("spend authority is disabled")
	}
	if input.AmountUnits > allowanceUnits {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("spend amount exceeds remaining fixer allowance")
	}
	if input.AmountUnits > balanceUnits {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("spend amount exceeds project balance")
	}

	if _, err := tx.Exec(
		`UPDATE project_balance
		 SET balance_units = balance_units - ?,
		     updated_at = CURRENT_TIMESTAMP
		 WHERE project_id = ?`,
		input.AmountUnits,
		projectID,
	); err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB balance update error: %v", err)
	}
	if _, err := tx.Exec(
		`UPDATE fixer_spend_authority
		 SET allowance_units = allowance_units - ?,
		     updated_at = CURRENT_TIMESTAMP
		 WHERE project_id = ?`,
		input.AmountUnits,
		projectID,
	); err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB authority update error: %v", err)
	}

	ledgerID, err := insertBalanceLedger(tx, projectID, -input.AmountUnits, "spend", reason, authorizedRole)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB ledger insert error: %v", err)
	}

	if err := tx.Commit(); err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB commit error: %v", err)
	}
	committed = true

	balance, err := fetchProjectBalanceRecord(projectID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB query error: %v", err)
	}
	ledger, err := fetchBalanceLedgerByID(ledgerID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, RecordFixerSpendOutput{}, fmt.Errorf("DB ledger query error: %v", err)
	}

	return nil, RecordFixerSpendOutput{Status: "success", Balance: balance, Ledger: ledger}, nil
}

func GetBalanceLedger(ctx context.Context, req *mcp.CallToolRequest, input GetBalanceLedgerInput) (*mcp.CallToolResult, GetBalanceLedgerOutput, error) {
	if authorizedRole != "fixer" && authorizedRole != "overseer" {
		return &mcp.CallToolResult{IsError: true}, GetBalanceLedgerOutput{}, fmt.Errorf("access denied: requires fixer or overseer role")
	}

	projectID, err := resolveEconomyProjectID(input.ProjectId)
	if err == sql.ErrNoRows {
		return &mcp.CallToolResult{IsError: true}, GetBalanceLedgerOutput{}, fmt.Errorf("project not found")
	}
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, GetBalanceLedgerOutput{}, err
	}

	rows, err := db.Query(
		`SELECT id,
		        project_id,
		        delta_units,
		        kind,
		        reason,
		        actor_role,
		        created_at
		 FROM balance_ledger
		 WHERE project_id = ?
		 ORDER BY id DESC
		 LIMIT ?`,
		projectID,
		normalizeBalanceLedgerLimit(input.Limit),
	)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, GetBalanceLedgerOutput{}, fmt.Errorf("DB query error: %v", err)
	}
	defer rows.Close()

	ledger := []BalanceLedgerRecord{}
	for rows.Next() {
		var record BalanceLedgerRecord
		if err := rows.Scan(
			&record.Id,
			&record.ProjectId,
			&record.DeltaUnits,
			&record.Kind,
			&record.Reason,
			&record.ActorRole,
			&record.CreatedAt,
		); err != nil {
			return &mcp.CallToolResult{IsError: true}, GetBalanceLedgerOutput{}, fmt.Errorf("DB scan error: %v", err)
		}
		ledger = append(ledger, record)
	}
	if err := rows.Err(); err != nil {
		return &mcp.CallToolResult{IsError: true}, GetBalanceLedgerOutput{}, fmt.Errorf("DB rows error: %v", err)
	}

	return nil, GetBalanceLedgerOutput{ProjectId: projectID, Ledger: ledger}, nil
}

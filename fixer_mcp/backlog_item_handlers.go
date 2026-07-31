package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

// BacklogItem is a durable idea or piece of work that has not necessarily
// become an executable session yet.
type BacklogItem struct {
	Id          int    `json:"id"`
	ProjectId   int    `json:"project_id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Status      string `json:"status"`
	Priority    string `json:"priority"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

type AddBacklogItemInput struct {
	ProjectId   int    `json:"project_id,omitempty" jsonschema:"Optional project ID when called by overseer; fixer uses the bound project."`
	Title       string `json:"title" jsonschema:"Short title for the backlog item."`
	Description string `json:"description,omitempty" jsonschema:"Optional longer description of the backlog item."`
	Status      string `json:"status,omitempty" jsonschema:"Optional item status. Defaults to open."`
	Priority    string `json:"priority,omitempty" jsonschema:"Optional priority label."`
}

type AddBacklogItemOutput struct {
	Id     int         `json:"id"`
	Status string      `json:"status"`
	Item   BacklogItem `json:"item"`
}

type GetBacklogItemsInput struct {
	ProjectId int    `json:"project_id,omitempty" jsonschema:"Optional project ID when called by overseer; fixer uses the bound project."`
	Status    string `json:"status,omitempty" jsonschema:"Optional status filter."`
	Priority  string `json:"priority,omitempty" jsonschema:"Optional priority filter."`
}

type GetBacklogItemsOutput struct {
	ProjectId int           `json:"project_id"`
	Items     []BacklogItem `json:"items"`
}

type UpdateBacklogItemInput struct {
	ProjectId   int    `json:"project_id,omitempty" jsonschema:"Optional project ID when called by overseer; fixer uses the bound project."`
	ItemId      int    `json:"item_id" jsonschema:"Backlog item ID to update."`
	Title       string `json:"title,omitempty" jsonschema:"Optional replacement title."`
	Description string `json:"description,omitempty" jsonschema:"Optional replacement description."`
	Status      string `json:"status,omitempty" jsonschema:"Optional replacement status."`
	Priority    string `json:"priority,omitempty" jsonschema:"Optional replacement priority."`
}

type UpdateBacklogItemOutput struct {
	Status string      `json:"status"`
	Item   BacklogItem `json:"item"`
}

func resolveBacklogProjectID(projectID int) (int, error) {
	if authorizedRole != "fixer" && authorizedRole != "overseer" {
		return 0, fmt.Errorf("access denied: requires fixer or overseer role")
	}
	return resolveProjectHandoffProjectID(projectID)
}

func normalizeBacklogStatus(raw string) string {
	status := strings.TrimSpace(raw)
	if status == "" {
		return "open"
	}
	return status
}

func scanBacklogItem(row interface{ Scan(...any) error }) (BacklogItem, error) {
	var item BacklogItem
	err := row.Scan(
		&item.Id,
		&item.ProjectId,
		&item.Title,
		&item.Description,
		&item.Status,
		&item.Priority,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	return item, err
}

func fetchBacklogItem(itemID int, projectID int) (BacklogItem, error) {
	return scanBacklogItem(db.QueryRow(
		`SELECT id,
		        project_id,
		        COALESCE(title, ''),
		        COALESCE(description, ''),
		        COALESCE(status, 'open'),
		        COALESCE(priority, ''),
		        COALESCE(created_at, ''),
		        COALESCE(updated_at, '')
		 FROM backlog_item
		 WHERE id = ? AND project_id = ?`,
		itemID,
		projectID,
	))
}

func AddBacklogItem(ctx context.Context, req *mcp.CallToolRequest, input AddBacklogItemInput) (*mcp.CallToolResult, AddBacklogItemOutput, error) {
	projectID, err := resolveBacklogProjectID(input.ProjectId)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, AddBacklogItemOutput{}, err
	}

	title := strings.TrimSpace(input.Title)
	if title == "" {
		return &mcp.CallToolResult{IsError: true}, AddBacklogItemOutput{}, fmt.Errorf("title is required")
	}

	res, err := db.Exec(
		`INSERT INTO backlog_item (project_id, title, description, status, priority, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`,
		projectID,
		title,
		strings.TrimSpace(input.Description),
		normalizeBacklogStatus(input.Status),
		strings.TrimSpace(input.Priority),
	)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, AddBacklogItemOutput{}, fmt.Errorf("DB insert error: %v", err)
	}

	itemID, err := res.LastInsertId()
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, AddBacklogItemOutput{}, fmt.Errorf("LastInsertId error: %v", err)
	}

	item, err := fetchBacklogItem(int(itemID), projectID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, AddBacklogItemOutput{}, fmt.Errorf("DB query error: %v", err)
	}

	return nil, AddBacklogItemOutput{Id: item.Id, Status: "success", Item: item}, nil
}

func GetBacklogItems(ctx context.Context, req *mcp.CallToolRequest, input GetBacklogItemsInput) (*mcp.CallToolResult, GetBacklogItemsOutput, error) {
	projectID, err := resolveBacklogProjectID(input.ProjectId)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, GetBacklogItemsOutput{}, err
	}

	query := `SELECT id,
	                 project_id,
	                 COALESCE(title, ''),
	                 COALESCE(description, ''),
	                 COALESCE(status, 'open'),
	                 COALESCE(priority, ''),
	                 COALESCE(created_at, ''),
	                 COALESCE(updated_at, '')
	          FROM backlog_item
	          WHERE project_id = ?`
	args := []any{projectID}
	if status := strings.TrimSpace(input.Status); status != "" {
		query += " AND status = ?"
		args = append(args, status)
	}
	if priority := strings.TrimSpace(input.Priority); priority != "" {
		query += " AND priority = ?"
		args = append(args, priority)
	}
	query += " ORDER BY id"

	rows, err := db.Query(query, args...)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, GetBacklogItemsOutput{}, fmt.Errorf("DB query error: %v", err)
	}
	defer rows.Close()

	items := make([]BacklogItem, 0)
	for rows.Next() {
		item, scanErr := scanBacklogItem(rows)
		if scanErr != nil {
			return &mcp.CallToolResult{IsError: true}, GetBacklogItemsOutput{}, fmt.Errorf("DB scan error: %v", scanErr)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return &mcp.CallToolResult{IsError: true}, GetBacklogItemsOutput{}, fmt.Errorf("DB rows error: %v", err)
	}

	return nil, GetBacklogItemsOutput{ProjectId: projectID, Items: items}, nil
}

func UpdateBacklogItem(ctx context.Context, req *mcp.CallToolRequest, input UpdateBacklogItemInput) (*mcp.CallToolResult, UpdateBacklogItemOutput, error) {
	projectID, err := resolveBacklogProjectID(input.ProjectId)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, err
	}
	if input.ItemId <= 0 {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, fmt.Errorf("item_id must be positive")
	}

	updates := make([]string, 0, 4)
	args := make([]any, 0, 5)
	if strings.TrimSpace(input.Title) != "" {
		updates = append(updates, "title = ?")
		args = append(args, strings.TrimSpace(input.Title))
	}
	if strings.TrimSpace(input.Description) != "" {
		updates = append(updates, "description = ?")
		args = append(args, strings.TrimSpace(input.Description))
	}
	if strings.TrimSpace(input.Status) != "" {
		updates = append(updates, "status = ?")
		args = append(args, strings.TrimSpace(input.Status))
	}
	if strings.TrimSpace(input.Priority) != "" {
		updates = append(updates, "priority = ?")
		args = append(args, strings.TrimSpace(input.Priority))
	}
	if len(updates) == 0 {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, fmt.Errorf("at least one backlog item field is required")
	}

	updates = append(updates, "updated_at = CURRENT_TIMESTAMP")
	args = append(args, input.ItemId, projectID)
	res, err := db.Exec(
		fmt.Sprintf("UPDATE backlog_item SET %s WHERE id = ? AND project_id = ?", strings.Join(updates, ", ")),
		args...,
	)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, fmt.Errorf("DB update error: %v", err)
	}

	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, fmt.Errorf("RowsAffected error: %v", err)
	}
	if rowsAffected == 0 {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, fmt.Errorf("backlog item not found or not belonging to project")
	}

	item, err := fetchBacklogItem(input.ItemId, projectID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, UpdateBacklogItemOutput{}, fmt.Errorf("DB query error: %v", err)
	}

	return nil, UpdateBacklogItemOutput{Status: "success", Item: item}, nil
}

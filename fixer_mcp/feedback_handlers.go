package main

import (
	"context"
	"fmt"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

type SubmitFixerMcpFeedbackInput struct {
	ProjectID    *int   `json:"project_id,omitempty"`
	FeedbackType string `json:"feedback_type"`
	Content      string `json:"content"`
}

type SubmitFixerMcpFeedbackOutput struct {
	FeedbackID int    `json:"feedback_id"`
	Status     string `json:"status"`
}

func SubmitFixerMcpFeedback(ctx context.Context, req *mcp.CallToolRequest, input SubmitFixerMcpFeedbackInput) (*mcp.CallToolResult, SubmitFixerMcpFeedbackOutput, error) {
	if authorizedRole != "fixer" && authorizedRole != "overseer" {
		return &mcp.CallToolResult{IsError: true}, SubmitFixerMcpFeedbackOutput{}, fmt.Errorf("access denied: requires fixer or overseer role. current role: %s", authorizedRole)
	}

	targetProjectID := 0
	if authorizedRole == "overseer" {
		if input.ProjectID == nil {
			return &mcp.CallToolResult{IsError: true}, SubmitFixerMcpFeedbackOutput{}, fmt.Errorf("project_id is required for overseer role")
		}
		targetProjectID = *input.ProjectID
	} else {
		if authorizedProjectId <= 0 {
			return &mcp.CallToolResult{IsError: true}, SubmitFixerMcpFeedbackOutput{}, fmt.Errorf("fixer must be bound to a project to submit feedback")
		}
		targetProjectID = authorizedProjectId
	}

	if input.FeedbackType == "" {
		return &mcp.CallToolResult{IsError: true}, SubmitFixerMcpFeedbackOutput{}, fmt.Errorf("feedback_type is required")
	}
	if input.Content == "" {
		return &mcp.CallToolResult{IsError: true}, SubmitFixerMcpFeedbackOutput{}, fmt.Errorf("content is required")
	}

	var newID int
	err := db.QueryRow("INSERT INTO fixer_mcp_feedback (project_id, feedback_type, content) VALUES (?, ?, ?) RETURNING id",
		targetProjectID, input.FeedbackType, input.Content).Scan(&newID)
	if err != nil {
		return &mcp.CallToolResult{IsError: true}, SubmitFixerMcpFeedbackOutput{}, fmt.Errorf("failed to insert feedback: %v", err)
	}

	return nil, SubmitFixerMcpFeedbackOutput{
		FeedbackID: newID,
		Status:     "success",
	}, nil
}

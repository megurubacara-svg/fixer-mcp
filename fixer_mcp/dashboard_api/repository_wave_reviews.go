package dashboardapi

import (
	"context"
	"strconv"
	"strings"
)

const parallelWaveReviewMarkerPrefix = "parallel-wave-review:"

func (r *Repository) sessionHasColumn(ctx context.Context, columnName string) bool {
	return r.tableHasColumn(ctx, "session", columnName)
}

func (r *Repository) tableHasColumn(ctx context.Context, tableName string, columnName string) bool {
	var count int
	if err := r.db.QueryRowContext(ctx,
		"SELECT COUNT(*) FROM pragma_table_info(?) WHERE name = ?",
		tableName, columnName,
	).Scan(&count); err != nil {
		return false
	}
	return count > 0
}

func (r *Repository) ProjectWaveReviews(ctx context.Context, projectID int) (ProjectWaveReviewsResponse, error) {
	project, err := r.requireProject(ctx, projectID)
	if err != nil {
		return ProjectWaveReviewsResponse{}, err
	}
	response := ProjectWaveReviewsResponse{
		Project: ProjectHeader{ID: project.ID, Name: project.Name, CWD: project.CWD},
		Reviews: []WaveReviewSummary{},
	}
	if !r.sessionHasColumn(ctx, "parallel_wave_id") {
		return response, nil
	}

	localIDsBySession, err := r.loadLocalSessionIDs(ctx)
	if err != nil {
		return ProjectWaveReviewsResponse{}, err
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, task_description, status, COALESCE(report, ''), parallel_wave_id
		FROM session
		WHERE project_id = ? AND parallel_wave_id LIKE ?
		ORDER BY id`, projectID, parallelWaveReviewMarkerPrefix+"%")
	if err != nil {
		return ProjectWaveReviewsResponse{}, err
	}
	defer rows.Close()

	for rows.Next() {
		var sessionID int
		var taskDescription, status, reportRaw, marker string
		if err := rows.Scan(&sessionID, &taskDescription, &status, &reportRaw, &marker); err != nil {
			return ProjectWaveReviewsResponse{}, err
		}
		waveID, err := strconv.Atoi(strings.TrimPrefix(marker, parallelWaveReviewMarkerPrefix))
		if err != nil || waveID <= 0 {
			continue
		}
		response.Reviews = append(response.Reviews, WaveReviewSummary{
			WaveID:                waveID,
			SessionID:             sessionID,
			LocalSessionID:        localIDsBySession[sessionID],
			Status:                status,
			TaskPreview:           preview(taskDescription, 220),
			ReportRaw:             reportRaw,
			StructuredFinalReport: decodeStructuredFinalReport(reportRaw),
		})
	}
	if err := rows.Err(); err != nil {
		return ProjectWaveReviewsResponse{}, err
	}
	return response, nil
}

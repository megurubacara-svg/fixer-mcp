package dashboardapi

import (
	"context"
	"fmt"
	"strings"
)

// projectActivity is the durable activity data used by the home project rail.
// Keep this separate from the legacy ProjectCard shape so the ordering logic
// can be adopted by the new project-card module without changing project
// overview payloads owned by the downstream integration slice.
type projectActivity struct {
	LastActivityAt  string
	ActiveWaveCount int
}

func (r *Repository) loadProjectActivity(ctx context.Context) (map[int]projectActivity, error) {
	activity := map[int]projectActivity{}

	// Each source is optional for compatibility with older fixer databases and
	// the small dashboard fixtures used by repository tests.
	queries := []string{}
	if r.tableExists(ctx, "netrunner_session_log") {
		queries = append(queries, `
			SELECT project_id, MAX(COALESCE(created_at, ''))
			FROM netrunner_session_log
			GROUP BY project_id`)
	}
	if r.tableExists(ctx, "autonomous_run_status") {
		queries = append(queries, `
			SELECT project_id, MAX(COALESCE(updated_at, ''))
			FROM autonomous_run_status
			GROUP BY project_id`)
	}
	if r.tableExists(ctx, "worker_process") {
		queries = append(queries, `
			SELECT project_id, MAX(COALESCE(updated_at, ''))
			FROM worker_process
			GROUP BY project_id`)
	}
	if r.tableExists(ctx, "parallel_wave") {
		queries = append(queries, `
			SELECT project_id, MAX(COALESCE(updated_at, ''))
			FROM parallel_wave
			GROUP BY project_id`)
	}

	for _, query := range queries {
		rows, err := r.db.QueryContext(ctx, query)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var projectID int
			var timestamp string
			if err := rows.Scan(&projectID, &timestamp); err != nil {
				_ = rows.Close()
				return nil, err
			}
			if timestamp > activity[projectID].LastActivityAt {
				entry := activity[projectID]
				entry.LastActivityAt = timestamp
				activity[projectID] = entry
			}
		}
		if err := rows.Err(); err != nil {
			_ = rows.Close()
			return nil, err
		}
		if err := rows.Close(); err != nil {
			return nil, err
		}
	}

	if r.tableExists(ctx, "parallel_wave") {
		rows, err := r.db.QueryContext(ctx, `
			SELECT project_id, COUNT(*)
			FROM parallel_wave
			WHERE status NOT IN ('completed', 'failed', 'stopped', 'cleaned')
			GROUP BY project_id`)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var projectID int
			var count int
			if err := rows.Scan(&projectID, &count); err != nil {
				_ = rows.Close()
				return nil, err
			}
			entry := activity[projectID]
			entry.ActiveWaveCount = count
			activity[projectID] = entry
		}
		if err := rows.Err(); err != nil {
			_ = rows.Close()
			return nil, err
		}
		if err := rows.Close(); err != nil {
			return nil, err
		}
	}

	return activity, nil
}

func hasProjectActivity(timestamp string) bool {
	return strings.TrimSpace(timestamp) != ""
}

func (r *Repository) loadAutonomousStatuses(ctx context.Context) (map[int]*AutonomousStatus, AutonomousSummary, error) {
	if !r.tableExists(ctx, "autonomous_run_status") {
		return map[int]*AutonomousStatus{}, AutonomousSummary{}, nil
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			project_id,
			COALESCE(session_id, 0),
			state,
			summary,
			COALESCE(focus, ''),
			COALESCE(blocker, ''),
			COALESCE(evidence, ''),
			COALESCE(orchestration_epoch, 0),
			COALESCE(orchestration_frozen, 0),
			COALESCE(notifications_enabled_for_active_run, 1),
			COALESCE(updated_at, '')
		FROM autonomous_run_status
		ORDER BY project_id`)
	if err != nil {
		return nil, AutonomousSummary{}, err
	}
	defer rows.Close()

	localIDsBySession, err := r.loadLocalSessionIDs(ctx)
	if err != nil {
		return nil, AutonomousSummary{}, err
	}

	records := map[int]*AutonomousStatus{}
	summary := AutonomousSummary{}
	for rows.Next() {
		var record AutonomousStatus
		var frozenInt int
		var notificationsInt int
		if err := rows.Scan(
			&record.ProjectID,
			&record.SessionID,
			&record.State,
			&record.Summary,
			&record.Focus,
			&record.Blocker,
			&record.Evidence,
			&record.OrchestrationEpoch,
			&frozenInt,
			&notificationsInt,
			&record.UpdatedAt,
		); err != nil {
			return nil, AutonomousSummary{}, err
		}
		record.OrchestrationFrozen = frozenInt != 0
		record.NotificationsEnabledForActiveRun = notificationsInt != 0
		if record.SessionID > 0 {
			record.LocalSessionID = localIDsBySession[record.SessionID]
		}
		records[record.ProjectID] = &record
		summary.ProjectsWithStatus++
		switch record.State {
		case "running":
			summary.RunningProjects++
		case "blocked":
			summary.BlockedProjects++
		case "awaiting_review":
			summary.AwaitingReview++
		}
		if record.OrchestrationFrozen {
			summary.FrozenProjects++
		}
	}
	return records, summary, rows.Err()
}

func (r *Repository) loadActiveWorkers(ctx context.Context) (map[int]WorkerStateSummary, []ActiveWorkerSummary, error) {
	bySession, err := r.loadRunningWorkersBySession(ctx)
	if err != nil {
		return nil, nil, err
	}
	if len(bySession) == 0 {
		return map[int]WorkerStateSummary{}, []ActiveWorkerSummary{}, nil
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT
			s.id,
			s.project_id,
			p.name,
			(
				SELECT COUNT(*)
				FROM session s2
				WHERE s2.project_id = s.project_id AND s2.id <= s.id
			) AS local_session_id,
			s.task_description
		FROM session s
		INNER JOIN project p ON p.id = s.project_id
		ORDER BY s.project_id, s.id`)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	byProject := map[int]WorkerStateSummary{}
	active := []ActiveWorkerSummary{}
	for rows.Next() {
		var sessionID, projectID, localSessionID int
		var projectName, taskDescription string
		if err := rows.Scan(&sessionID, &projectID, &projectName, &localSessionID, &taskDescription); err != nil {
			return nil, nil, err
		}
		processes := bySession[sessionID]
		if len(processes) == 0 {
			continue
		}
		summary := WorkerStateSummary{
			RunningCount: len(processes),
			HasRunning:   true,
			Processes:    processes,
		}
		projectSummary := byProject[projectID]
		projectSummary.RunningCount += len(processes)
		projectSummary.HasRunning = true
		projectSummary.Processes = append(projectSummary.Processes, processes...)
		byProject[projectID] = projectSummary
		active = append(active, ActiveWorkerSummary{
			ProjectID:      projectID,
			ProjectName:    projectName,
			SessionID:      sessionID,
			LocalSessionID: localSessionID,
			Headline:       firstLineOrFallback(taskDescription, fmt.Sprintf("Session #%d", localSessionID)),
			WorkerState:    summary,
		})
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}
	return byProject, active, nil
}

func (r *Repository) loadRunningWorkersBySession(ctx context.Context) (map[int][]WorkerProcess, error) {
	if !r.tableExists(ctx, "worker_process") {
		return map[int][]WorkerProcess{}, nil
	}
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, session_id, pid, launch_epoch, status, started_at, updated_at, COALESCE(stopped_at, ''), COALESCE(stop_reason, '')
		FROM worker_process
		WHERE status = 'running'
		ORDER BY session_id, id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	localIDsBySession, err := r.loadLocalSessionIDs(ctx)
	if err != nil {
		return nil, err
	}

	bySession := map[int][]WorkerProcess{}
	for rows.Next() {
		var worker WorkerProcess
		if err := rows.Scan(&worker.ID, &worker.SessionID, &worker.PID, &worker.LaunchEpoch, &worker.Status, &worker.StartedAt, &worker.UpdatedAt, &worker.StoppedAt, &worker.StopReason); err != nil {
			return nil, err
		}
		worker.Alive = isProcessAlive(worker.PID)
		worker.LocalID = localIDsBySession[worker.SessionID]
		bySession[worker.SessionID] = append(bySession[worker.SessionID], worker)
	}
	return bySession, rows.Err()
}

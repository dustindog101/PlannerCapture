# PlannerCapture Roadmap

## Current Status

Phase: **Post-v3 stabilization (early production hardening)**.

The app has core end-user functionality in place (capture, planning, groups, settings, diagnostics), but reliability engineering and automated regression coverage are not yet complete.

## Completed Milestones

### v2 (Completed)
Goal: baseline hub-backed planner flow.
Delivered:
- Menubar integration and gateway task flow.
- Section model (`Waiting`, `Immediate`, `This Week`, `Other`, `Done`).
- Planner manager workflow.

### v2.1 (Completed)
Goal: improve usability and settings control.
Delivered:
- Row-level star toggling with immediate persistence.
- Material polish in app surfaces.
- Expanded settings controls (views/sorting/grouping density).

### v3 (Completed)
Goal: group-aware planning model.
Delivered:
- Group model (`group_id`) and group APIs.
- Grouping modes: bucket, group->bucket, bucket->group.
- Planner remodel with inspector metadata and saved layout behavior.

### Post-v3 UX Fixes (Completed, latest)
Goal: close major interaction gaps.
Delivered:
- Status-move and selection sync fixes.
- Hotkey parsing improvements.
- Group editor completion and inspector sync improvements.

## Current Milestone (Active)

### M0: Reliability and Observability Hardening
Goal: make sync behavior predictable and debuggable under failure.

In scope:
- Stabilize edge-case behavior around stale state and retries.
- Document and test request-ID-based debugging workflow.
- Reduce regressions in parsing/sectioning/edit-save behavior.

Dependencies:
- Existing API behavior from Daily Helper Hub remains stable.

Complexity: **M**

## Upcoming Milestones

### M1: Automated Test Harness + Regression Suite
Goal: establish repeatable quality gate for core business logic.

Tasks:
- Add XCTest target for parser, sectioning, sorting, settings sanitization.
- Add deterministic fixtures for task/group payload decoding.
- Add regression tests for stale-task 404 recovery path and star rollback behavior.

Dependencies:
- M0 documentation and behavior lock-in.

Complexity: **L**

### M2: Settings and Schema Robustness
Goal: harden configuration durability and forward compatibility.

Tasks:
- Add settings migration strategy for future keys.
- Split/organize monolithic `Models.swift` into clearer layers (models/client/store).
- Define explicit API compatibility assumptions and failure handling around decode drift.

Dependencies:
- M1 test harness to protect refactors.

Complexity: **L**

### M3: UX Expansion on Stable Core
Goal: add quality-of-life features after reliability baseline.

Tasks:
- Better search/filter interactions in planner view.
- Bulk actions and keyboard-centric planner operations.
- Optional richer group metadata and presentation.
- Redesign UI to match Apple Reminders aesthetic (circular checkboxes, priority indicators, inline due dates).

Dependencies:
- M1+M2 complete.

Complexity: **M/L**

## Backlog / Future Ideas

- Offline mode with local queue/cache for temporary gateway outages.
- Background refresh/notification workflows for due tasks.
- Export/reporting views for weekly planning snapshots.
- Better conflict messaging when external systems modify tasks concurrently.

## Known Technical Debt

- No automated tests or CI in repository.
- `Sources/Models.swift` is oversized and mixes multiple responsibilities.
- API contract coupling is implicit (no schema version contract tests).
- Build process is script-based only (`build.sh`) with no project-level package manifest.

## Suggested Work Order

1. Complete M0 hardening checks and docs consistency.
2. Deliver M1 tests with required regression coverage.
3. Execute M2 refactor/migration work incrementally behind tests.
4. Start M3 user-facing enhancements only after M1+M2 stability goals are met.

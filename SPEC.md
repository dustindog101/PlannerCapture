# PlannerCapture Product Specification (PRD)

## Product Overview

PlannerCapture is a macOS-first task capture and planning client that provides:
- a global hotkey capture surface,
- a menubar task dashboard,
- a full planner/editor window,
- and a settings/diagnostics UI,

while persisting all task and group state through the Daily Helper Hub gateway.

Problem solved:
- Fast task capture with minimal context switching.
- Lightweight planning workflow with status, priority, due date, starred, and group metadata.
- Unified hub-backed source of truth used by other tools in the same ecosystem.

## Target Users (Inferred)

1. Student planner users
- Need very fast “capture now, organize later” flow.
- Benefit from waiting/priority buckets and due-date triage.

2. Individual productivity users
- Want menubar-level visibility and quick status updates.
- Need simple grouping (e.g., School, Personal, Work).

3. Power users of Daily Helper Hub
- Expect sync with existing task ecosystem and request-level diagnostics.

## User Stories / Use Cases

- As a user, I want to press a global hotkey and capture a task in one line so that I do not lose context.
- As a user, I want inline commands (`/done`, `#p4`, `#g:School`) so that I can encode metadata at capture time.
- As a user, I want tasks grouped into actionable sections (`Immediate`, `This Week`, `Other`, `Waiting`, `Done`) so that prioritization is automatic.
- As a user, I want to edit task fields in an inspector so that I can refine details after capture.
- As a user, I want to create/rename/remove groups in-app so that I can organize tasks without leaving PlannerCapture.
- As a user, I want resilient sync with clear connection state and logs so that failures are diagnosable.

## Core Features and Acceptance Criteria

## F1. Global Hotkey Capture (P0)
Implementation:
- `GlobalHotkey.register` in `Sources/GlobalHotkey.swift`.
- Floating capture panel in `Sources/FloatingWindowController.swift`.

Acceptance criteria:
- Pressing `Cmd+Shift+Space` toggles the capture panel.
- Enter submits parsed input and closes panel.
- Empty input is ignored.

## F2. Capture Command Parsing (P0)
Implementation: `parseCaptureInput(_:)`.

Supported command behavior:
- Status commands: `/done`, `/todo`, `/inbox`, `/blocked`/`/block`, `/inprogress`/`/in_progress`, `/archived`/`/archive`.
- Priority/star tokens: leading `!`, `#p0..#p4`, `#star`, `*`.
- Notes separator: `::`.
- Group token: `#g:<name>`.

Acceptance criteria:
- Unknown slash command does not fail capture; treated as plain title and warning logged.
- Unknown group name does not fail capture; task is created ungrouped and warning logged.
- Leading `!` increases priority from baseline and stars task.

## F3. Hub Gateway Task/Group Sync (P0)
Implementation: `GatewayClient` + `TaskStore` in `Sources/Models.swift`.

Acceptance criteria:
- Tasks and groups load from gateway and render in UI.
- Create, edit, complete/toggle, archive, and star updates persist via API.
- Polling checks latest sequence and refreshes when sequence advances.

## F4. Menubar Dashboard (P1)
Implementation: `MenuBarManager` and `MenuContentView`.

Acceptance criteria:
- Menubar icon opens popover with connection status and summary line.
- Popover displays up to first 4 sections and up to first 6 tasks per section.
- Row controls allow toggle done, toggle star, and archive.

## F5. Planner Manager Window (P0)
Implementation: `PlannerWindowController` + `PlannerModernView`.

Acceptance criteria:
- Supports pages: Tasks, Groups, Settings.
- Tasks page supports section selection, task list, and inspector edit/save/reset.
- Group changes are reflected after successful API operations.
- Task status changes can move selected task between sections with message feedback.

## F6. Group-Aware Views and Filtering (P1)
Implementation: `GroupViewMode`, `buildSections`.

Acceptance criteria:
- Modes supported: `bucket`, `group_then_bucket`, `bucket_then_group`.
- Ungrouped tasks are represented as “Ungrouped”.
- Visibility filters (`visibleGroupIds`) influence section construction.

## F7. Settings and Diagnostics (P0)
Implementation: `SettingsStore`, `SettingsView`, `PlannerLogger`.

Acceptance criteria:
- Settings are persisted to `~/Library/Application Support/PlannerCapture/settings.json`.
- Log level updates runtime filtering.
- “Open logs” opens log file location.
- “Copy last error” copies recent WARN/ERROR context.

## Feature Priority

- P0 (Must have): Global capture, parsing, gateway sync, planner editor, settings persistence.
- P1 (Should have): Menubar quick actions, group-aware views, diagnostics UX.
- P2 (Nice to have): Legacy/new UI switch fallback, optional CLI mirroring.

## Data Model / Schema (Client View)

## `PlannerTask`
Source: `Sources/Models.swift`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Required identifier |
| `title` | `String` | Defaults to `Untitled task` if missing |
| `notes` | `String` | Optional text |
| `status` | `TaskStatus` | `inbox`, `todo`, `in_progress`, `blocked`, `done`, `archived` |
| `priority` | `Int` | Normalized to 0..4 on writes |
| `isStarred` | `Bool` | Decodes from bool or int |
| `source` | `String` | Source attribution (`menubar`, `menubar_capture`, etc.) |
| `sourceRef` | `String` | External/source reference |
| `groupId` | `String?` | Optional group association |
| `dueAt` | `Int?` | Unix timestamp |
| `updatedAt` | `Int` | Unix timestamp |

## `TaskGroup`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Group ID |
| `name` | `String` | Display name |
| `color` | `String` | Gateway-provided color label |
| `sortOrder` | `Int` | Ordering hint |
| `archivedAt` | `Int?` | Archived marker |

## `PlannerSettings`

Persisted keys include:
- `gatewayURL`, `apiToken`
- `pollVisibleSec`, `pollHiddenSec`
- `defaultStatusRaw`
- `immediateOverrideEnabled`
- `mirrorCLI`
- `logLevelRaw`
- `showDoneSection`, `showWaitingSection`
- `defaultSortModeRaw`
- `defaultGroupViewRaw`
- `starClickImmediateSave`
- `compactRowDensity`
- `defaultGroupId`
- `visibleGroupIds`
- `newUIEnabled`

## API Endpoints and Contracts (Observed)

All requests are issued from `GatewayClient` in `Sources/Models.swift`.

Headers:
- `Accept: application/json`
- `Content-Type: application/json` for body requests
- Optional: `Authorization: Bearer <token>` when token exists
- `X-Request-Id: <uuid>` added to every request

Endpoints:
- `GET /v1/meta/seq` → `{ "latest_seq": Int }`
- `GET /v1/tasks?limit=<n>` → `{ "tasks": [...], "latest_seq": Int }`
- `POST /v1/tasks` with fields:
  - `title`, `notes`, `status`, `priority`, `is_starred`, `source`, `group_id`, `source_ref`
- `PATCH /v1/tasks/{id}` with task patch fields
- `POST /v1/tasks/{id}/complete`
- `POST /v1/tasks/{id}/archive`
- `GET /v1/groups` → `{ "groups": [...] }`
- `POST /v1/groups` with `name`, `color`, `sort_order`
- `PATCH /v1/groups/{id}` (rename uses `{ "name": ... }`)
- `POST /v1/groups/{id}/archive`

## Primary User Flows

### Flow A: Quick capture
1. Trigger hotkey.
2. Enter capture string with optional commands.
3. Submit.
4. Task created via gateway.
5. Task appears in derived sections.

### Flow B: Plan and edit
1. Open planner window from menubar.
2. Select section and task.
3. Edit fields in inspector.
4. Save patch to gateway.
5. Task moves sections if status/due/priority rules changed.

### Flow C: Group management
1. Open planner `Groups` page.
2. Add group or rename/remove existing group.
3. Gateway applies change.
4. Task/group lists refresh and regroup.

## Business Rules and Embedded Logic

- Default capture status comes from settings (`defaultStatusRaw`, default `inbox`).
- Immediate section includes:
  - due within 24h, or
  - (if `immediateOverrideEnabled`) starred or priority >= 3 without due date.
- This Week section includes tasks due within 7 days (excluding immediate window).
- Waiting section is status `inbox`; Done section is status `done`; archived excluded from active buckets.
- Task actions are serialized per task ID (`inFlightActions`) to avoid concurrent conflicting mutations.

## Non-Functional Requirements (Inferred)

- Responsiveness:
  - HTTP request timeout configured (`timeoutIntervalForRequest = 10`, resource timeout 15).
- Reliability:
  - Polling with exponential backoff + jitter.
  - Connection health tracking (`isConnected`, `consecutiveFailures`).
  - 404 stale-task recovery by local removal + forced refresh.
- Observability:
  - Structured logs with request IDs and response IDs when available.
  - Diagnostics copy for recent warn/error lines.
- Security:
  - No shell interpolation for optional CLI mirror path (`Process` arguments used directly).
  - Bearer token sourced from local settings.
- Accessibility/system integration:
  - Global hotkey requires macOS permissions/access.


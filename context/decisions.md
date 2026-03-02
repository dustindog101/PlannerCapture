# Context Decisions

### 2026-03-01 — Gateway-Backed Client Architecture
**Decision:** PlannerCapture persists tasks/groups via Daily Helper Hub gateway instead of owning a local DB.

**Context:** `GatewayClient` in `Sources/Models.swift` implements all task/group read-write behavior using HTTP.

**Alternatives considered (inferred):**
- Embed local SQLite in app.
- Hybrid local-first sync model.

**Why this was chosen (inferred):**
- Reuse existing hub ecosystem as single source of truth.
- Keep macOS app lightweight and focused on capture/planning UX.

### 2026-03-01 — Section-Centric Planning Model
**Decision:** Organize UI around computed sections (`Immediate`, `This Week`, `Other`, `Waiting`, `Done`) instead of raw task list only.

**Context:** Implemented in `TaskStore.buildSections` and used by menubar/planner views.

**Alternatives considered (inferred):**
- Flat list with user-defined filters only.
- Kanban-style columns by status only.

**Why this was chosen (inferred):**
- Fast prioritization without forcing manual sorting.

### 2026-03-01 — Grouping Modes as View Strategy
**Decision:** Support three group view modes (`bucket`, `group_then_bucket`, `bucket_then_group`).

**Context:** `GroupViewMode` + section rendering logic in `buildSections`.

**Alternatives considered (inferred):**
- Single fixed grouping mode.

**Why this was chosen (inferred):**
- Different planning contexts need different visual hierarchy.

### 2026-03-01 — Request-ID Diagnostics
**Decision:** Attach `X-Request-Id` to every gateway call and log both client and response IDs.

**Context:** `GatewayClient.request(...)` and `PlannerLogger` metadata usage.

**Alternatives considered (inferred):**
- Generic error logs with no correlation.

**Why this was chosen (inferred):**
- Easier cross-log tracing with gateway logs during failures.

### 2026-03-01 — Legacy UI Fallback Kept
**Decision:** Keep `newUIEnabled` switch and legacy planner fallback path.

**Context:** `PlannerRootView` selects modern vs legacy view using settings flag.

**Alternatives considered (inferred):**
- Hard-cut to modern UI only.

**Why this was chosen (inferred):**
- Risk mitigation during post-refactor stabilization.

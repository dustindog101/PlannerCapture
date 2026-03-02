# PlannerCapture Progress Log

## Last Updated
- **March 1, 2026**

## Overall Project Status
- **Estimated completion:** ~75% toward a stable, maintainable v3 baseline.
- **Phase:** Feature-complete core with reliability/testing hardening still pending.

## What's Working (✅)

- ✅ Global hotkey capture (`Cmd+Shift+Space`) with command parsing.
- ✅ Menubar popover with live connection state and task quick actions.
- ✅ Planner manager window with task inspector editing.
- ✅ Group creation, rename, archive/removal flows in-app.
- ✅ Section derivation model (`Immediate`, `This Week`, `Other`, `Waiting`, `Done`).
- ✅ Configurable sort/group view and section visibility settings.
- ✅ Structured file logging + diagnostics helpers (`Open logs`, `Copy last error`).
- ✅ Request ID propagation for gateway correlation (`X-Request-Id`).

## In Progress (🔄)

- 🔄 Reliability hardening posture is partially implemented (backoff, stale-task recovery) but not verified by tests.
- 🔄 Documentation memory-bank expansion (this documentation set) is being established.
- 🔄 Architectural maintainability improvements are identified but not yet executed (monolithic `Models.swift`).

## Broken or Blocked (❌)

- ❌ No automated test suite currently exists (unit/integration/e2e).
- ❌ No CI pipeline is present to enforce regression checks.
- ❌ App is operationally dependent on external Daily Helper Hub gateway/database runtime.

## Recent Changes (from git history)

### 2026-03-01 — `b740a41`
`fix(ux): finalize groups, status movement, hotkey parsing, and inspector sync`
- Updated: `README.md`
- Updated: `Sources/FloatingWindowController.swift`
- Updated: `Sources/MenuBarManager.swift`
- Updated: `Sources/Models.swift`
- Updated: `Sources/PlannerWindowController.swift`

### 2026-03-01 — `7635a39`
`refactor(ui): rebuild planner and menubar with clean native workflow`
- Updated: `CHANGELOG.md`, `README.md`
- Updated major UI/state files (`MenuBarManager`, `PlannerWindowController`, `Settings*`, `UIPrimitives`, `Models`)

### Milestone tags present
- `v2`
- `v2.1`
- `v3`

## Key Decisions Made

- Gateway-first architecture: PlannerCapture is a client over Daily Helper Hub APIs (no internal DB).
- Derived sections as product core: task display is computed from status/due/priority/star/group settings.
- Request-correlated logging: every API request includes request ID for cross-service troubleshooting.
- UI fallback strategy: `newUIEnabled` allows fallback to legacy planner view.

## Open Questions

- Should archived tasks have a first-class UI surface/filter in planner views?
- Is offline queueing/caching required for temporary gateway outages?
- Should API compatibility be explicitly versioned and validated in client tests?
- Should the app continue as a single large `Models.swift` architecture, or be split into layered files now?

## Immediate Next Work Candidates

1. Add XCTest coverage for parser + sectioning + settings sanitization.
2. Add regression tests for stale-task 404 recovery and star rollback.
3. Start incremental `Models.swift` decomposition after tests are in place.

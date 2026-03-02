# CLAUDE.md

## Project Context

PlannerCapture is a native macOS menubar + planner application written in Swift (SwiftUI + AppKit) that uses Daily Helper Hub as its backend source of truth. The app provides global hotkey capture, task sectioning, in-app editing, group management, and diagnostics/logging.

The core operational model is client-only local state (`TaskStore`) synchronized via HTTP through `GatewayClient` to a locally running hub gateway (default `http://127.0.0.1:8765`).

## Code Style and Naming Rules

- Swift naming conventions:
  - Types/protocols/enums: `PascalCase`.
  - Variables/functions/properties: `camelCase`.
  - Enum raw values: snake_case only when API contract requires it (e.g., `in_progress`).
- Keep JSON coding keys aligned with gateway payload fields (`snake_case`).
- Use explicit, descriptive names for task/action methods (`toggleTask`, `saveTaskEdits`, `archiveGroup`).

## File Organization Rules

- Domain models, gateway transport, and central task-state logic live in [`Sources/Models.swift`](./Sources/Models.swift).
- Planner window UI flows live in [`Sources/PlannerWindowController.swift`](./Sources/PlannerWindowController.swift).
- Menubar behavior lives in [`Sources/MenuBarManager.swift`](./Sources/MenuBarManager.swift).
- Capture panel + parser logic live in [`Sources/FloatingWindowController.swift`](./Sources/FloatingWindowController.swift).
- Settings schema/persistence belongs in [`Sources/SettingsStore.swift`](./Sources/SettingsStore.swift).
- Shared visual primitives belong in [`Sources/UIPrimitives.swift`](./Sources/UIPrimitives.swift).

## Architectural Rules

- Always route gateway API calls through `GatewayClient`.
- Always route task/group mutations through `TaskStore` (do not mutate UI-local arrays directly).
- Preserve request correlation behavior (`X-Request-Id` + log metadata) for all new network calls.
- Preserve action in-flight guard semantics (`beginAction`/`endAction`) when adding task actions.
- Keep status/group/priority business logic in store/domain layer, not inside view code.

## Do and Don't

- ✅ DO update `TaskEditDraft.patchFields()` when task-editable schema changes.
- ✅ DO rebuild `sections` after task/group mutations that affect display state.
- ✅ DO log failures with enough context (`task_id`, action, request ID when available).
- ✅ DO clamp and validate user-configurable settings in `SettingsStore.sanitize`.
- ❌ DON'T call gateway directly from SwiftUI views.
- ❌ DON'T bypass `GatewayError` mapping with ad-hoc error strings.
- ❌ DON'T add new dependencies or services without updating `tech-stack.md`.

## Common Commands

```bash
# Build app bundle
cd "/Users/king/Desktop/school files/PlannerCapture"
./build.sh

# Run app
open PlannerCapture.app

# Start backend dependency (Daily Helper Hub)
cd "/Users/king/Desktop/school files/daily-helper-hub"
python3 hub-db/init_db.py
python3 hub-gateway/server.py
```

## Error-Prone Areas

- `parseCaptureInput(_:)`: token precedence and unknown-token behavior are easy to regress.
- `buildSections(from:)`: grouping/sorting/visibility interactions are multi-dimensional.
- Action concurrency: task actions must respect `inFlightActions` to avoid race conditions.
- 404 stale-task path: keep forced-refresh recovery logic intact.
- Settings persistence: malformed settings must degrade safely to defaults.

## Documentation Maintenance Rules

- After feature changes, update [`progress.md`](./progress.md).
- After dependency or runtime changes, update [`tech-stack.md`](./tech-stack.md).
- After architecture/state-flow changes, update [`architecture.md`](./architecture.md).
- After behavior/requirements changes, update [`SPEC.md`](./SPEC.md).
- After milestone reprioritization, update [`ROADMAP.md`](./ROADMAP.md).
- After API behavior discoveries, update `context/api-notes.md`.

## When Unsure

Ask before making assumptions about:
- Hub API behavior not visible in this repo.
- Product-level status semantics beyond current implementation.
- Whether to keep or remove legacy UI fallback (`newUIEnabled`).

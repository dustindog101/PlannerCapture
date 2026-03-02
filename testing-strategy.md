# PlannerCapture Testing Strategy

## Current State

- No automated tests are currently checked into this repository.
- No XCTest target, UI test target, or CI workflow is present.
- Quality is currently validated manually by running the app and observing behavior against the hub gateway.

## Testing Frameworks

## Recommended baseline
- **XCTest** for unit-level and logic-integration tests (Swift-native, no new external dependency required).

## Optional later stage
- **XCUITest** for high-value UI regressions after unit coverage baseline is stable.

## Test Types and Scope

## 1) Unit tests (first priority)
Focus on pure logic and deterministic behavior:
- `parseCaptureInput(_:)` in `Sources/FloatingWindowController.swift`.
- `sortTasks(_:)` behavior in `TaskStore` (`Sources/Models.swift`).
- `PlannerSettings` sanitization in `SettingsStore.sanitize(_:)`.

## 2) Logic integration tests (second priority)
Focus on composed in-memory behavior:
- `buildSections(from:)` bucketing/grouping outcomes for representative task fixtures.
- `TaskEditDraft.patchFields()` normalization and field mapping.
- Error mapping from HTTP/transport/decode cases to `GatewayError.userMessage`.

## 3) Manual end-to-end checks (current operational reality)
Until automation is added, validate:
- Hotkey capture -> task appears in planner/menubar.
- Task toggle/edit/archive/star actions sync through gateway.
- Group create/rename/remove updates section rendering.
- Settings save/reload effects on behavior (polling, grouping, sorting, visibility).

## How to Run Tests (Target State)

After adding XCTest targets:

```bash
# Example when an Xcode project or SwiftPM package target exists
xcodebuild test -scheme PlannerCapture -destination 'platform=macOS'
```

⚠️ `xcodebuild test` is not currently runnable from this repo shape because no test project/target is defined yet.

## Test File Location Conventions (Proposed)

When test targets are created:
- `Tests/PlannerCaptureTests/ParseCaptureInputTests.swift`
- `Tests/PlannerCaptureTests/SectioningTests.swift`
- `Tests/PlannerCaptureTests/SettingsStoreTests.swift`
- `Tests/PlannerCaptureTests/GatewayErrorTests.swift`

Naming:
- `*Tests.swift` files.
- `test_<condition>_<expectedBehavior>()` or readable camelCase test names.

## Priority Test Scenarios

## Capture parser scenarios
- Plain title defaults.
- Slash command overrides status correctly.
- Priority tokens (`!`, `#pN`) precedence and clamping behavior.
- `#star` and `*` star behavior.
- Notes parsing with `::`.
- Unknown slash/group tokens handled safely.

## Sectioning and sorting scenarios
- Due-date window boundaries (<=24h immediate, <=7d this week, else other).
- `immediateOverrideEnabled` effect for starred/high-priority tasks with no due date.
- Group modes:
  - `bucket`
  - `group_then_bucket`
  - `bucket_then_group`
- Section visibility toggles for waiting/done.

## Settings sanitization scenarios
- Invalid URL fallback.
- Poll interval clamping.
- Invalid enum raw values fallback to defaults.

## Error and recovery scenarios
- `GatewayError.userMessage` mapping.
- Action-level HTTP 404 stale task behavior (remove local task + refresh trigger).
- Star optimistic update rollback on failure.

## What Should Not Be Tested (Yet)

- Pure visual styling details (`Material`, corner radius, spacing constants) unless they impact behavior.
- Snapshot-level pixel-perfect rendering checks.
- Deep UI automation for every control before core logic has baseline unit coverage.

## Best Practices for This Project

- Prefer deterministic fixtures over live gateway calls for unit tests.
- Keep gateway contract assumptions explicit in fixture payloads (snake_case keys).
- Isolate time-dependent logic by controlling “now” inputs when possible.
- Add regression tests for every bug fixed in parser/section movement/stale state handling.

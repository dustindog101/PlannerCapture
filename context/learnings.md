# Context Learnings

## Practical Gotchas

- Global hotkey requires macOS accessibility/permission context; if capture does not appear, verify system permissions.
- Unknown slash commands in capture are intentionally non-fatal and treated as plain title text, with warning logs.
- Unknown `#g:<name>` group tokens do not block capture; task is created ungrouped and warning logged.
- Task actions are guarded by per-task in-flight action tracking; repeated rapid clicks can be ignored by design.
- A `404` during task action is treated as stale local state and triggers forced refresh behavior.

## Debugging Notes

- Planner logs: `~/Library/Logs/PlannerCapture/plannercapture.log`.
- Gateway errors often include response request ID via header; match against app request ID logs.
- `Copy last error` pulls recent WARN/ERROR lines (up to 12) to clipboard for quick bug reports.

## Behavior Details That Are Easy to Miss

- Default plain capture status is configurable and defaults to `inbox` (`Waiting`).
- Star toggles are optimistic in UI and roll back if PATCH fails.
- Section inclusion depends on both settings and derived task attributes (status, due date, priority, starred, group visibility).


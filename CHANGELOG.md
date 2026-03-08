# PlannerCapture Changelog

## v2

- Menubar + gateway-backed task flow.
- Waiting/Immediate/This Week/Other/Done section model.
- Standalone Planner manager window with edit panel.
- Reliability hardening with request IDs, stale-task recovery, and persistent logs.

## v2.1

- Click-to-star support directly on task rows with immediate persistence.
- Lightweight macOS material polish in menubar and manager surfaces.
- Expanded settings for section visibility, sort mode, group view mode, and row density.

## v3.1

- Inline due date parsing in capture surface using `|` separator or `due:` token.
- Support for relative offsets (`5m`, `2h`, `1d`, `1w`, `1h30m`).
- Natural language and absolute date/time parsing via `NSDataDetector`.
- Smart rolling for past dates (bumps to tomorrow/next year).
- Graceful degradation for unrecognized dates (stored in task notes).
- Introduced automated unit testing suite with 20 initial tests.

## v3

- Group-aware task model with `group_id` support.
- Grouping modes: bucket, group->bucket, bucket->group.
- Manager editor includes group picker and grouping-aware section rendering.
- Major UI remodel with three-pane Apple-glass layout, saved filters, collapsible sections, and inspector metadata.
- Tabbed settings architecture (`General`, `Views`, `Shortcuts`, `Data & Sync`, `Diagnostics`) with `new_ui_enabled` fallback toggle.

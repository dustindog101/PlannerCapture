# PlannerCapture

PlannerCapture is a native macOS menubar + planner app for fast task capture and task management, backed by Daily Helper Hub APIs.

## Key Features

- Global hotkey capture (`Cmd+Shift+Space`) via floating input panel.
- Capture command parsing for status, priority, star, notes, and group assignment.
- Menubar popover with connection state and quick task actions.
- Full planner window with sectioned task list and inspector editing.
- In-app group management (add/rename/remove/archive).
- Settings UI for sync, views, defaults, and diagnostics.
- Request-correlated persistent logs for troubleshooting.

## Documentation Map

- [Technology stack](./tech-stack.md)
- [System architecture](./architecture.md)
- [Product spec](./SPEC.md)
- [Roadmap](./ROADMAP.md)
- [Progress log](./progress.md)
- [Testing strategy](./testing-strategy.md)
- [AI agent rules](./CLAUDE.md)
- [Context knowledge base](./context/)

## Tech Stack (Summary)

- Swift + SwiftUI + AppKit + Carbon
- Foundation `URLSession` for gateway API integration
- Local settings JSON + file-based app logs
- Build via `swiftc` and `build.sh`

See [tech-stack.md](./tech-stack.md) for full reasoning and details.

## Prerequisites

- macOS with Swift toolchain (`swiftc`) available.
- Daily Helper Hub repository available locally.
- Hub gateway and DB runtime available locally.

## Getting Started (5-Minute Run)

```bash
# 1) Start backend dependency (Terminal 1)
cd "/Users/king/Desktop/school files/daily-helper-hub"
python3 hub-db/init_db.py
python3 hub-gateway/server.py
```

```bash
# 2) Build and run PlannerCapture (Terminal 2)
cd "/Users/king/Desktop/school files/PlannerCapture"
./build.sh
open PlannerCapture.app
```

```bash
# 3) Optional: verify gateway API is alive
curl http://127.0.0.1:8765/v1/tasks
```

## Capture Shortcuts

Inside the hotkey popup:

- `!` at start: increase priority and star task.
- `#p0`..`#p4`: explicit priority.
- `#star` or `*`: star task.
- `::`: split `title :: notes`.
- `/done <title>`: create done task.
- `/todo <title>`: create todo task.
- `/inbox <title>`: create waiting task.
- `/blocked <title>` or `/block <title>`: blocked task.
- `/inprogress <title>`: in-progress task.
- `/archived <title>`: archived task.
- `#g:<group-name>`: assign to existing group.

Examples:
- `test task`
- `! call mechanic :: ask for quote`
- `#p4 study for monday exam :: review chapter 3`
- `/done submit article review`
- `/inbox review lecture slides #g:School`

## Configuration and Environment

PlannerCapture uses persisted settings rather than `.env` files.

Settings file location:
- `~/Library/Application Support/PlannerCapture/settings.json`

Log file location:
- `~/Library/Logs/PlannerCapture/plannercapture.log`

### Runtime Settings / "Env" Table

| Key | Purpose | Example | Required |
|---|---|---|---|
| `gatewayURL` | Hub API base URL | `http://127.0.0.1:8765` | Yes |
| `apiToken` | Optional Bearer token | `abc123` | No |
| `pollVisibleSec` | Poll interval when popover visible | `3` | Yes |
| `pollHiddenSec` | Poll interval when popover hidden | `15` | Yes |
| `defaultStatusRaw` | Default status for created tasks | `inbox` | Yes |
| `immediateOverrideEnabled` | Star/high-priority immediate bucketing | `true` | Yes |
| `mirrorCLI` | Mirror new tasks to planner CLI | `false` | No |
| `logLevelRaw` | Minimum log level | `info` | Yes |
| `showDoneSection` | Show/hide done section | `true` | Yes |
| `showWaitingSection` | Show/hide waiting section | `true` | Yes |
| `defaultSortModeRaw` | Default sorting behavior | `smart` | Yes |
| `defaultGroupViewRaw` | Grouping layout mode | `bucket` | Yes |
| `starClickImmediateSave` | Immediate star persistence toggle | `true` | Yes |
| `compactRowDensity` | Task row compact density | `false` | No |
| `defaultGroupId` | Default group for new tasks | `<group-id>` | No |
| `visibleGroupIds` | Filtered visible groups | `group1,group2` | No |
| `newUIEnabled` | Toggle modern planner UI | `true` | Yes |

## Available Commands

| Command | What it does |
|---|---|
| `./build.sh` | Builds `PlannerCapture.app` and compiles all Swift sources |
| `open PlannerCapture.app` | Launches PlannerCapture |
| `curl http://127.0.0.1:8765/v1/tasks` | Quick gateway health/data check |

## Project Structure (Quick View)

```text
Sources/
├── PlannerCaptureApp.swift          # App startup, notification setup, hotkey registration
├── Models.swift                     # Domain models, GatewayClient, TaskStore
├── FloatingWindowController.swift   # Hotkey panel and capture parsing
├── MenuBarManager.swift             # Menubar popover and quick task controls
├── PlannerWindowController.swift    # Main planner manager window
├── SettingsStore.swift              # Settings persistence and sanitization
├── SettingsWindowController.swift   # Settings UI tabs
├── PlannerLogger.swift              # File logger and diagnostics helpers
├── GlobalHotkey.swift               # Carbon hotkey registration
├── CLIWrapper.swift                 # Optional planner CLI mirror
└── UIPrimitives.swift               # Shared UI tokens/components
```

See [architecture.md](./architecture.md) for complete structure and interactions.

## Troubleshooting

- Disconnected status: verify hub gateway is running and `gatewayURL` is correct.
- No tasks visible: run `curl http://127.0.0.1:8765/v1/tasks`.
- Hotkey not working: verify macOS Accessibility permissions.
- Use **Logs** in menubar or **Open logs** in settings.
- Use **Copy last error** in settings for quick diagnostics payload.

## Contributing

- Follow architecture and placement conventions in [architecture.md](./architecture.md).
- Follow AI/developer operating rules in [CLAUDE.md](./CLAUDE.md).
- Update docs when behavior or architecture changes:
  - `progress.md` for status changes
  - `tech-stack.md` for dependency/runtime changes
  - `SPEC.md` for feature behavior changes

## License

No license file is currently present in this repository.


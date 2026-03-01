# PlannerCapture

PlannerCapture is a macOS menubar + global capture app that now reads/writes tasks through Daily Helper Hub.

## What Changed

- Task source is now the hub gateway (`http://127.0.0.1:8765` by default).
- Menubar list refreshes automatically using sequence polling.
- Plain capture text defaults to `Waiting` (`inbox`) status.
- Tasks are grouped into `Immediate`, `This Week`, `Other`, `Waiting`, and `Done`.
- Row stars are directly clickable and save immediately.
- Capture box supports terminal-style shortcuts for status, priority, stars, and notes.
- Persistent app logs are written to `~/Library/Logs/PlannerCapture/plannercapture.log`.
- A settings window is available from the menubar popover.
- A standalone planner manager window is available from the menubar popover.

## Capture Shortcuts

Type inside the hotkey popup (`Cmd+Shift+Space`):

- `!` at start: boost priority and star.
- `#p0`..`#p4`: set priority explicitly.
- `#star` or `*`: star task.
- `::`: split title and notes.
- `/done <title>`: create completed task.
- `/block <title>`: create blocked task.
- `/inprogress <title>`: create in-progress task.

Examples:

- `test task` (lands in Waiting by default)
- `! call mechanic :: ask for quote`
- `#p4 study for monday exam :: review chapter 3`
- `/done submit article review`

## Prerequisites

- Daily Helper Hub DB + gateway running.
- macOS with Swift toolchain.

## Build

```bash
cd "/Users/king/Desktop/school files/PlannerCapture"
./build.sh
```

## Run with Hub

In terminal 1 (hub):

```bash
cd "/Users/king/Desktop/school files/daily-helper-hub"
python3 hub-db/init_db.py
python3 hub-gateway/server.py
```

In terminal 2 (PlannerCapture):

```bash
cd "/Users/king/Desktop/school files/PlannerCapture"
./build.sh
open PlannerCapture.app
```

Configure runtime options in **Settings** from the menubar:

- Gateway URL
- Gateway API token
- Visible/hidden polling intervals
- Default new-task status
- Immediate override behavior
- CLI mirror toggle
- Log level
- Show/hide Waiting and Done sections
- Default sort mode (`Smart`, `Due Date`, `Priority`, `Recently Updated`)
- Default group view (`Bucket`, `Group -> Bucket`, `Bucket -> Group`)
- Star click behavior
- Compact row density
- Default group ID and visible group ID filters

Open **Planner** from the menubar for the v2 manager window:

- Sidebar sections with task counts.
- Section task list with complete/undo behavior.
- Edit panel for title, notes, status, due date, priority, star, and group.
- Explicit Save for reliable updates.

## Troubleshooting

- Menubar says waiting/error: confirm gateway is running and reachable.
- No tasks showing: run `curl http://127.0.0.1:8765/v1/tasks` to verify API data.
- Hotkey not working: verify Accessibility permission for PlannerCapture.
- Use **Logs** button in popover to open `plannercapture.log` for detailed errors.
- Use **Copy Last Error** in settings to copy recent warning/error lines to clipboard.
- Correlate failures by request ID:
  - PlannerCapture logs include `request_id`.
  - Gateway responses include `request_id` and `X-Request-Id`.
  - Gateway logs are at `~/Library/Logs/daily-helper-hub/gateway.log`.

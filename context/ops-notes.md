# Operations Notes

## Local Runtime Dependencies

1. Daily Helper Hub DB initialization and gateway process must be running.
2. PlannerCapture app built and opened locally.

## Standard Startup Sequence

```bash
# Terminal 1: backend
cd "/Users/king/Desktop/school files/daily-helper-hub"
python3 hub-db/init_db.py
python3 hub-gateway/server.py

# Terminal 2: app
cd "/Users/king/Desktop/school files/PlannerCapture"
./build.sh
open PlannerCapture.app
```

## Health Checks

- Verify gateway: `curl http://127.0.0.1:8765/v1/tasks`
- Verify app logs: open `~/Library/Logs/PlannerCapture/plannercapture.log`
- Verify app connection indicator in menubar/planner header.

## Triage Checklist

1. If disconnected: confirm gateway process and URL in settings.
2. If no tasks: check API endpoint output and JSON format.
3. If hotkey fails: verify accessibility permissions and that app is running.
4. If action fails intermittently: inspect request IDs and compare with gateway logs.

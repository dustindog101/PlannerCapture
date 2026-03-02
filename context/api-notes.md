# API Notes (Daily Helper Hub Gateway)

## Base URL
- Default: `http://127.0.0.1:8765`
- Configurable in settings (`gatewayURL`).

## Auth
- Optional bearer token from settings (`apiToken`).
- Header format: `Authorization: Bearer <token>` (only when token is non-empty).

## Request Correlation
- Client sends `X-Request-Id` on every request.
- Response may return `X-Request-Id` for correlation.
- App logs both IDs where available.

## Endpoints Used by PlannerCapture

- `GET /v1/meta/seq`
- `GET /v1/tasks?limit=<n>`
- `POST /v1/tasks`
- `PATCH /v1/tasks/{id}`
- `POST /v1/tasks/{id}/complete`
- `POST /v1/tasks/{id}/archive`
- `GET /v1/groups`
- `POST /v1/groups`
- `PATCH /v1/groups/{id}`
- `POST /v1/groups/{id}/archive`

## Payload Notes

### Task create payload fields
- `title` (String)
- `notes` (String)
- `status` (String enum)
- `priority` (Int 0..4)
- `is_starred` (0/1)
- `source` (String)
- `group_id` (nullable)
- `source_ref` (nullable)

### Task patch payload fields from editor
- `title`, `notes`, `status`, `priority`, `is_starred`, `group_id`, `due_at`, `source_ref`.

## Error Handling Expectations in Client

- Timeouts and transport errors mark store disconnected and increase poll backoff.
- HTTP status outside 2xx is logged with body snippet.
- HTTP 404 during action can indicate stale local task and trigger local eviction + refresh.

## Open Contract Questions

- ⚠️ Confirm whether gateway guarantees stable response schema across versions.
- ⚠️ Confirm exact semantics for `archived` vs `done` visibility and retention.


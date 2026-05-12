# Task Calendar Storage Migration — TODO

## Current State
- Task calendar (`modules/task-calendar.html`) stores everything in **browser localStorage**
- Keys: `pof2828_tasks`, `pof2828_projects`, `pof2828_summaries`, `pof2828_prefs`
- Seed blocks in HTML inject tasks on page load (growing fast — 50+ entries per day)
- localStorage cap: ~5-10MB, will hit wall in weeks at current pace

## Problem
- localStorage is browser-only — no cross-session access for AI agents
- Seed blocks in HTML keep growing (bad pattern)
- No backup/export — clear browser cache = lose everything

## Planned Solution: SQLite via sync_server.py
- Add `tasks.db` (SQLite) in `config/` folder alongside `storage.json`
- Python `sqlite3` is built-in, zero dependencies
- Add REST endpoints to `sync_server.py` (port 3456):
  - `GET /api/tasks` — list tasks (with date/project filters)
  - `POST /api/tasks` — create task
  - `PUT /api/tasks/<id>` — update task
  - `DELETE /api/tasks/<id>` — delete task
  - `GET /api/tasks/export` — dump all as JSON (backup)
- Update `task-calendar.html`:
  - Replace localStorage reads/writes with fetch() calls to sync server
  - Remove seed blocks from HTML (migrate to DB one-time)
  - Keep localStorage as offline fallback if server unreachable
- Benefits:
  - Unlimited storage
  - AI agents can read/write tasks via HTTP
  - Backup = copy one .db file
  - Query by date, project, priority, done status via SQL

## Migration Steps
1. Create `config/tasks.db` with schema (tasks, projects, summaries tables)
2. Add endpoints to `sync_server.py`
3. Write one-time migration: seed blocks → DB rows
4. Update calendar HTML to use fetch() API
5. Test offline fallback
6. Remove seed blocks from HTML

## Notes
- Existing sync_server.py already uses `config/storage.json` pattern — follow same convention
- Keep task-calendar.html working standalone (offline mode) as fallback
- Date: 2026-03-21 — flagged for next available session

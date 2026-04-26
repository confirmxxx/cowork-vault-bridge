# Changelog

## v1.1.0 — 2026-04-26

Event-driven watcher closes the 24h staleness gap left by the daily-only refresh.

**Added**
- `watchers/watch-vault.ps1` — persistent PowerShell FileSystemWatcher. Watches `$Config.VaultRoot/$Config.BrainFolder` recursively for `*.md` changes. Debounces 30s after the last save, then runs `cowork-refresh.ps1`. Ignores swap/temp/lock files (`.swp`, `.tmp`, `.crswap`, `~$`, `.md~`).
- `watchers/install-watcher.ps1` — registers the watcher as a Scheduled Task at user logon. Hidden window, `RunLevel Limited` (no admin needed), restart-on-failure 3× at 1-min intervals, `MultipleInstances IgnoreNew`.
- `watchers/uninstall-watcher.ps1` — removes the task and kills any leftover watcher processes via `Get-CimInstance Win32_Process` filter.
- `watchers/watch-status.ps1` — task state, watcher process check, snapshot age (color-coded: green ≤5m, yellow ≤60m, red older), tail of last 25 log lines.

**Changed**
- `config.ps1` — added `WatcherTaskName`, `DebounceSec`, `PollIntervalSec`.
- `watchers/README.md` — full v1.1.0 docs: rationale for FileSystemWatcher over Python watchdog / Task Scheduler events / Obsidian shellcommands; install/verify/uninstall flow; tuning notes.
- Root `README.md` — documented the dual-refresh model (recommend running both daily + watcher), expanded config table, updated file structure tree.

**Design notes**
- Synchronized hashtable for thread-safe state between the FileSystemWatcher event runspace and the main poll loop.
- Initial catch-up refresh on watcher start covers the gap if the vault changed while the watcher was down.
- Self-trigger loop is impossible: log + snapshot writes go to `~/.claude/`, outside the watch path.
- Recommended to keep the daily refresh as a safety net — if the watcher dies and exhausts its 3 restart attempts, the daily job catches the gap.

## v1.0.0 — 2026-04-26
- Initial release
- Daily snapshot of obsidian-mind brain/ → CLAUDE.md via Task Scheduler
- Extracts: Active Projects, North Star, last 10 Key Decisions, Gotchas, External Tool Access
- install.ps1 one-command setup (daily + at-logon triggers)
- uninstall.ps1 cleanup
- config.ps1 separates user config from logic
- Logging with auto-trim to MaxLogLines

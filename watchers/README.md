# Watchers

Event-driven triggers that replace the 24h Task Scheduler polling with instant refresh on vault save.

## Status

`watch-vault.ps1` — **pending implementation** (Opus 4.7, 2026-04-26)

## When complete

The watcher should:
1. Watch `brain/*.md` for file changes
2. Debounce 30s after last change
3. Call `../cowork-refresh.ps1 -ConfigPath ../config.ps1`
4. Log each trigger to `$Config.LogFile`
5. Survive Obsidian restarts (run as persistent background process or Task Scheduler event)

## Install (once implemented)

```powershell
.\watch-vault.ps1 -ConfigPath ..\config.ps1
```

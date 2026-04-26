# Watchers

Event-driven triggers that close the 24h staleness gap left by the daily Task Scheduler refresh.

## What's here

- `watch-vault.ps1` — persistent FileSystemWatcher. Fires `cowork-refresh.ps1` 30s after the last save in `brain/`.
- `install-watcher.ps1` — registers the watcher as a Scheduled Task that auto-starts at logon.
- `uninstall-watcher.ps1` — removes the task and kills any running watcher process.
- `watch-status.ps1` — health check + snapshot freshness + tail of the log.

## Why FileSystemWatcher

Of the four candidate approaches the v1.0 README listed:

| Approach | Why not |
|---|---|
| Python `watchdog` | Adds a runtime dep for no reliability gain over .NET FSW |
| Task Scheduler "on event" | Fires on Windows Event Log entries, not file changes — would need SACL auditing enabled (heavy) |
| Obsidian `shellcommands` plugin | Only fires when Obsidian is the editor; misses git pulls, VS Code edits, Claude Code writes from WSL |
| **PowerShell FileSystemWatcher** | Native, catches every write regardless of source, no extra deps, ~130 lines |

## Install

```powershell
# from repo root, after editing ../config.ps1
cd watchers
.\install-watcher.ps1
```

The installer:
1. Removes any existing watcher task and kills orphan processes
2. Registers a Scheduled Task that runs `watch-vault.ps1` at user logon (hidden window, no admin needed)
3. Configures restart-on-failure (3 retries at 1-min intervals)
4. Starts the task immediately

## Verify

```powershell
.\watch-status.ps1
```

Then edit any `brain/*.md` file in your vault, save, wait ~35 seconds, re-run status. The "Last snapshot" timestamp should jump to "now" and the log should show a `Debounce elapsed` line.

## Test interactively (before installing as a task)

```powershell
# Foreground, visible window — Ctrl+C to stop
.\watch-vault.ps1
```

You'll see the catch-up refresh fire, then live log lines as you edit `brain/*.md` files.

## Uninstall

```powershell
.\uninstall-watcher.ps1
```

The daily refresh task installed by the root `install.ps1` is left in place — keep it as a belt-and-suspenders safety net in case the watcher dies between Task Scheduler restart attempts.

## Tuning

In `../config.ps1`:

| Key | Default | Purpose |
|---|---|---|
| `WatcherTaskName` | `CoworkVaultBridgeWatcher` | Scheduled Task name |
| `DebounceSec` | `30` | Wait this long after the last save before refreshing |
| `PollIntervalSec` | `3` | How often the watcher checks the debounce timer |

If you want vault-wide watching instead of just `brain/`, edit `watch-vault.ps1` and change `$WatchPath = Join-Path $Config.VaultRoot $Config.BrainFolder` to `$WatchPath = $Config.VaultRoot`.

## Self-trigger loop is impossible

The watcher's log goes to `$Config.LogFile` (outside the vault) and the refresh writes to `$Config.ClaudeMd` (also outside the vault). Neither falls under the watch path, so the watcher cannot trigger itself.

# cowork-vault-bridge

Bridges your **obsidian-mind** vault with **Claude Cowork**, giving every Cowork session live context from your second brain — active projects, north star goals, recent decisions, gotchas, and tool access — without any manual copy-paste.

Built for the obsidian-mind stack. Works on Windows, no admin rights required.

---

## What it does

`cowork-refresh.ps1` reads your vault's `brain/` folder and injects a snapshot between `<!-- COWORK-CONTEXT-START -->` / `<!-- COWORK-CONTEXT-END -->` markers in `C:\Users\HP\.claude\CLAUDE.md`. Cowork auto-loads that file at session start, so every conversation begins with fresh context.

Two refresh paths:

- **Daily snapshot** via Task Scheduler (root `install.ps1`) — guaranteed catch-up at the configured time.
- **Event-driven watcher** (`watchers/install-watcher.ps1`) — fires within ~30s of any `brain/*.md` save. Closes the staleness gap. **Recommended to run both** — the daily job is a safety net if the watcher dies.

---

## Requirements

- Windows 10/11
- PowerShell 5.1+
- An obsidian-mind vault at the path in `config.ps1`
- `C:\Users\HP\.claude\CLAUDE.md` must exist (Cowork creates it on first run)

---

## Install

```powershell
# 1. Clone or copy this folder anywhere accessible
# 2. Edit config.ps1 — set VaultRoot and ClaudeMd to your actual paths
# 3. Run install.ps1 from PowerShell:

cd "<path-to-this-folder>"
.\install.ps1                                # daily refresh
.\watchers\install-watcher.ps1               # event-driven watcher (recommended)
```

Both scripts validate paths, register a Scheduled Task, and run the first refresh immediately.

---

## Upgrade

```powershell
# Pull latest, re-run install (idempotent — updates the existing tasks)
.\install.ps1
.\watchers\install-watcher.ps1
```

---

## Uninstall

```powershell
.\watchers\uninstall-watcher.ps1
.\uninstall.ps1
```

Removes the Task Scheduler jobs. Does not touch your vault or CLAUDE.md content.

---

## Manual refresh

```powershell
.\cowork-refresh.ps1
```

---

## Configuration

All user-editable settings are in `config.ps1`:

| Key | Default | Purpose |
|-----|---------|---------|
| `VaultRoot` | `C:\Users\HP\Documents\obsidian-mind` | Root of your Obsidian vault |
| `ClaudeMd` | `C:\Users\HP\.claude\CLAUDE.md` | Cowork context file |
| `BrainFolder` | `brain` | Subfolder inside vault containing brain notes |
| `LogFile` | `C:\Users\HP\.claude\cowork-bridge.log` | Refresh + watcher log |
| `MaxLogLines` | `300` | Auto-trim threshold |
| `TaskName` | `CoworkVaultBridge` | Daily-refresh Scheduled Task name |
| `TriggerTime` | `08:00` | Daily run time |
| `WatcherTaskName` | `CoworkVaultBridgeWatcher` | Watcher Scheduled Task name |
| `DebounceSec` | `30` | Wait this long after last save before refreshing |
| `PollIntervalSec` | `3` | How often the watcher checks the debounce timer |

---

## File structure

```
cowork-bridge/
├── config.ps1                    # user config — edit this
├── cowork-refresh.ps1            # main snapshot script
├── install.ps1                   # daily-refresh setup
├── uninstall.ps1                 # daily-refresh cleanup
├── CHANGELOG.md
├── .gitignore
└── watchers/                     # v1.1.0 — event-driven layer
    ├── watch-vault.ps1           # FileSystemWatcher
    ├── install-watcher.ps1       # register at-logon Scheduled Task
    ├── uninstall-watcher.ps1     # remove task + kill orphan processes
    ├── watch-status.ps1          # health check + log tail
    └── README.md
```

---

## Roadmap

- **v1.2.0** — Cross-project knowledge retrieval: slash command that wraps QMD search and buckets results by project subfolder/frontmatter, so patterns across projects surface automatically instead of requiring manual cross-search.

---

## How it fits the stack

```
obsidian-mind vault (brain/)
        │
        ├── on save  ──►  watchers/watch-vault.ps1  (debounce 30s)
        │                         │
        ├── 08:00 daily ──►  cowork-refresh.ps1
        │                         │
        ▼                         ▼
C:\Users\HP\.claude\CLAUDE.md  (snapshot between markers)
        │
        ▼  auto-loaded by Cowork at session start
Every Cowork conversation ← knows your projects, goals, decisions
```

Claude Code reads the vault directly via WSL mount. Cowork reads the snapshot. Both surfaces share the same second brain.

# cowork-vault-bridge

Bridges your **obsidian-mind** vault with **Anthropic Cowork**, giving every Cowork session live context from your second brain — active projects, north star goals, recent decisions, gotchas, and tool access — without any manual copy-paste.

Built for the Tristar AGS / obsidian-mind stack. Works on Windows, no admin rights required.

---

## What it does

`cowork-refresh.ps1` reads your vault's `brain/` folder and injects a snapshot between `<!-- COWORK-CONTEXT-START -->` / `<!-- COWORK-CONTEXT-END -->` markers in `C:\Users\HP\.claude\CLAUDE.md`. Cowork auto-loads that file at session start, so every conversation begins with fresh context.

Runs daily via Task Scheduler. Event-driven watcher (closes the staleness gap) lives in `watchers/` — see status there.

---

## Requirements

- Windows 10/11
- PowerShell 5.1+
- An obsidian-mind vault at the path in `config.ps1`
- `C:\Users\HP\.claude\CLAUDE.md` must exist (Cowork creates it on first run)

---

## Install

```powershell
# 1. Clone or copy this folder anywhere accessible (e.g. inside your vault)
# 2. Edit config.ps1 — set VaultRoot and ClaudeMd to your actual paths
# 3. Run install.ps1 from PowerShell:

cd "C:\Users\HP\Documents\obsidian-mind\tools\cowork-bridge"
.\install.ps1
```

That's it. The script validates paths, registers Task Scheduler (daily + at-logon), and runs the first refresh immediately.

---

## Upgrade

```powershell
# Pull latest, re-run install (idempotent — updates the existing task)
.\install.ps1
```

---

## Uninstall

```powershell
.\uninstall.ps1
```

Removes the Task Scheduler job. Does not touch your vault or CLAUDE.md content.

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
| `LogFile` | `C:\Users\HP\.claude\cowork-bridge.log` | Refresh log |
| `MaxLogLines` | `300` | Auto-trim threshold |
| `TaskName` | `CoworkVaultBridge` | Task Scheduler job name |
| `TriggerTime` | `08:00` | Daily run time |

---

## File structure

```
cowork-bridge/
├── config.ps1              # user config — edit this
├── cowork-refresh.ps1      # main snapshot script
├── install.ps1             # one-command setup
├── uninstall.ps1           # cleanup
├── CHANGELOG.md
├── .gitignore
└── watchers/
    ├── watch-vault.ps1     # event-driven watcher (pending v1.1.0)
    └── README.md
```

---

## Roadmap

- **v1.1.0** — `watch-vault.ps1`: FileSystemWatcher or Python watchdog that fires refresh on brain/ file save, debounced 30s. Closes the 24h staleness gap.
- **v1.2.0** — Vector embeddings integration: cross-project knowledge retrieval across ATLAS/AlfardZip/Verso patterns.

---

## How it fits the stack

```
obsidian-mind vault (brain/)
        │
        ▼  cowork-refresh.ps1 (daily + on-save in v1.1)
C:\Users\HP\.claude\CLAUDE.md
        │
        ▼  auto-loaded by Cowork at session start
Every Cowork conversation ← knows your projects, goals, decisions
```

Claude Code reads the vault directly via WSL mount. Cowork reads the snapshot. Both surfaces share the same second brain.

# cowork-vault-bridge

Bidirectional bridge between your **obsidian-mind** vault and **Claude Cowork**. Every Cowork session starts with live context from your second brain — active projects, north star goals, recent decisions, gotchas, tool access. And Claude can write targeted updates back to designated vault notes without touching anything else.

Built for the obsidian-mind stack. Works on Windows, no admin rights required.

---

## What it does

### Read path — vault → Cowork

`cowork-refresh.ps1` reads your vault's `brain/` folder and injects a snapshot between `<!-- COWORK-CONTEXT-START -->` / `<!-- COWORK-CONTEXT-END -->` markers in `~\.claude\CLAUDE.md`. Cowork auto-loads that file at session start, so every conversation begins with fresh context.

Two refresh paths:

- **Daily snapshot** via Task Scheduler (`install.ps1`) — guaranteed catch-up at the configured time.
- **Event-driven watcher** (`watchers/install-watcher.ps1`) — fires within ~30s of any `brain/*.md` save. Closes the staleness gap. **Recommended to run both** — the daily job is a safety net if the watcher dies.

### Write path — Cowork → vault

`cowork-write.ps1` lets Claude write targeted content back to vault notes. Safety gates prevent unintended changes:

- **Opt-in only** — a note must contain `<!-- CLAUDE-WRITABLE -->` or the script exits 1 immediately.
- **Auto-backup** — every write creates a `.bak` before touching the file.
- **Atomic write** — content is written to a `.tmp` then renamed; a crash mid-write leaves the original intact.

Two write modes:

- **`append`** — adds content to the end of the note.
- **`section`** — creates or replaces a named `<!-- CLAUDE-SECTION-START: name -->` / `<!-- CLAUDE-SECTION-END: name -->` block. Idempotent: re-running replaces the block rather than appending a second one.

```powershell
# append a new entry to a note
.\cowork-write.ps1 -TargetNote "perf\Brag Doc.md" -Content "..." -Mode append

# create or replace a named section
.\cowork-write.ps1 -TargetNote "brain\North Star.md" -Content "..." -Mode section -SectionName "Claude Updates"
```

---

## Requirements

- Windows 10/11
- PowerShell 5.1+
- An obsidian-mind vault at the path set in `config.ps1`
- `~\.claude\CLAUDE.md` must exist (Cowork creates it on first run)

---

## Install

```powershell
# 1. Clone anywhere accessible
# 2. Edit config.ps1 — set VaultRoot and ClaudeMd to your actual paths
# 3. Run:

cd "<path-to-this-folder>"
.\install.ps1                                # daily refresh (Task Scheduler)
.\watchers\install-watcher.ps1               # event-driven watcher (recommended)
```

Both scripts validate paths, register a Scheduled Task, and run the first refresh immediately. No admin rights needed.

---

## Upgrade

```powershell
# Fetch latest — review the diff before merging (see Security below)
git fetch origin
git diff HEAD origin/main
git merge origin/main

# Re-run install to update existing tasks (idempotent)
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
| `BrainFolder` | `brain` | Subfolder watched for changes and read on refresh |
| `LogFile` | `C:\Users\HP\.claude\cowork-bridge.log` | Refresh + watcher log |
| `MaxLogLines` | `300` | Auto-trim threshold |
| `TaskName` | `CoworkVaultBridge` | Daily-refresh Scheduled Task name |
| `TriggerTime` | `08:00` | Daily run time (24h) |
| `WatcherTaskName` | `CoworkVaultBridgeWatcher` | Watcher Scheduled Task name |
| `DebounceSec` | `30` | Quiet period after last save before refreshing |
| `PollIntervalSec` | `3` | How often the watcher checks the debounce timer |

---

## Making a note writable

Add the marker anywhere in the note (recommended: right after frontmatter):

```markdown
---
tags: [perf]
---

<!-- CLAUDE-WRITABLE -->

# My Note
```

Without this marker, `cowork-write.ps1` will not touch the file.

For section-mode writes, also add the section markers where you want the block to live (optional — the script creates them at end-of-file if absent):

```markdown
<!-- CLAUDE-SECTION-START: Claude Updates -->
<!-- CLAUDE-SECTION-END: Claude Updates -->
```

---

## File structure

```
cowork-bridge/
├── config.ps1                    # user config — edit this
├── cowork-refresh.ps1            # read path: vault → CLAUDE.md snapshot
├── cowork-write.ps1              # write path: Cowork → vault notes
├── install.ps1                   # daily-refresh Task Scheduler setup
├── uninstall.ps1                 # daily-refresh cleanup
├── CHANGELOG.md
├── .gitignore
└── watchers/                     # event-driven layer (v1.1.0+)
    ├── watch-vault.ps1           # FileSystemWatcher + debounce loop
    ├── install-watcher.ps1       # register at-logon Scheduled Task
    ├── uninstall-watcher.ps1     # remove task + kill orphan processes
    ├── watch-status.ps1          # health check + log tail
    └── README.md
```

---

## Security

This repo feeds directly into `CLAUDE.md`, which Cowork loads at session start. Treat it as a trusted surface:

- **Do not set an upstream tracking branch on `main`.** A silent `git pull` = potential prompt injection from a compromised or force-pushed remote. Use the fetch → review → merge flow above.
- **Tag known-good state** after each upgrade: `git tag known-good-YYYY-MM-DD`
- The `<!-- CLAUDE-WRITABLE -->` marker is the only thing standing between Claude and an arbitrary vault note — add it deliberately.

---

## Roadmap

- **v1.2.0** — Cross-project knowledge retrieval: slash command wrapping QMD search, results bucketed by project subfolder/frontmatter, so patterns across projects surface automatically.

---

## How it fits the stack

```
obsidian-mind vault
        │
        ├── brain/ saves  ──►  watch-vault.ps1 (debounce 30s)  ──►  cowork-refresh.ps1
        ├── 08:00 daily   ──────────────────────────────────────►  cowork-refresh.ps1
        │                                                                   │
        │                                                                   ▼
        │                                               ~\.claude\CLAUDE.md (snapshot)
        │                                                                   │
        │                                                    auto-loaded by Cowork
        │                                                                   │
        │◄──────────── cowork-write.ps1 (marker-gated) ◄── Claude (Cowork session)
        │
        ▼
vault notes updated in place (Brag Doc, North Star, etc.)
```

Claude Code reads the vault directly via WSL mount. Cowork reads the CLAUDE.md snapshot and writes back via `cowork-write.ps1`. Both surfaces share the same second brain.

# cowork-vault-bridge — user configuration
# Edit these to match your machine. Everything else reads from here.

$Config = @{
    VaultRoot        = "C:\Users\HP\Documents\obsidian-mind"
    ClaudeMd         = "C:\Users\HP\.claude\CLAUDE.md"
    BrainFolder      = "brain"                             # relative to VaultRoot
    LogFile          = "C:\Users\HP\.claude\cowork-bridge.log"
    MaxLogLines      = 300                                 # trim log after this many lines
    TaskName         = "CoworkVaultBridge"                 # daily-refresh Task Scheduler job
    TriggerTime      = "08:00"                             # daily run time (24h)

    # ---- v1.1.0 watcher ----
    WatcherTaskName  = "CoworkVaultBridgeWatcher"          # event-driven watcher Task Scheduler job
    DebounceSec      = 30                                  # wait this long after last save before refreshing
    PollIntervalSec  = 3                                   # how often the watcher checks the debounce timer
}

# cowork-vault-bridge — user configuration
# Edit these to match your machine. Everything else reads from here.

$Config = @{
    VaultRoot   = "C:\Users\HP\Documents\obsidian-mind"
    ClaudeMd    = "C:\Users\HP\.claude\CLAUDE.md"
    BrainFolder = "brain"                             # relative to VaultRoot
    LogFile     = "C:\Users\HP\.claude\cowork-bridge.log"
    MaxLogLines = 300                                 # trim log after this many lines
    TaskName    = "CoworkVaultBridge"                 # Windows Task Scheduler job name
    TriggerTime = "08:00"                             # daily run time (24h)
}

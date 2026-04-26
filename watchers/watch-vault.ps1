# watchers/watch-vault.ps1  v1.1.0
# Event-driven watcher: fires cowork-refresh.ps1 on vault brain/*.md changes.
# Closes the 24h staleness gap that the daily Task Scheduler refresh leaves open.
#
# Run via Task Scheduler (install-watcher.ps1) or interactively for debugging:
#   .\watch-vault.ps1
#
# Started by Task Scheduler at user logon, runs persistently.

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config.ps1"
)

. $ConfigPath   # dot-source user config -> $Config

$ErrorActionPreference = 'Continue'

$WatchPath     = Join-Path $Config.VaultRoot $Config.BrainFolder
$RefreshScript = Join-Path (Split-Path $PSScriptRoot -Parent) "cowork-refresh.ps1"
$LogPath       = $Config.LogFile
$DebounceSec   = $Config.DebounceSec
$PollSec       = $Config.PollIntervalSec

# ---- Logging (line-count trim, matches cowork-refresh.ps1 pattern) ----
function Write-WatchLog {
    param([string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [watcher] $Message"
    try {
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
        $lines = Get-Content $LogPath -ErrorAction SilentlyContinue
        if ($lines -and $lines.Count -gt $Config.MaxLogLines) {
            $lines | Select-Object -Last $Config.MaxLogLines | Set-Content $LogPath -Encoding UTF8
        }
    } catch {
        Write-Host $line
    }
}

# ---- Sanity checks ----
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

if (-not (Test-Path $WatchPath)) {
    Write-WatchLog "FATAL: watch path missing: $WatchPath"
    exit 1
}
if (-not (Test-Path $RefreshScript)) {
    Write-WatchLog "FATAL: refresh script missing: $RefreshScript"
    exit 1
}

Write-WatchLog "==== Watcher starting ===="
Write-WatchLog "Watch: $WatchPath  Debounce: ${DebounceSec}s  Poll: ${PollSec}s"

# ---- Refresh runner ----
function Invoke-Refresh {
    param([string]$Reason)
    Write-WatchLog "Refresh ($Reason)"
    try {
        $output = & powershell.exe -NoProfile -WindowStyle Hidden `
            -ExecutionPolicy Bypass -File $RefreshScript -ConfigPath $ConfigPath 2>&1
        foreach ($l in $output) { Write-WatchLog "  | $l" }
    } catch {
        Write-WatchLog "ERROR: refresh failed: $($_.Exception.Message)"
    }
}

# ---- Synchronized state for cross-thread access ----
$state = [hashtable]::Synchronized(@{
    LastEvent   = [DateTime]::MinValue
    PendingFire = $false
    LastFile    = ""
    EventCount  = 0
})

# ---- FileSystemWatcher ----
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path                  = $WatchPath
$watcher.Filter                = "*.md"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter          = [System.IO.NotifyFilters]::LastWrite -bor `
                                  [System.IO.NotifyFilters]::FileName -bor `
                                  [System.IO.NotifyFilters]::Size
$watcher.EnableRaisingEvents   = $true

$action = {
    $s    = $Event.MessageData
    $path = $Event.SourceEventArgs.FullPath
    $ct   = $Event.SourceEventArgs.ChangeType
    # Ignore swap/temp/lock files (Obsidian, vim, VS Code patterns)
    if ($path -match '\.(swp|tmp|crswap)$' -or $path -match '~\$' -or $path -match '\.md~$') { return }
    $s.LastEvent   = Get-Date
    $s.PendingFire = $true
    $s.LastFile    = "$path ($ct)"
    $s.EventCount  = $s.EventCount + 1
}

$handlers = @()
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Changed -MessageData $state -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Created -MessageData $state -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Renamed -MessageData $state -Action $action
$handlers += Register-ObjectEvent -InputObject $watcher -EventName Deleted -MessageData $state -Action $action

# Catch up on changes that happened while the watcher was down
Invoke-Refresh -Reason "startup catch-up"

# ---- Main loop ----
try {
    while ($true) {
        Start-Sleep -Seconds $PollSec
        if ($state.PendingFire) {
            $silentFor = ((Get-Date) - $state.LastEvent).TotalSeconds
            if ($silentFor -ge $DebounceSec) {
                $batched = $state.EventCount
                $last    = $state.LastFile
                $state.PendingFire = $false
                $state.EventCount  = 0
                Write-WatchLog "Debounce elapsed (silent ${silentFor}s, batched $batched events). Last: $last"
                Invoke-Refresh -Reason "file change"
            }
        }
    }
}
finally {
    Write-WatchLog "Watcher stopping..."
    foreach ($h in $handlers) {
        try { Unregister-Event -SourceIdentifier $h.Name -ErrorAction SilentlyContinue } catch {}
    }
    try { $watcher.EnableRaisingEvents = $false; $watcher.Dispose() } catch {}
    Write-WatchLog "==== Watcher stopped ===="
}

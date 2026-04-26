# watchers/watch-status.ps1  v1.1.0
# Inspect watcher state, snapshot freshness, and recent log lines.

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config.ps1"
)

. $ConfigPath

$TaskName = $Config.WatcherTaskName
$LogPath  = $Config.LogFile
$ClaudeMd = $Config.ClaudeMd

Write-Host "=== Cowork Bridge Watcher Status ===" -ForegroundColor Cyan
Write-Host ""

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "Task NOT INSTALLED" -ForegroundColor Red
    Write-Host "Install: .\install-watcher.ps1"
    exit 1
}

$info       = Get-ScheduledTaskInfo -TaskName $TaskName
$stateColor = switch ($task.State) { "Running" {"Green"} "Ready" {"Yellow"} default {"Red"} }

Write-Host "Task state:        " -NoNewline; Write-Host $task.State -ForegroundColor $stateColor
Write-Host "Last run:          $($info.LastRunTime)"
Write-Host "Last result:       0x$('{0:X}' -f $info.LastTaskResult)"
Write-Host ""

$proc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watch-vault.ps1*" }
if ($proc) {
    Write-Host "Watcher process:   " -NoNewline
    Write-Host "RUNNING (PID $($proc.ProcessId))" -ForegroundColor Green
} else {
    Write-Host "Watcher process:   " -NoNewline
    Write-Host "NOT RUNNING" -ForegroundColor Red
    Write-Host "  Try: Start-ScheduledTask -TaskName $TaskName"
}
Write-Host ""

if (Test-Path $ClaudeMd) {
    $content = Get-Content $ClaudeMd -Raw
    if ($content -match "Auto-refreshed:\s*(\S+\s+\S+)") {
        $stamp  = $Matches[1]
        try {
            $age = [int](((Get-Date) - [DateTime]::Parse($stamp)).TotalMinutes)
            $col = if ($age -le 5) {"Green"} elseif ($age -le 60) {"Yellow"} else {"Red"}
            Write-Host "Last snapshot:     $stamp " -NoNewline
            Write-Host "(${age}m ago)" -ForegroundColor $col
        } catch {
            Write-Host "Last snapshot:     $stamp"
        }
    }
}
Write-Host ""

if (Test-Path $LogPath) {
    $sizeKb = [math]::Round((Get-Item $LogPath).Length / 1KB, 1)
    Write-Host "=== Last 25 log lines (${sizeKb}KB total) ===" -ForegroundColor Cyan
    Get-Content $LogPath -Tail 25
} else {
    Write-Host "Log file not found yet." -ForegroundColor Yellow
}

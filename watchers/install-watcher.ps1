# watchers/install-watcher.ps1  v1.1.0
# Registers watch-vault.ps1 as a Scheduled Task that runs at user logon.
#   .\install-watcher.ps1

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config.ps1"
)

. $ConfigPath

$WatcherScript = "$PSScriptRoot\watch-vault.ps1"
$TaskName      = $Config.WatcherTaskName

if (-not (Test-Path $WatcherScript)) {
    Write-Error "Watcher not found at $WatcherScript"
    exit 1
}

# Remove existing task if present
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Kill any leftover watcher processes
$leftover = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watch-vault.ps1*" }
foreach ($p in $leftover) {
    Write-Host "Stopping leftover watcher PID $($p.ProcessId)" -ForegroundColor Yellow
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -NonInteractive -File `"$WatcherScript`" -ConfigPath `"$ConfigPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 365) `
    -Hidden `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Watches vault BrainFolder for *.md changes and refreshes the Cowork CLAUDE.md snapshot (debounced $($Config.DebounceSec)s). Complements the daily refresh." | Out-Null

Write-Host "Task '$TaskName' registered." -ForegroundColor Green
Write-Host "Starting now..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName

Start-Sleep -Seconds 3
$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host ""
Write-Host "  State:       $($task.State)"
Write-Host "  Last run:    $($info.LastRunTime)"
Write-Host "  Last result: 0x$('{0:X}' -f $info.LastTaskResult)"
Write-Host ""
Write-Host "Log:    $($Config.LogFile)" -ForegroundColor Gray
Write-Host "Status: .\watch-status.ps1" -ForegroundColor Gray

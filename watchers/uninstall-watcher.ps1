# watchers/uninstall-watcher.ps1  v1.1.0
# Removes the watcher Scheduled Task and stops any running watcher processes.

param(
    [string]$ConfigPath = "$PSScriptRoot\..\config.ps1"
)

. $ConfigPath

$TaskName = $Config.WatcherTaskName

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Task '$TaskName' removed." -ForegroundColor Green
} else {
    Write-Host "Task '$TaskName' not found." -ForegroundColor Yellow
}

$watchers = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watch-vault.ps1*" }
foreach ($w in $watchers) {
    Write-Host "Killing orphan watcher PID $($w.ProcessId)" -ForegroundColor Yellow
    Stop-Process -Id $w.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host "Done."

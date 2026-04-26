# uninstall.ps1
# Removes the daily-refresh Task Scheduler job AND the watcher task (if installed).
# Does NOT touch CLAUDE.md or vault files.

param(
    [string]$ConfigPath = "$PSScriptRoot\config.ps1"
)

. $ConfigPath

foreach ($name in @($Config.TaskName, $Config.WatcherTaskName)) {
    if (-not $name) { continue }
    if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
        try { Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue } catch {}
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Host "Removed Task Scheduler job '$name'" -ForegroundColor Green
    } else {
        Write-Host "Task '$name' not found — nothing to remove" -ForegroundColor Yellow
    }
}

# Stop any orphan watcher processes
$watchers = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*watch-vault.ps1*" }
foreach ($w in $watchers) {
    Write-Host "Killing orphan watcher PID $($w.ProcessId)" -ForegroundColor Yellow
    Stop-Process -Id $w.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host "Uninstall complete. CLAUDE.md context block left in place — remove manually if needed." -ForegroundColor Gray

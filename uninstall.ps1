# uninstall.ps1
# Removes the Task Scheduler job. Does NOT touch CLAUDE.md or vault files.

param(
    [string]$ConfigPath = "$PSScriptRoot\config.ps1"
)

. $ConfigPath

$taskName = $Config.TaskName

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed Task Scheduler job '$taskName'" -ForegroundColor Green
} else {
    Write-Host "Task '$taskName' not found — nothing to remove" -ForegroundColor Yellow
}

# Stop watcher if running
$watcherJob = Get-Job -Name "CoworkVaultWatcher" -ErrorAction SilentlyContinue
if ($watcherJob) {
    Stop-Job $watcherJob
    Remove-Job $watcherJob
    Write-Host "Stopped vault watcher job" -ForegroundColor Green
}

Write-Host "Uninstall complete. CLAUDE.md context block left in place — remove manually if needed." -ForegroundColor Gray

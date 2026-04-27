# install.ps1  v1.0.0
# One-command setup: validates paths, registers Task Scheduler job, runs first refresh.
# Run once from PowerShell (no admin required for current-user tasks):
#   .\install.ps1

param(
    [string]$ConfigPath = "$PSScriptRoot\config.ps1"
)

. $ConfigPath

$refreshScript = "$PSScriptRoot\cowork-refresh.ps1"

Write-Host ""
Write-Host "cowork-vault-bridge installer" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# -- Validate paths ------------------------------------------------------------

$ok = $true

if (-not (Test-Path $Config.VaultRoot)) {
    Write-Host "ERROR: Vault not found at $($Config.VaultRoot)" -ForegroundColor Red
    $ok = $false
}
if (-not (Test-Path $Config.ClaudeMd)) {
    Write-Host "ERROR: CLAUDE.md not found at $($Config.ClaudeMd)" -ForegroundColor Red
    $ok = $false
}
if (-not (Test-Path $refreshScript)) {
    Write-Host "ERROR: cowork-refresh.ps1 not found - run install.ps1 from the repo folder" -ForegroundColor Red
    $ok = $false
}

if (-not $ok) { Write-Host "Fix errors above and re-run install.ps1." -ForegroundColor Yellow; exit 1 }

Write-Host "Paths OK" -ForegroundColor Green

# -- Register Task Scheduler job -----------------------------------------------

$taskName = $Config.TaskName
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "Task '$taskName' already exists - updating..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$action  = New-ScheduledTaskAction `
    -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NonInteractive -File `"$refreshScript`" -ConfigPath `"$ConfigPath`""

$triggers = @(
    # Daily at configured time
    $(New-ScheduledTaskTrigger -Daily -At $Config.TriggerTime),
    # Also run at logon so context is fresh after a reboot
    $(New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME)
)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable `
    -DontStopOnIdleEnd

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Principal $principal `
    | Out-Null

Write-Host "Task Scheduler job '$taskName' registered (daily $($Config.TriggerTime) + at logon)" -ForegroundColor Green

# -- First run -----------------------------------------------------------------

Write-Host "Running first refresh now..." -ForegroundColor Cyan
& $refreshScript -ConfigPath $ConfigPath

Write-Host ""
Write-Host "Done. Cowork will now have fresh vault context every session." -ForegroundColor Green
Write-Host "Log: $($Config.LogFile)" -ForegroundColor Gray
Write-Host ""
Write-Host "Next step: drop watch-vault.ps1 from watchers/ to close the staleness gap." -ForegroundColor Gray

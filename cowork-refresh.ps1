# cowork-refresh.ps1  v1.0.0
# Snapshots obsidian-mind brain/ notes into CLAUDE.md for Cowork context.
# Run via Task Scheduler (install.ps1) or manually: .\cowork-refresh.ps1
# Event-driven watcher lives in watchers/ (see watch-vault.ps1).

param(
    [string]$ConfigPath = "$PSScriptRoot\config.ps1"
)

. $ConfigPath   # dot-source user config → $Config

$vault    = $Config.VaultRoot
$claudeMd = $Config.ClaudeMd
$logFile  = $Config.LogFile
$date     = Get-Date -Format "yyyy-MM-dd HH:mm"

# ── Logging ──────────────────────────────────────────────────────────────────

function Write-Log($msg) {
    $line = "[$date] $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    Write-Host $line
    # Trim log
    $lines = Get-Content $logFile -ErrorAction SilentlyContinue
    if ($lines.Count -gt $Config.MaxLogLines) {
        $lines | Select-Object -Last $Config.MaxLogLines | Set-Content $logFile -Encoding UTF8
    }
}

# ── File helpers ──────────────────────────────────────────────────────────────

function Read-VaultFile($rel) {
    $p = Join-Path $vault $rel
    if (Test-Path $p) { return Get-Content $p -Raw -Encoding UTF8 }
    Write-Log "WARN: not found — $rel"
    return $null
}

function Extract-Section($content, $startHeader, $stopHeader) {
    if (-not $content) { return "" }
    $lines  = $content -split "`n"
    $inside = $false
    $out    = @()
    foreach ($line in $lines) {
        if ($line -match "^#{1,3}\s+$([regex]::Escape($startHeader))") { $inside = $true; continue }
        if ($inside -and $stopHeader -and $line -match "^#{1,3}\s+$([regex]::Escape($stopHeader))") { break }
        if ($inside) { $out += $line }
    }
    return ($out -join "`n").Trim()
}

function Last-TableRows($content, $n) {
    if (-not $content) { return "" }
    $rows = ($content -split "`n") | Where-Object { $_ -match "^\|\s*20" }
    if ($rows.Count -le $n) { return $rows -join "`n" }
    return ($rows | Select-Object -Last $n) -join "`n"
}

# ── Pull content ──────────────────────────────────────────────────────────────

$brain = $Config.BrainFolder

$northStar  = Read-VaultFile "$brain\North Star.md"
$memories   = Read-VaultFile "$brain\Memories.md"
$keyDec     = Read-VaultFile "$brain\Key Decisions.md"
$gotchas    = Read-VaultFile "$brain\Gotchas.md"
$extTools   = Read-VaultFile "$brain\External Tool Access.md"

$activeProjects  = Extract-Section $memories "Active Projects" "Recent Context"
$recentDecisions = Last-TableRows $keyDec 10

# ── Build snapshot ────────────────────────────────────────────────────────────

$snapshot = @"
<!-- COWORK-CONTEXT-START -->
## Cowork Live Context
_Auto-refreshed: $date — do not edit this section manually_

### Active Projects
$activeProjects

---
### North Star
$northStar

---
### Key Decisions (last 10)
| Date | Decision | Context |
|------|----------|---------|
$recentDecisions

---
### Gotchas
$gotchas

---
### External Tool Access
$extTools
<!-- COWORK-CONTEXT-END -->
"@

# ── Inject into CLAUDE.md ─────────────────────────────────────────────────────

if (-not (Test-Path $claudeMd)) {
    Write-Log "ERROR: CLAUDE.md not found at $claudeMd"
    exit 1
}

$current = Get-Content $claudeMd -Raw -Encoding UTF8
$start   = "<!-- COWORK-CONTEXT-START -->"
$end     = "<!-- COWORK-CONTEXT-END -->"

if ($current -match [regex]::Escape($start)) {
    $pattern = [regex]::Escape($start) + "[\s\S]*?" + [regex]::Escape($end)
    $updated = [regex]::Replace($current, $pattern, $snapshot.Trim())
} else {
    $updated = $current.TrimEnd() + "`n`n" + $snapshot.Trim()
}

[System.IO.File]::WriteAllText($claudeMd, $updated, [System.Text.Encoding]::UTF8)
Write-Log "OK: context refreshed"

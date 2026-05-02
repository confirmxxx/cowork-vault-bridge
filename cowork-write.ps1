# cowork-write.ps1  v1.0.0
# Writes content back from Cowork/Claude into vault notes.
# Only notes marked with <!-- CLAUDE-WRITABLE --> are eligible.
#
# Usage:
#   .\cowork-write.ps1 -TargetNote "perf/Brag Doc.md" -Content "..." -Mode append
#   .\cowork-write.ps1 -TargetNote "brain/North Star.md" -Content "..." -Mode section -SectionName "Claude Updates"
#
# Modes:
#   append   — appends content to end of file
#   section  — replaces content between <!-- CLAUDE-SECTION-START: name --> and <!-- CLAUDE-SECTION-END: name -->
#              creates the section at end of file if it doesn't exist yet

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetNote,        # Relative path from VaultRoot (e.g. "perf/Brag Doc.md")

    [Parameter(Mandatory=$true)]
    [string]$Content,           # Content to write

    [ValidateSet("append","section")]
    [string]$Mode = "append",

    [string]$SectionName = "",  # Required when Mode = "section"

    [string]$ConfigPath = "$PSScriptRoot\config.ps1"
)

. $ConfigPath

$ErrorActionPreference = 'Stop'

$targetPath = Join-Path $Config.VaultRoot $TargetNote
$logFile    = $Config.LogFile
$date       = Get-Date -Format "yyyy-MM-dd HH:mm"

# -- Logging ------------------------------------------------------------------

function Write-Log($msg) {
    $line = "[$date] [write-back] $msg"
    try {
        Add-Content -Path $logFile -Value $line -Encoding UTF8
    } catch {}
    Write-Host $line
}

# -- Validation ---------------------------------------------------------------

if (-not (Test-Path $targetPath)) {
    Write-Log "ERROR: target note not found: $TargetNote"
    exit 1
}

$existing = Get-Content $targetPath -Raw -Encoding UTF8

if ($existing -notmatch '<!--\s*CLAUDE-WRITABLE\s*-->') {
    Write-Log "ERROR: not writable — missing <!-- CLAUDE-WRITABLE --> marker in: $TargetNote"
    exit 1
}

if ($Mode -eq "section" -and -not $SectionName) {
    Write-Log "ERROR: -SectionName is required when Mode is 'section'"
    exit 1
}

# -- Backup -------------------------------------------------------------------

$backupPath = $targetPath + ".bak"
try {
    Copy-Item $targetPath $backupPath -Force
    Write-Log "Backup: $($TargetNote).bak"
} catch {
    Write-Log "WARN: backup failed (continuing): $($_.Exception.Message)"
}

# -- Build updated content ----------------------------------------------------

$updated = $null

switch ($Mode) {
    "append" {
        $updated = $existing.TrimEnd() + "`n`n" + $Content.Trim() + "`n"
        Write-Log "Mode: append ($($Content.Length) chars to $TargetNote)"
    }

    "section" {
        $startMarker = "<!-- CLAUDE-SECTION-START: $SectionName -->"
        $endMarker   = "<!-- CLAUDE-SECTION-END: $SectionName -->"
        $block       = "$startMarker`n$($Content.Trim())`n$endMarker"

        if ($existing -notmatch [regex]::Escape($startMarker)) {
            # Section doesn't exist yet — append it
            $updated = $existing.TrimEnd() + "`n`n" + $block + "`n"
            Write-Log "Mode: section-create '$SectionName' in $TargetNote"
        } else {
            # Replace existing section content
            $pattern = [regex]::Escape($startMarker) + "[\s\S]*?" + [regex]::Escape($endMarker)
            $updated = [regex]::Replace($existing, $pattern, $block)
            Write-Log "Mode: section-replace '$SectionName' in $TargetNote"
        }
    }
}

# -- Atomic write -------------------------------------------------------------

$tmpPath = $targetPath + ".tmp"
try {
    [System.IO.File]::WriteAllText($tmpPath, $updated, [System.Text.Encoding]::UTF8)
    Move-Item $tmpPath $targetPath -Force
} catch {
    # Clean up temp file if move failed
    if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue }
    Write-Log "ERROR: write failed: $($_.Exception.Message)"
    exit 1
}

Write-Log "OK: write-back complete -> $TargetNote"

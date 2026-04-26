# watch-vault.ps1  — PLACEHOLDER
# Event-driven watcher: fires cowork-refresh.ps1 on vault brain/ file saves.
# Closes the 24h staleness gap on the Cowork bridge.
#
# STATUS: to be implemented by Opus 4.7 (task handed off 2026-04-26)
#
# Expected behavior:
#   - Watch $Config.VaultRoot\$Config.BrainFolder for *.md changes
#   - Debounce: wait 30s after last change before triggering (avoids rapid-fire on autosave)
#   - On trigger: run cowork-refresh.ps1
#   - Log each trigger to $Config.LogFile
#   - Run persistently (as a background job or a scheduled task on file event)
#
# Candidate approaches (Opus to evaluate and pick):
#   1. PowerShell FileSystemWatcher — persistent script, no external deps
#   2. Python watchdog — pip install watchdog, subprocess to PS script
#   3. Obsidian shellcommands plugin — fires on save inside Obsidian
#   4. Task Scheduler event trigger — less reliable but no persistent process

Write-Host "watch-vault.ps1 not yet implemented. See watchers/README.md." -ForegroundColor Yellow

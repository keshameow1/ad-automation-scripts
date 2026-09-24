🇬🇧 English | [🇷🇺 Русский](scheduled-tasks-setup.ru.md)

# Setting up Windows Task Scheduler tasks

All three scripts run weekly on Sundays, 30 minutes apart, so each step
works on the output of the previous one:

| Time | Task | Script |
|------|------|--------|
| 03:00 | `kir_Move-DisabledAccounts` | `move_disabled_accounts.ps1` |
| 03:30 | `kir_Remove-ThunderbirdProfiles` | `remove_thunderbird_profiles.ps1` |
| 04:00 | `kir_Cleanup-OldDisabledAccounts` | `cleanup_old_disabled_accounts.ps1` |

The `kir_` prefix is used to tell these tasks apart from other tasks on the
server. Replace it with your own if needed.

All commands below are run in an elevated PowerShell session.

## 1. Move disabled/deleted AD accounts

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\move_disabled_accounts\move_disabled_accounts.ps1"'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "kir_Move-DisabledAccounts" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Weekly move of disabled/deleted AD accounts' profiles into the quarantine folder"
```

## 2. Remove Thunderbird profiles

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\move_disabled_accounts\remove_thunderbird_profiles.ps1"'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:30am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "kir_Remove-ThunderbirdProfiles" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Weekly removal of Thunderbird profiles from every folder in the quarantine"
```

## 3. Clean up profiles older than 90 days

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\move_disabled_accounts\cleanup_old_disabled_accounts.ps1" -DaysThreshold 90'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 4am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "kir_Cleanup-OldDisabledAccounts" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Weekly deletion of quarantined profiles older than 90 days"
```

## Verifying the tasks

List all your tasks and their state:

```powershell
Get-ScheduledTask -TaskName "kir_*" | Select-Object TaskName, State
```

Check the schedule and last/next run time for a specific task:

```powershell
Get-ScheduledTaskInfo -TaskName "kir_Move-DisabledAccounts"
```

Run a task manually without waiting for its schedule (useful for testing):

```powershell
Start-ScheduledTask -TaskName "kir_Move-DisabledAccounts"
```

After a manual run, check the corresponding log file under
`C:\Scripts\move_disabled_accounts\` to confirm the task actually ran as
`SYSTEM`, has AD access, and is doing its part correctly.

## Renaming existing tasks

The `ScheduledTasks` module has no built-in `Rename` command. To rename a
task that already exists, export it, unregister it, and re-register it
under the new name:

```powershell
function Rename-ScheduledTaskSafe {
    param(
        [Parameter(Mandatory)] [string]$OldName,
        [Parameter(Mandatory)] [string]$NewName
    )

    $xml = Export-ScheduledTask -TaskName $OldName
    Unregister-ScheduledTask -TaskName $OldName -Confirm:$false
    Register-ScheduledTask -TaskName $NewName -Xml $xml | Out-Null

    Write-Host "Renamed: '$OldName' -> '$NewName'" -ForegroundColor Green
}

Rename-ScheduledTaskSafe -OldName "Move-DisabledAccounts" -NewName "kir_Move-DisabledAccounts"
```

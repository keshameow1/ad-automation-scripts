🇬🇧 English | [🇷🇺 Русский](README.ru.md)

# AD Account Cleanup Automation

A set of PowerShell scripts that automate the lifecycle of former employees'
local profiles on a file/terminal server: detecting disabled Active Directory
accounts, quarantining their local profiles, and scheduled cleanup of data
past its retention period.

## Problem

On a server with local/terminal user profiles, folders belonging to former
employees pile up over time in `C:\Users`: the AD account is already
disabled or deleted, but the profile data (including Thunderbird mail
archives) keeps taking up disk space and poses a personal-data retention
risk.

This used to be a manual, ad-hoc check. The goal was to turn it into a
weekly automated process that requires no administrator involvement.

## How it works

Three scripts run sequentially on a weekly schedule (every Sunday night)
via Windows Task Scheduler:

| # | Script | Time | What it does |
|---|--------|------|---------------|
| 1 | `move_disabled_accounts.ps1` | 03:00 | Cross-checks folders in `C:\Users` against the account status in AD. If the account is disabled (`ACCOUNTDISABLE` flag) or not found in AD, the profile folder is moved to the quarantine folder (`_Уволенные`) and stamped with the move date. |
| 2 | `remove_thunderbird_profiles.ps1` | 03:30 | Walks every folder in the quarantine and removes `AppData\Roaming\Thunderbird\Profiles` — the heaviest and least useful data is deleted right away instead of waiting 90 days. |
| 3 | `cleanup_old_disabled_accounts.ps1` | 04:00 | Deletes profiles from the quarantine that have been sitting there longer than `DaysThreshold` (default 90) days, using the move-date stamp left by the first script. |

For the exact Task Scheduler registration commands, see
[`docs/scheduled-tasks-setup.md`](docs/scheduled-tasks-setup.md).

## Repository structure

```
ad-automation-scripts/
├── README.md
├── README.ru.md
├── .gitignore
├── move-disabled-accounts/
│   ├── move_disabled_accounts.ps1
│   ├── remove_thunderbird_profiles.ps1
│   └── cleanup_old_disabled_accounts.ps1
└── docs/
    ├── scheduled-tasks-setup.md
    └── scheduled-tasks-setup.ru.md
```

## Scripts

### `move_disabled_accounts.ps1`

Scans `C:\Users`; for every folder (excluding the service ones listed in
`$exclude`) it looks up a matching AD user by `sAMAccountName` via
`DirectoryServices.DirectorySearcher`. If the user isn't found, or the
account is disabled (the `ACCOUNTDISABLE` bit in `userAccountControl`), the
folder is moved into the quarantine folder, and a `_moved_date.txt` marker
file with the move date is dropped alongside it (used by the cleanup script
to compute age).

Runs fully non-interactively — suitable for scheduled execution. All
actions and matched accounts are logged to `move_disabled_accounts.log` next
to the script.

### `remove_thunderbird_profiles.ps1`

Walks every subfolder of the quarantine folder, checks for
`AppData\Roaming\Thunderbird\Profiles`, and deletes it without confirmation.
Logs results to `remove_thunderbird_profiles.log`.

### `cleanup_old_disabled_accounts.ps1`

Accepts a `-DaysThreshold` parameter (default 90). For every folder in the
quarantine it reads the move date from `_moved_date.txt` (falling back to
the folder's `CreationTime` if the marker is missing) and deletes the
folder entirely once it has exceeded the threshold. Logs to
`cleanup_old_disabled_accounts.log`.

## Requirements

- PowerShell 5.1+ (built into Windows Server / Windows 10+).
- Read access to user objects in Active Directory.
- Read/write/delete access to `C:\Users` (for scheduled runs — the `SYSTEM`
  account with `RunLevel Highest`, see `docs/scheduled-tasks-setup.md`).

## Adapting to your environment

Before using these scripts, edit:

- `$profilePath` — path to the folder containing user profiles (default `C:\Users`).
- `$exclude` — list of system/service folders to skip (built-in Windows
  accounts, service accounts, etc.).
- `$deletedFolderName` — name of the quarantine folder for former employees.
- `$DaysThreshold` in `cleanup_old_disabled_accounts.ps1` — retention period
  before a profile is permanently deleted.

## Security notes and limitations

- Deletion in `cleanup_old_disabled_accounts.ps1` and
  `remove_thunderbird_profiles.ps1` is permanent (`Remove-Item -Force`, no
  recycle bin). Test on a non-production folder before relying on this in
  production.
- These scripts target a classic on-premise Active Directory environment
  (`System.DirectoryServices`); Azure AD / Entra ID would require a
  different mechanism for checking account status.

[English](scheduled-tasks-setup.md) | Русский

# Настройка задач в Планировщике заданий Windows

Все три скрипта выполняются еженедельно по воскресеньям с интервалом в
30 минут, чтобы каждый следующий шаг работал с результатом предыдущего:

| Время | Задача | Скрипт |
|-------|--------|--------|
| 03:00 | `kir_Move-DisabledAccounts` | `move_disabled_accounts.ps1` |
| 03:30 | `kir_Remove-ThunderbirdProfiles` | `remove_thunderbird_profiles.ps1` |
| 04:00 | `kir_Cleanup-OldDisabledAccounts` | `cleanup_old_disabled_accounts.ps1` |

Префикс `kir_` используется, чтобы отличать свои задачи от остальных задач
в Планировщике на сервере. Замените на свой при необходимости.

Все команды выполняются в PowerShell с правами администратора.

## 1. Перенос отключённых/удалённых в AD учёток

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\move_disabled_accounts\move_disabled_accounts.ps1"'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am

$principal = New-ScheduledTaskPrincipal -UserId "СИСТЕМА" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "kir_Move-DisabledAccounts" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Еженедельный перенос профилей отключённых/удалённых в AD учёток в папку _Уволенные"
```

## 2. Удаление Thunderbird Profiles у уволенных

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\move_disabled_accounts\remove_thunderbird_profiles.ps1"'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:30am

$principal = New-ScheduledTaskPrincipal -UserId "СИСТЕМА" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "kir_Remove-ThunderbirdProfiles" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Еженедельное удаление Thunderbird Profiles у всех в папке '_Уволенные'"
```

## 3. Очистка профилей старше 90 дней

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\move_disabled_accounts\cleanup_old_disabled_accounts.ps1" -DaysThreshold 90'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 4am

$principal = New-ScheduledTaskPrincipal -UserId "СИСТЕМА" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "kir_Cleanup-OldDisabledAccounts" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Еженедельное удаление профилей из '_Уволенные' старше 90 дней"
```

## Проверка задач

Посмотреть все свои задачи и их состояние:

```powershell
Get-ScheduledTask -TaskName "kir_*" | Select-Object TaskName, State
```

Посмотреть расписание и время последнего/следующего запуска конкретной задачи:

```powershell
Get-ScheduledTaskInfo -TaskName "kir_Move-DisabledAccounts"
```

Запустить задачу вручную, не дожидаясь расписания (полезно для теста):

```powershell
Start-ScheduledTask -TaskName "kir_Move-DisabledAccounts"
```

После ручного запуска стоит сразу посмотреть соответствующий лог в
`C:\Scripts\move_disabled_accounts\`, чтобы убедиться, что задача
действительно отработала от `СИСТЕМА`, имеет доступ к AD и корректно
выполняет свою часть работы.

## Переименование уже существующих задач

Если задача была ранее зарегистрирована под другим именем, штатной команды
`Rename` в модуле `ScheduledTasks` нет — задачу нужно экспортировать,
удалить и зарегистрировать заново под новым именем:

```powershell
function Rename-ScheduledTaskSafe {
    param(
        [Parameter(Mandatory)] [string]$OldName,
        [Parameter(Mandatory)] [string]$NewName
    )

    $xml = Export-ScheduledTask -TaskName $OldName
    Unregister-ScheduledTask -TaskName $OldName -Confirm:$false
    Register-ScheduledTask -TaskName $NewName -Xml $xml | Out-Null

    Write-Host "Переименовано: '$OldName' -> '$NewName'" -ForegroundColor Green
}

Rename-ScheduledTaskSafe -OldName "Move-DisabledAccounts" -NewName "kir_Move-DisabledAccounts"
```

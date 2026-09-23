$profilePath = "C:\Users"
$exclude = @('Public', 'Default', 'Администратор', 'Administrator', 'All Users', 'Default User', '_Уволенные')
$deletedFolderName = '_Уволенные'
$deletedFolderPath = Join-Path $profilePath $deletedFolderName

# Лог-файл — хранится вместе со скриптом
$scriptDir = "C:\Scripts\move_disabled_accounts"
if (-not (Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
}
$logPath = Join-Path $scriptDir "move_disabled_accounts.log"

function Write-Log {
    param($Message, $Color = 'White')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"
    Add-Content -Path $logPath -Value $line
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "=== Запуск скрипта ==="

$searcher = New-Object DirectoryServices.DirectorySearcher
$searcher.PageSize = 1000

$results = Get-ChildItem -Path $profilePath -Directory |
    Where-Object { $_.Name -notin $exclude } |
    ForEach-Object {
        $folder = $_.Name
        $fullPath = $_.FullName
        $searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$folder))"
        $searcher.PropertiesToLoad.AddRange(@('userAccountControl', 'lastLogonTimestamp', 'sAMAccountName'))

        $result = $searcher.FindOne()

        if ($null -eq $result) {
            [PSCustomObject]@{
                Folder    = $fullPath
                AD_User   = $folder
                Status    = 'Нет в AD (удалён)'
                LastLogon = $null
            }
        }
        else {
            $uac = $result.Properties['useraccountcontrol'][0]
            if ($uac -band 2) {
                $lastLogonTimestamp = $result.Properties['lastlogontimestamp']
                if ($lastLogonTimestamp) {
                    $lastLogon = [DateTime]::FromFileTime([Int64]::Parse($lastLogonTimestamp[0]))
                } else {
                    $lastLogon = $null
                }
                [PSCustomObject]@{
                    Folder    = $fullPath
                    AD_User   = $result.Properties['samaccountname'][0]
                    Status    = 'Отключен в AD'
                    LastLogon = $lastLogon
                }
            }
        }
    }

$results = @($results)

if ($results.Count -gt 0) {
    Write-Log ("Найдено учёток для переноса: {0}" -f $results.Count)
    $results | Format-Table -AutoSize | Out-String | Add-Content -Path $logPath

    if (-not (Test-Path $deletedFolderPath)) {
        New-Item -Path $deletedFolderPath -ItemType Directory | Out-Null
    }

    foreach ($item in $results) {
        $sourcePath = $item.Folder
        $folderName = Split-Path $sourcePath -Leaf
        $destinationPath = Join-Path $deletedFolderPath $folderName

        try {
            if (Test-Path $destinationPath) {
                Write-Log "Пропуск: в '$deletedFolderName' уже есть папка '$folderName'" 'Yellow'
                continue
            }
            Move-Item -Path $sourcePath -Destination $destinationPath -ErrorAction Stop
            Get-Date -Format 'yyyy-MM-dd HH:mm:ss' | Set-Content -Path (Join-Path $destinationPath "_moved_date.txt")
            Write-Log "Перемещено: $folderName ($($item.Status))" 'Green'
        }
        catch {
            Write-Log "Ошибка при перемещении '$folderName': $($_.Exception.Message)" 'Red'
        }
    }
}
else {
    Write-Log "Подозрительных учетных записей не найдено." 'Green'
}

Write-Log "=== Завершение работы скрипта ==="
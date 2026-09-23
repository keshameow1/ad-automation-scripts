$TargetFolder = "C:\Users\_Уволенные"

$scriptDir = "C:\Scripts\move_disabled_accounts"
if (-not (Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
}
$logPath = Join-Path $scriptDir "remove_thunderbird_profiles.log"

function Write-Log {
    param($Message, $Color = 'White')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"
    Add-Content -Path $logPath -Value $line
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "=== Запуск удаления Thunderbird Profiles в '$TargetFolder' ==="

if (-not (Test-Path $TargetFolder -PathType Container)) {
    Write-Log "ОШИБКА: Папка '$TargetFolder' не найдена. Завершение." 'Red'
    return
}

$userFolders = Get-ChildItem -Path $TargetFolder -Directory

if ($userFolders.Count -eq 0) {
    Write-Log "В папке '$TargetFolder' нет подпапок. Завершение." 'Yellow'
    return
}

Write-Log "Найдено папок пользователей: $($userFolders.Count)"

$profilesToDelete = @()
foreach ($userFolder in $userFolders) {
    $userName = $userFolder.Name
    $thunderbirdProfiles = Join-Path $userFolder.FullName "AppData\Roaming\Thunderbird\Profiles"
    if (Test-Path $thunderbirdProfiles -PathType Container) {
        $profilesToDelete += [PSCustomObject]@{
            User = $userName
            Path = $thunderbirdProfiles
        }
    }
}

if ($profilesToDelete.Count -eq 0) {
    Write-Log "Не найдено ни одной папки Profiles в профилях уволенных." 'Green'
    Write-Log "=== Завершение ==="
    return
}

Write-Log ("Найдено папок Profiles для удаления: {0}" -f $profilesToDelete.Count)

$successCount = 0
$errorCount = 0

foreach ($p in $profilesToDelete) {
    try {
        Remove-Item -Path $p.Path -Recurse -Force -ErrorAction Stop
        Write-Log "Удалено: $($p.User) : $($p.Path)" 'Green'
        $successCount++
    }
    catch {
        Write-Log "Ошибка при удалении '$($p.Path)' ($($p.User)): $($_.Exception.Message)" 'Red'
        $errorCount++
    }
}

Write-Log ("Итог: успешно удалено {0}, ошибок {1}" -f $successCount, $errorCount)
Write-Log "=== Завершение ==="
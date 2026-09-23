param(
    [int]$DaysThreshold = 90
)

$deletedFolderPath = "C:\Users\_Уволенные"
$scriptDir = "C:\Scripts\move_disabled_accounts"
if (-not (Test-Path $scriptDir)) {
    New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
}
$logPath = Join-Path $scriptDir "cleanup_old_disabled_accounts.log"

function Write-Log {
    param($Message, $Color = 'White')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"
    Add-Content -Path $logPath -Value $line
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "=== Запуск очистки '_Уволенные' (порог: $DaysThreshold дн.) ==="

if (-not (Test-Path $deletedFolderPath)) {
    Write-Log "Папка '$deletedFolderPath' не найдена. Завершение." 'Yellow'
    return
}

$now = Get-Date
$candidates = Get-ChildItem -Path $deletedFolderPath -Directory

if ($candidates.Count -eq 0) {
    Write-Log "В '_Уволенные' пусто, нечего чистить." 'Green'
}

foreach ($folder in $candidates) {
    $markerPath = Join-Path $folder.FullName "_moved_date.txt"

    if (Test-Path $markerPath) {
        try {
            $movedDate = [DateTime]::Parse((Get-Content $markerPath -Raw).Trim())
            $source = "метка"
        }
        catch {
            $movedDate = $folder.CreationTime
            $source = "CreationTime (не удалось прочитать метку)"
        }
    }
    else {
        $movedDate = $folder.CreationTime
        $source = "CreationTime (метки нет)"
    }

    $ageDays = ($now - $movedDate).Days

    if ($ageDays -ge $DaysThreshold) {
        try {
            Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
            Write-Log "Удалено: $($folder.Name) — в '_Уволенные' $ageDays дн. (источник даты: $source)" 'Green'
        }
        catch {
            Write-Log "Ошибка при удалении '$($folder.Name)': $($_.Exception.Message)" 'Red'
        }
    }
    else {
        Write-Log "Пропуск: $($folder.Name) — только $ageDays дн. из $DaysThreshold (источник даты: $source)"
    }
}

Write-Log "=== Завершение очистки ==="
param(
    [string]$Path = "H:\MSSQL",                       ##Back up drive Path
    [int]$RetentionDays = 7,                                 ##Retention Days For .bak
    [string]$LogFile = "H:\MSSQL\Backup\CleanupBackups.log"  ##Output Log File
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $Message"

    Write-Output $entry
    Add-Content -Path $LogFile -Value $entry
}

try {
    Write-Log "===== Backup Cleanup Started ====="
    Write-Log "Path: $Path"
    Write-Log "Retention: $RetentionDays days"

    if (!(Test-Path $Path)) {
        throw "Path does not exist: $Path"
    }

    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)

    Write-Log "Deleting files older than: $cutoffDate"

    $files = Get-ChildItem -Path $Path -Recurse -Include *.bak, *.trn, *.diff -File

    if ($files.Count -eq 0) {
        Write-Log "No backup files found."
    }

    $deletedCount = 0

    foreach ($file in $files) {
        if ($file.LastWriteTime -lt $cutoffDate) {
            Write-Log "Deleting: $($file.FullName)"

            Remove-Item $file.FullName -Force -ErrorAction Stop
            $deletedCount++
        }
    }

    Write-Log "Total files deleted: $deletedCount"
    Write-Log "===== Cleanup Completed Successfully ====="
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}

##

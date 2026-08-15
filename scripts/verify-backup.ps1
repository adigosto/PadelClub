param(
    [Parameter(Mandatory = $true)][string]$BackupFile,
    [string]$SqlPassword = "YourStrong!Passw0rd"
)

$ErrorActionPreference = "Stop"
$workspace = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backupDirectory = (Resolve-Path (Join-Path $workspace "backups")).Path
$resolved = (Resolve-Path -LiteralPath $BackupFile).Path
if (-not $resolved.StartsWith($backupDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Backup must be inside $backupDirectory." }
if ([IO.Path]::GetExtension($resolved) -ne ".bak") { throw "Expected a .bak file." }

$fileName = [IO.Path]::GetFileName($resolved)
$containerPath = "/var/opt/mssql/backup/$fileName"
$query = "RESTORE VERIFYONLY FROM DISK = N'$containerPath' WITH CHECKSUM"
docker compose exec -T padelclub-sql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P $SqlPassword -Q $query
if ($LASTEXITCODE -ne 0) { throw "Backup verification failed." }
Write-Host "Backup verified: $resolved"

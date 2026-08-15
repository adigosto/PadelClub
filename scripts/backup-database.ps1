param(
    [string]$Database = "PadelClub",
    [string]$SqlPassword = "YourStrong!Passw0rd"
)

$ErrorActionPreference = "Stop"
$workspace = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backupDirectory = Join-Path $workspace "backups"
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

if ($Database -notmatch '^[A-Za-z0-9_-]+$') { throw "Invalid database name." }
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$fileName = "$Database-$timestamp.bak"
$containerPath = "/var/opt/mssql/backup/$fileName"
$query = "BACKUP DATABASE [$Database] TO DISK = N'$containerPath' WITH COPY_ONLY, CHECKSUM, INIT, STATS = 10"

docker compose exec -T padelclub-sql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P $SqlPassword -Q $query
if ($LASTEXITCODE -ne 0) { throw "SQL Server backup failed." }

$hostPath = Join-Path $backupDirectory $fileName
if (-not (Test-Path -LiteralPath $hostPath)) { throw "Backup completed but $hostPath was not found." }
Write-Host "Backup created: $hostPath"

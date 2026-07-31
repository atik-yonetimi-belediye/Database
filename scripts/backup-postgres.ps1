param(
  [string]$Container = "atik_db",
  [string]$Database = "belediye_atik",
  [string]$User = "postgres",
  [string]$BackupDirectory = ".\backups",
  [int]$RetentionDays = 14
)

$ErrorActionPreference = "Stop"
$resolvedBackup = [System.IO.Path]::GetFullPath($BackupDirectory)
if ($resolvedBackup -eq [System.IO.Path]::GetPathRoot($resolvedBackup)) { throw "Yedek dizini disk kökü olamaz." }
New-Item -ItemType Directory -Path $resolvedBackup -Force | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$containerFile = "/tmp/$Database-$stamp.dump"
$hostFile = Join-Path $resolvedBackup "$Database-$stamp.dump"

docker exec $Container pg_dump -U $User -d $Database -Fc -f $containerFile
if ($LASTEXITCODE -ne 0) { throw "pg_dump başarısız oldu." }
docker cp "${Container}:${containerFile}" $hostFile
if ($LASTEXITCODE -ne 0) { throw "Yedek host dizinine kopyalanamadı." }

Get-ChildItem -LiteralPath $resolvedBackup -Filter "$Database-*.dump" -File |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
  ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

Write-Output $hostFile

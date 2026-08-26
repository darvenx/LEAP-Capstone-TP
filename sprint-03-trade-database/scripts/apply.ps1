# apply.ps1 - Windows PowerShell equivalent of apply.sh.
#
# Take an empty database to fully migrated and seeded, in one command, from the
# sprint-03-trade-database/ folder:
#
#     ./scripts/apply.ps1
#
# Reads TARGET_DATABASE / POSTGRES_* from the repository-root .env if present.
# Uses psql -v ON_ERROR_STOP=1 so a failure aborts with a non-zero exit code.

$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDbDir   = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent $RepoDbDir

$envFile = Join-Path $ProjectRoot '.env'
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $name, $value = $line -split '=', 2
        $name = $name.Trim()
        $value = $value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not (Test-Path "Env:$name")) {
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

$targetDb = $env:TARGET_DATABASE
if ([string]::IsNullOrWhiteSpace($targetDb)) { $targetDb = $env:POSTGRES_DB }
if ([string]::IsNullOrWhiteSpace($targetDb)) {
    Write-Error "Set TARGET_DATABASE, or POSTGRES_DB in the repository-root .env"
    exit 2
}

if ([string]::IsNullOrWhiteSpace($env:PGUSER)) {
    $env:PGUSER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { 'postgres' }
}
if ([string]::IsNullOrWhiteSpace($env:PGPASSWORD) -and $env:POSTGRES_PASSWORD) {
    $env:PGPASSWORD = $env:POSTGRES_PASSWORD
}

Set-Location $RepoDbDir

Write-Host "==> Applying migrations to '$targetDb'"
Get-ChildItem -Path 'migrations' -Filter '*.sql' | Sort-Object Name | ForEach-Object {
    Write-Host "    migration: $($_.Name)"
    psql -v ON_ERROR_STOP=1 --no-psqlrc -d $targetDb -f $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "migration failed: $($_.Name)" }
}

Write-Host "==> Loading seed data into '$targetDb'"
Get-ChildItem -Path 'seed' -Filter '*.sql' | Sort-Object Name | ForEach-Object {
    Write-Host "    seed: $($_.Name)"
    psql -v ON_ERROR_STOP=1 --no-psqlrc -d $targetDb -f $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "seed failed: $($_.Name)" }
}

Write-Host "==> Done. '$targetDb' is migrated and seeded."

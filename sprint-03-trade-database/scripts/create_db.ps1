# create_db.ps1 - local (non-Docker) one-line command.
#
# Recreates the target database, applies every migration, bulk-loads seed/csv,
# and runs probes/. Credentials come from the repository-root .env. Never
# prompts for a password (psql --no-password).
#
# Requires a running Postgres and `psql` on PATH.
#
#     ./scripts/create_db.ps1

$ErrorActionPreference = 'Stop'
# psql writes expected SQL errors to stderr. Do not treat that as terminating.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

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

if ([string]::IsNullOrWhiteSpace($env:PGHOST)) {
    $env:PGHOST = 'localhost'
}
if ([string]::IsNullOrWhiteSpace($env:PGUSER)) {
    $env:PGUSER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { 'postgres' }
}
if ([string]::IsNullOrWhiteSpace($env:PGPASSWORD) -and $env:POSTGRES_PASSWORD) {
    $env:PGPASSWORD = $env:POSTGRES_PASSWORD
}
if ([string]::IsNullOrWhiteSpace($env:PGPASSWORD)) {
    Write-Error "Set POSTGRES_PASSWORD in the repository-root .env (password prompt is disabled)"
    exit 2
}

function Invoke-Psql {
    param(
        [Parameter(Mandatory = $true)][string] $Database,
        [Parameter(Mandatory = $true)][string[]] $PsqlArgs
    )
    & psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password -d $Database @PsqlArgs
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed (exit $LASTEXITCODE) on database '$Database': $($PsqlArgs -join ' ')"
    }
}

Set-Location $RepoDbDir

Write-Host "==> Recreating database '$targetDb'"
# Must connect to a different database than the one we drop.
Invoke-Psql -Database postgres -PsqlArgs @(
    '-c', "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$targetDb' AND pid <> pg_backend_pid();"
)
Invoke-Psql -Database postgres -PsqlArgs @('-c', "DROP DATABASE IF EXISTS `"$targetDb`";")
Invoke-Psql -Database postgres -PsqlArgs @('-c', "CREATE DATABASE `"$targetDb`";")

Write-Host "==> Applying migrations to '$targetDb'"
Get-ChildItem -Path 'migrations' -Filter '*.sql' | Sort-Object Name | ForEach-Object {
    Write-Host "    migration: $($_.Name)"
    Invoke-Psql -Database $targetDb -PsqlArgs @('-f', $_.FullName)
}

Write-Host "==> Loading CSV seed into '$targetDb'"
Invoke-Psql -Database $targetDb -PsqlArgs @('-f', (Join-Path $RepoDbDir 'scripts\load_csv.sql'))

Write-Host "==> Running probes"
Invoke-Psql -Database $targetDb -PsqlArgs @('-f', (Join-Path $RepoDbDir 'probes\verify_queries.sql'))

& psql -v ON_ERROR_STOP=0 --no-psqlrc --no-password -d $targetDb -f (Join-Path $RepoDbDir 'probes\failure_tests.sql')
# ON_ERROR_STOP=0: the two statements are supposed to error (23505 / 23503).

Write-Host ""
Write-Host "Done. '$targetDb' is migrated, CSV-seeded and probe-tested."

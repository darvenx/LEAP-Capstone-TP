param(
    [string]$TargetDatabase,
    [string]$PgHost,
    [int]$PgPort,
    [string]$PgUser
)

$ErrorActionPreference = 'Stop'
$databaseDirectory = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $databaseDirectory '..\manifest.env'
if (Test-Path $manifestPath) {
    Get-Content $manifestPath | Where-Object { $_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)\s*$' } | ForEach-Object {
        $name = $Matches[1]
        $value = $Matches[2].Trim([char[]]@("'", '"'))
        if (-not (Get-Item "Env:$name" -ErrorAction SilentlyContinue)) {
            Set-Item "Env:$name" $value
        }
    }
}

if (-not $TargetDatabase) { $TargetDatabase = if ($env:TARGET_DATABASE) { $env:TARGET_DATABASE } elseif ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { 'trade_db' } }
if (-not $PgHost) { $PgHost = if ($env:PGHOST) { $env:PGHOST } else { 'localhost' } }
if (-not $PgPort) { $PgPort = if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 } }
if (-not $PgUser) { $PgUser = if ($env:PGUSER) { $env:PGUSER } else { 'postgres' } }

$psqlArguments = @('-h', $PgHost, '-p', $PgPort, '-U', $PgUser, '-v', 'ON_ERROR_STOP=1')

function Invoke-Psql {
    param([string[]]$Arguments)
    & psql @psqlArguments @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed with exit code $LASTEXITCODE"
    }
}

Push-Location $databaseDirectory
try {
    $databaseExists = (& psql @psqlArguments -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$TargetDatabase';").Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Could not connect to the postgres maintenance database. Check PGHOST, PGPORT, PGUSER, and PGPASSWORD."
    }

    if ($databaseExists -ne '1') {
        Write-Host "Creating database '$TargetDatabase'"
        Invoke-Psql @('-d', 'postgres', '-c', "CREATE DATABASE `"$TargetDatabase`";")
    } else {
        Write-Host "Database '$TargetDatabase' already exists"
    }

    Get-ChildItem -Path (Join-Path $databaseDirectory 'migrations') -Filter '*.sql' |
        Sort-Object Name |
        ForEach-Object {
            Write-Host "Applying $($_.Name)"
            Invoke-Psql @('-d', $TargetDatabase, '-f', $_.FullName)
        }

    Get-ChildItem -Path (Join-Path $databaseDirectory 'seed') -Filter '*.sql' |
        Sort-Object Name |
        ForEach-Object {
            Write-Host "Loading $($_.Name)"
            Invoke-Psql @('-d', $TargetDatabase, '-f', $_.FullName)
        }

    Write-Host "Database '$TargetDatabase' is migrated and seeded."
}
finally {
    Pop-Location
}

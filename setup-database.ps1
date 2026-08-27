$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'database\scripts\setup_db_and_seed.ps1')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

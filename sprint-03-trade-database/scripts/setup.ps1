# setup.ps1 - Windows PowerShell equivalent of setup.sh.
#
# The Docker one-line command: build the Sprint 3 database image and run a
# fully migrated + CSV-seeded + probe-tested Postgres 16 container.
#
#     ./scripts/setup.ps1
#
# Credentials come from the repository-root .env if present, else safe local
# defaults. Override the published port with $env:PGPORT (default 5432).
# Never prompts for a password.

$ErrorActionPreference = 'Stop'
# docker / psql write warnings and expected SQL errors to stderr. Do not treat
# that as a terminating PowerShell error; we check $LASTEXITCODE ourselves.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Get-DockerLogs {
    param([string] $Name)
    # docker logs writes to stderr. Capture via cmd so Windows PowerShell 5.1
    # does not turn those lines into terminating ErrorRecords.
    cmd /c "docker logs `"$Name`" 2>&1"
}

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$DbDir       = Split-Path -Parent $ScriptDir            # sprint-03-trade-database/
$ProjectRoot = Split-Path -Parent $DbDir

$envFile = Join-Path $ProjectRoot '.env'
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $name, $value = $line -split '=', 2
        $name = $name.Trim(); $value = $value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($name) -and -not (Test-Path "Env:$name")) {
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

$image     = 'leap-trade-db:sprint03'
$container = 'leap-trade-db'
$port      = if ($env:PGPORT) { $env:PGPORT } else { '5432' }
$db        = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { 'trading' }
$user      = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { 'postgres' }
$password  = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { 'postgres_dev_password' }

Write-Host "==> Building image '$image'"
docker build -t $image $DbDir
if ($LASTEXITCODE -ne 0) { throw "docker build failed" }

Write-Host "==> Removing any previous '$container' container"
docker rm -f $container 2>$null | Out-Null

Write-Host "==> Starting '$container' on localhost:$port (db '$db')"
docker run -d --name $container -p "${port}:5432" `
    -e "POSTGRES_DB=$db" `
    -e "POSTGRES_USER=$user" `
    -e "POSTGRES_PASSWORD=$password" `
    $image | Out-Null
if ($LASTEXITCODE -ne 0) { throw "docker run failed" }

Write-Host "==> Waiting for init (migrations, CSV seed, probes) to finish"
$deadline = (Get-Date).AddSeconds(120)
$initDone = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $running = docker inspect -f '{{.State.Running}}' $container 2>$null
    if ($running -ne 'true') {
        Write-Host (Get-DockerLogs $container | Out-String)
        throw "container '$container' exited before init finished"
    }
    $logs = Get-DockerLogs $container | Out-String
    if ($logs -match 'PostgreSQL init process complete') {
        $initDone = $true
        break
    }
}
if (-not $initDone) {
    Write-Host (Get-DockerLogs $container | Out-String)
    throw "timed out waiting for database init"
}

do {
    Start-Sleep -Seconds 1
    docker exec -e "PGPASSWORD=$password" $container pg_isready -U $user -d $db *> $null
} while ($LASTEXITCODE -ne 0)

Write-Host "==> Running probes"
# cmd so expected SQL errors on stderr (failure_tests) are not terminating.
cmd /c "docker exec -e PGPASSWORD=$password $container psql -v ON_ERROR_STOP=1 --no-psqlrc --no-password -U $user -d $db -f /schema/probes/verify_queries.sql"
if ($LASTEXITCODE -ne 0) { throw "probe failed: verify_queries.sql" }

cmd /c "docker exec -e PGPASSWORD=$password $container psql -v ON_ERROR_STOP=0 --no-psqlrc --no-password -U $user -d $db -f /schema/probes/failure_tests.sql"
# ON_ERROR_STOP=0: the two statements are supposed to error (23505 / 23503).

Write-Host ""
Write-Host "Done. Postgres 16 is migrated, CSV-seeded and probe-tested at localhost:$port."
Write-Host "  Connect:  psql -h localhost -p $port -U $user -d $db"
Write-Host "  Logs:     docker logs -f $container"
Write-Host "  Rebuild:  docker rm -f $container ; ./scripts/setup.ps1"

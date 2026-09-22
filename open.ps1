param(
    [Parameter(Position = 0)]
    [ValidateSet("dashboard", "author", "publish", "dispatcher", "traefik", "kibana", "elasticsearch", "all")]
    [string[]]$Target = @("dashboard"),
    [string]$ComposeFiles = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\scripts\Import-LocalEnv.ps1"
Import-LocalEnv -RootPath $PSScriptRoot

function Get-EnvValue {
    param(
        [string]$Path,
        [string]$Name
    )

    $processValue = [System.Environment]::GetEnvironmentVariable($Name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue
    }

    $line = Get-Content $Path | Where-Object { $_ -match "^${Name}=" } | Select-Object -First 1
    if (-not $line) {
        return $null
    }

    $value = $line.Substring($Name.Length + 1).Trim()
    if ($value.StartsWith('"') -and $value.EndsWith('"')) {
        return $value.Trim('"')
    }

    return $value
}

function Get-ServicePort {
    param(
        [object[]]$Services,
        [string]$ServiceName,
        [int]$TargetPort
    )

    $service = $Services | Where-Object { $_.Service -eq $ServiceName } | Select-Object -First 1
    if (-not $service) {
        return $null
    }

    foreach ($publisher in @($service.Publishers)) {
        if ($publisher.TargetPort -eq $TargetPort -and $publisher.PublishedPort) {
            return [string]$publisher.PublishedPort
        }
    }

    return $null
}

$serviceLines = docker compose ps --format json
$services = @($serviceLines | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
$envFile = Join-Path $PSScriptRoot ".env"

$urlMap = [ordered]@{
    dashboard     = "https://dashboard.localhost/"
    author        = "http://localhost:{0}" -f ((Get-ServicePort -Services $services -ServiceName "author" -TargetPort 8080) ?? (Get-EnvValue -Path $envFile -Name "AUTHOR_PORT"))
    publish       = "http://localhost:{0}" -f ((Get-ServicePort -Services $services -ServiceName "publish" -TargetPort 8080) ?? (Get-EnvValue -Path $envFile -Name "PUBLISH_PORT"))
    dispatcher    = "http://localhost:{0}" -f ((Get-ServicePort -Services $services -ServiceName "dispatcher" -TargetPort 80) ?? (Get-EnvValue -Path $envFile -Name "DISPATCHER_PORT"))
    traefik       = "http://localhost:{0}/dashboard/" -f ((Get-ServicePort -Services $services -ServiceName "traefik" -TargetPort 8080) ?? (Get-EnvValue -Path $envFile -Name "TRAEFIK_PORT_DASHBOARD"))
    kibana        = "http://localhost:{0}" -f ((Get-ServicePort -Services $services -ServiceName "kibana" -TargetPort 5601) ?? (Get-EnvValue -Path $envFile -Name "KIBANA_PORT"))
    elasticsearch = "https://localhost:{0}" -f ((Get-ServicePort -Services $services -ServiceName "elasticsearch" -TargetPort 9200) ?? (Get-EnvValue -Path $envFile -Name "ES_PORT"))
}

$targetsToOpen = New-Object System.Collections.Generic.List[string]
foreach ($item in $Target) {
    if ($item -eq "all") {
        foreach ($knownTarget in $urlMap.Keys) {
            if (-not $targetsToOpen.Contains($knownTarget)) {
                $targetsToOpen.Add($knownTarget)
            }
        }
        continue
    }

    if (-not $targetsToOpen.Contains($item)) {
        $targetsToOpen.Add($item)
    }
}

foreach ($item in $targetsToOpen) {
    $url = $urlMap[$item]
    if ($url -match "localhost:$") {
        Write-Host ("Skipping {0}: no port resolved" -f $item) -ForegroundColor Yellow
        continue
    }

    Write-Host ("Opening {0}: {1}" -f $item, $url) -ForegroundColor Cyan
    Start-Process $url
}

param(
    [string]$ComposeFiles = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\scripts\Import-LocalEnv.ps1"
Import-LocalEnv -RootPath $PSScriptRoot

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title -ForegroundColor Cyan
}

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

$envFile = Join-Path $PSScriptRoot ".env"
$authorPort = Get-EnvValue -Path $envFile -Name "AUTHOR_PORT"
$publishPort = Get-EnvValue -Path $envFile -Name "PUBLISH_PORT"
$dispatcherPort = Get-EnvValue -Path $envFile -Name "DISPATCHER_PORT"
$traefikHttpPort = Get-EnvValue -Path $envFile -Name "TRAEFIK_PORT_HTTP"
$traefikHttpsPort = Get-EnvValue -Path $envFile -Name "TRAEFIK_PORT_HTTPS"
$traefikDashboardPort = Get-EnvValue -Path $envFile -Name "TRAEFIK_PORT_DASHBOARD"
$elasticPort = Get-EnvValue -Path $envFile -Name "ES_PORT"
$kibanaPort = Get-EnvValue -Path $envFile -Name "KIBANA_PORT"

Write-Section "Compose Services"
$psCommand = "docker compose $ComposeFiles ps --format json"
$serviceLines = Invoke-Expression $psCommand
$services = @($serviceLines | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })

if (-not $services -or $services.Count -eq 0) {
    Write-Host "No services found for this compose project." -ForegroundColor Yellow
} else {
    $services |
        Sort-Object Service |
        Select-Object Service, State, Health, Status, Ports |
        Format-Table -AutoSize
}

$actualAuthorPort = Get-ServicePort -Services $services -ServiceName "author" -TargetPort 8080
$actualPublishPort = Get-ServicePort -Services $services -ServiceName "publish" -TargetPort 8080
$actualDispatcherPort = Get-ServicePort -Services $services -ServiceName "dispatcher" -TargetPort 80
$actualTraefikHttpPort = Get-ServicePort -Services $services -ServiceName "traefik" -TargetPort 80
$actualTraefikHttpsPort = Get-ServicePort -Services $services -ServiceName "traefik" -TargetPort 443
$actualTraefikDashboardPort = Get-ServicePort -Services $services -ServiceName "traefik" -TargetPort 8080
$actualElasticPort = Get-ServicePort -Services $services -ServiceName "elasticsearch" -TargetPort 9200
$actualKibanaPort = Get-ServicePort -Services $services -ServiceName "kibana" -TargetPort 5601

Write-Section "Key URLs"
if ($actualAuthorPort) {
    Write-Host ("Author:               http://localhost:{0}" -f $actualAuthorPort)
} elseif ($authorPort) {
    Write-Host ("Author (.env):        http://localhost:{0}" -f $authorPort)
}
if ($actualPublishPort) {
    Write-Host ("Publish:              http://localhost:{0}" -f $actualPublishPort)
} elseif ($publishPort) {
    Write-Host ("Publish (.env):       http://localhost:{0}" -f $publishPort)
}
if ($actualDispatcherPort) {
    Write-Host ("Dispatcher:           http://localhost:{0}" -f $actualDispatcherPort)
} elseif ($dispatcherPort) {
    Write-Host ("Dispatcher (.env):    http://localhost:{0}" -f $dispatcherPort)
}
if ($actualTraefikHttpPort) {
    Write-Host ("Traefik HTTP:         http://localhost:{0}" -f $actualTraefikHttpPort)
} elseif ($traefikHttpPort) {
    Write-Host ("Traefik HTTP (.env):  http://localhost:{0}" -f $traefikHttpPort)
}
if ($actualTraefikHttpsPort) {
    Write-Host ("Traefik HTTPS:        https://localhost:{0}" -f $actualTraefikHttpsPort)
} elseif ($traefikHttpsPort) {
    Write-Host ("Traefik HTTPS (.env): https://localhost:{0}" -f $traefikHttpsPort)
}
if ($actualTraefikDashboardPort) {
    Write-Host ("Traefik Dashboard:    http://localhost:{0}" -f $actualTraefikDashboardPort)
} elseif ($traefikDashboardPort) {
    Write-Host ("Traefik Dash (.env):  http://localhost:{0}" -f $traefikDashboardPort)
}
if ($actualElasticPort) {
    Write-Host ("Elasticsearch:        https://localhost:{0}" -f $actualElasticPort)
} elseif ($elasticPort) {
    Write-Host ("Elasticsearch (.env): https://localhost:{0}" -f $elasticPort)
}
if ($actualKibanaPort) {
    Write-Host ("Kibana:               http://localhost:{0}" -f $actualKibanaPort)
} elseif ($kibanaPort) {
    Write-Host ("Kibana (.env):        http://localhost:{0}" -f $kibanaPort)
}

Write-Section "Notes"
Write-Host "URLs prefer actual published ports from running compose services."
Write-Host "If a service is not running, status.ps1 falls back to the .env default port when available."

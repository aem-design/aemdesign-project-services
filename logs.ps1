param(
    [Parameter(Position = 0)]
    [string[]]$Service = @("author"),
    [int]$Tail = 200,
    [switch]$Follow,
    [string]$ComposeFiles = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\scripts\Import-LocalEnv.ps1"
Import-LocalEnv -RootPath $PSScriptRoot

function Resolve-ServiceNames {
    param(
        [string[]]$RequestedServices,
        [string[]]$AvailableServices
    )

    $aliasMap = @{
        "all"          = $AvailableServices
        "aem"          = @("author", "publish", "dispatcher")
        "search"       = @("elasticsearch", "kibana", "logstash", "filebeat", "metricbeat")
        "observability"= @("elasticsearch", "kibana", "logstash", "filebeat", "metricbeat")
        "web"          = @("traefik", "dispatcher", "proxy", "dashboard")
    }

    $resolved = New-Object System.Collections.Generic.List[string]

    foreach ($requested in $RequestedServices) {
        if ([string]::IsNullOrWhiteSpace($requested)) {
            continue
        }

        $key = $requested.Trim().ToLowerInvariant()
        if ($aliasMap.ContainsKey($key)) {
            foreach ($serviceName in $aliasMap[$key]) {
                if ($AvailableServices -contains $serviceName -and -not $resolved.Contains($serviceName)) {
                    $resolved.Add($serviceName)
                }
            }
            continue
        }

        if ($AvailableServices -notcontains $key) {
            $availableText = ($AvailableServices | Sort-Object) -join ", "
            throw "Unknown service '$requested'. Available services: $availableText. Aliases: all, aem, search, observability, web."
        }

        if (-not $resolved.Contains($key)) {
            $resolved.Add($key)
        }
    }

    return @($resolved)
}

$availableServices = @(
    docker compose config --services |
        Where-Object { $_ -and $_.Trim() }
)

if (-not $availableServices -or $availableServices.Count -eq 0) {
    throw "No compose services were found for this project."
}

$resolvedServices = Resolve-ServiceNames -RequestedServices $Service -AvailableServices $availableServices

if (-not $resolvedServices -or $resolvedServices.Count -eq 0) {
    throw "No services were selected after resolving aliases."
}

Write-Host ("Tailing logs for: {0}" -f ($resolvedServices -join ", ")) -ForegroundColor Cyan
Write-Host ("Tail lines: {0}" -f $Tail)
Write-Host ("Follow: {0}" -f $Follow.IsPresent)

$followFlag = if ($Follow) { "-f" } else { "" }
$serviceArgs = $resolvedServices -join " "
$command = "docker compose $ComposeFiles logs $followFlag --tail $Tail $serviceArgs"

Invoke-Expression $command

param(
    [string]$AemHost = "http://localhost:4502",
    [string]$AemUsername = "admin",
    [string]$AemPassword = "admin",
    [string]$ElasticHost = "https://localhost:9200",
    [string]$ElasticUsername = "elastic",
    [string]$ElasticPassword = "elastic"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[verify] $Message" -ForegroundColor Cyan
}

function Get-BasicAuthHeader {
    param(
        [string]$Username,
        [string]$Password
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes("${Username}:${Password}")
    $token = [Convert]::ToBase64String($bytes)
    return "Basic $token"
}

function Test-Url {
    param(
        [string]$Uri,
        [hashtable]$Headers = @{},
        [switch]$SkipCertificateCheck
    )

    $params = @{
        Method  = "Get"
        Uri     = $Uri
        Headers = $Headers
    }

    if ($SkipCertificateCheck) {
        $params["SkipCertificateCheck"] = $true
    }

    $response = Invoke-WebRequest @params
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        throw "Unexpected status code $($response.StatusCode) for $Uri"
    }
}

$aemHeaders = @{
    Authorization = Get-BasicAuthHeader -Username $AemUsername -Password $AemPassword
}

$elasticHeaders = @{
    Authorization = Get-BasicAuthHeader -Username $ElasticUsername -Password $ElasticPassword
}

Write-Step "Checking AEM author at $AemHost/system/console/bundles.json"
Test-Url -Uri "$AemHost/system/console/bundles.json" -Headers $aemHeaders
Write-Step "AEM author is reachable"

Write-Step "Checking Elasticsearch at $ElasticHost"
Test-Url -Uri $ElasticHost -Headers $elasticHeaders -SkipCertificateCheck
Write-Step "Elasticsearch is reachable"

Write-Step "Running smoke-elasticsearch-proxy.ps1"
& "$PSScriptRoot\smoke-elasticsearch-proxy.ps1" `
    -AemHost $AemHost `
    -AemUsername $AemUsername `
    -AemPassword $AemPassword `
    -ElasticHost $ElasticHost `
    -ElasticUsername $ElasticUsername `
    -ElasticPassword $ElasticPassword

Write-Host ""
Write-Host "Verification passed." -ForegroundColor Green

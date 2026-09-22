param(
    [string]$IndexName = "aem-saas-site-content-test",
    [string]$DocumentId = "test-1",
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
    Write-Host "[smoke] $Message" -ForegroundColor Cyan
}

function Set-Utf8NoBomContent {
    param(
        [string]$Path,
        [string]$Value
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function New-BasicAuthHeader {
    param(
        [string]$Username,
        [string]$Password
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes("${Username}:${Password}")
    $token = [Convert]::ToBase64String($bytes)
    return @{ Authorization = "Basic $token" }
}

function Invoke-ElasticJson {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Username,
        [string]$Password,
        [object]$Body = $null,
        [switch]$SkipCertificateCheck
    )

    $headers = New-BasicAuthHeader -Username $Username -Password $Password
    $invokeParams = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
    }

    if ($Body -ne $null) {
        $invokeParams["ContentType"] = "application/json"
        $invokeParams["Body"] = ($Body -is [string]) ? $Body : ($Body | ConvertTo-Json -Depth 20 -Compress)
    }

    if ($SkipCertificateCheck) {
        $invokeParams["SkipCertificateCheck"] = $true
    }

    return Invoke-RestMethod @invokeParams
}

function Invoke-AemProxyRaw {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Username,
        [string]$Password,
        [object]$Body = $null
    )

    $tempFile = $null
    $outputFile = $null
    $commandFile = $null
    try {
        $outputFile = [System.IO.Path]::GetTempFileName()
        if ($Body -ne $null) {
            $jsonBody = ($Body -is [string]) ? $Body : ($Body | ConvertTo-Json -Depth 20 -Compress)
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Utf8NoBomContent -Path $tempFile -Value $jsonBody
            $command = 'curl.exe -s -u "{0}:{1}" -X {2} -H "Content-Type: application/json" --data-binary "@{3}" -o "{4}" "{5}"' -f `
                $Username, $Password, $Method, $tempFile, $outputFile, $Uri
        } else {
            $command = 'curl.exe -s -u "{0}:{1}" -o "{2}" "{3}"' -f $Username, $Password, $outputFile, $Uri
        }
        $commandFile = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".cmd")
        Set-Content -Path $commandFile -Value "@echo off`r`n$command`r`n" -Encoding ascii
        & $commandFile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe failed for $Method $Uri with exit code $LASTEXITCODE"
        }

        return (Get-Content -Path $outputFile -Raw).Trim()
    } finally {
        if ($null -ne $tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force
        }
        if ($null -ne $outputFile -and (Test-Path $outputFile)) {
            Remove-Item -Path $outputFile -Force
        }
        if ($null -ne $commandFile -and (Test-Path $commandFile)) {
            Remove-Item -Path $commandFile -Force
        }
    }
}

$proxyBaseUrl = "$AemHost/bin/elasticsearch.json"
$documentBody = @{
    title = "hello world"
    path  = "/content/aemdesign/test"
}

Write-Step "Verifying direct Elasticsearch availability at $ElasticHost"
$directInfo = Invoke-ElasticJson -Method Get -Uri $ElasticHost -Username $ElasticUsername -Password $ElasticPassword -SkipCertificateCheck
Write-Step "Direct Elasticsearch node: $($directInfo.name), version $($directInfo.version.number)"

Write-Step "Ensuring test index '$IndexName' exists"
try {
    Invoke-ElasticJson -Method Put -Uri "$ElasticHost/$IndexName" -Username $ElasticUsername -Password $ElasticPassword -Body @{
        settings = @{
            number_of_shards   = 1
            number_of_replicas = 0
        }
    } -SkipCertificateCheck | Out-Null
    Write-Step "Created index '$IndexName'"
} catch {
    $message = $_.ErrorDetails.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = $_.Exception.Message
    }
    if ($message -match "resource_already_exists_exception") {
        Write-Step "Index '$IndexName' already exists"
    } else {
        throw
    }
}

Write-Step "Indexing document '$DocumentId' into '$IndexName'"
$indexed = Invoke-ElasticJson `
    -Method Post `
    -Uri "$ElasticHost/$IndexName/_doc/$DocumentId?refresh=true" `
    -Username $ElasticUsername `
    -Password $ElasticPassword `
    -Body $documentBody `
    -SkipCertificateCheck
Write-Step "Document write result: $($indexed.result)"

Write-Step "Verifying index metadata through AEM proxy at $proxyBaseUrl"
$proxyIndex = Invoke-AemProxyRaw `
    -Method Get `
    -Uri "$proxyBaseUrl/$IndexName" `
    -Username $AemUsername `
    -Password $AemPassword

if ($proxyIndex -notmatch [regex]::Escape($IndexName)) {
    throw "AEM proxy did not return expected index '$IndexName'"
}
Write-Step "AEM proxy returned index metadata for '$IndexName'"

Write-Step "Running allowed POST _search through AEM proxy"
$searchBody = '{"query":{"match":{"title":"hello"}}}'
$searchInputFile = [System.IO.Path]::GetTempFileName()
$searchOutputFile = [System.IO.Path]::GetTempFileName()
$searchCommandFile = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".cmd")
try {
    Set-Utf8NoBomContent -Path $searchInputFile -Value $searchBody
    $searchCommand = 'curl.exe -s -u "{0}:{1}" -X POST -H "Content-Type: application/json" --data-binary "@{2}" -o "{3}" "{4}"' -f `
        $AemUsername, $AemPassword, $searchInputFile, $searchOutputFile, "$proxyBaseUrl/$IndexName/_search"
    Set-Content -Path $searchCommandFile -Value "@echo off`r`n$searchCommand`r`n" -Encoding ascii
    & $searchCommandFile | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "curl.exe failed for proxy search with exit code $LASTEXITCODE"
    }
    $searchResponse = (Get-Content -Path $searchOutputFile -Raw).Trim()
} finally {
    if (Test-Path $searchInputFile) {
        Remove-Item -Path $searchInputFile -Force
    }
    if (Test-Path $searchOutputFile) {
        Remove-Item -Path $searchOutputFile -Force
    }
    if (Test-Path $searchCommandFile) {
        Remove-Item -Path $searchCommandFile -Force
    }
}

$searchResult = $searchResponse | ConvertFrom-Json
$returnedTitles = @($searchResult.hits.hits | ForEach-Object { $_._source.title })
if ($returnedTitles -notcontains $documentBody.title) {
    throw "Expected title '$($documentBody.title)' in AEM proxy search response"
}

Write-Step "AEM proxy search returned document '$DocumentId' with title '$($documentBody.title)'"
Write-Host ""
Write-Host "Smoke test passed." -ForegroundColor Green
Write-Host "Direct Elasticsearch: $ElasticHost" -ForegroundColor Green
Write-Host "AEM proxy: $proxyBaseUrl/$IndexName/_search" -ForegroundColor Green

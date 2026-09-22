function Import-LocalEnv {
    param(
        [string]$RootPath = $PSScriptRoot
    )

    $localEnvPath = Join-Path $RootPath ".env.local"
    if (-not (Test-Path $localEnvPath)) {
        return
    }

    foreach ($line in Get-Content $localEnvPath) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#")) {
            continue
        }

        $separatorIndex = $trimmed.IndexOf("=")
        if ($separatorIndex -lt 1) {
            continue
        }

        $name = $trimmed.Substring(0, $separatorIndex).Trim()
        $value = $trimmed.Substring($separatorIndex + 1).Trim()

        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Trim('"')
        }

        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

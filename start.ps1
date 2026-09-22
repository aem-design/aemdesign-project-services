. "$PSScriptRoot\scripts\Import-LocalEnv.ps1"
Import-LocalEnv -RootPath $PSScriptRoot

docker compose up -d --remove-orphans
Start-Sleep -Seconds 10
Start-Process "https://dashboard.localhost/"

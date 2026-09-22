. "$PSScriptRoot\scripts\Import-LocalEnv.ps1"
Import-LocalEnv -RootPath $PSScriptRoot

docker compose stop dashboard dispatcher
Start-Sleep -Seconds 3
docker compose rm dashboard dispatcher -f
Start-Sleep -Seconds 3
docker compose up dashboard dispatcher -d

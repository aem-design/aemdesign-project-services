. "$PSScriptRoot\scripts\Import-LocalEnv.ps1"
Import-LocalEnv -RootPath $PSScriptRoot

docker compose down --remove-orphans

$CLEAN_CONTAINER = Read-Host "Prune unused Docker resources? (y/N)"
if ($CLEAN_CONTAINER -eq "y") {
    docker system prune -f
}

$CLEAN_VOLUMES = Read-Host "Prune unused Docker volumes? (y/N)"
if ($CLEAN_VOLUMES -eq "y") {
    docker volume prune -f
}

$REMOVE_PROJECT_VOLUMES = Read-Host "Remove this project's named volumes too? (y/N)"
if ($REMOVE_PROJECT_VOLUMES -eq "y") {
    $CURRENT_DIR = (Get-Item -Path ".\").Name

    docker volume rm "${CURRENT_DIR}_author-data" 2>$null
    docker volume rm "${CURRENT_DIR}_publish-data" 2>$null
    docker volume rm "${CURRENT_DIR}_dispatcher-data" 2>$null
    docker volume rm "${CURRENT_DIR}_authormongo-data" 2>$null
    docker volume rm "elastic-certs-data" 2>$null
    docker volume rm "elasticsearch-data" 2>$null
    docker volume rm "kibana-data" 2>$null
    docker volume rm "metricbeat-data" 2>$null
    docker volume rm "filebeat-data" 2>$null
    docker volume rm "logstash-data" 2>$null
}

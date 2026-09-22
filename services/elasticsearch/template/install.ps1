Write-Host "Path ${pwd} is the current working directory"

Write-Host ""
Write-Host "Uploading template to Elasticsearch"
curl -u elastic:elastic --insecure -H "Content-Type: application/json" -X PUT --data "@${PSScriptRoot}\aem.json" https://localhost:9200/_index_template/aem

Write-Host ""
Write-Host ""
Write-Host "Creating index"
curl -u elastic:elastic --insecure -X PUT https://localhost:9200/aem-saas-site-content

Write-Host ""
Write-Host ""
Write-Host "Inserting documents into index (less fields)"
curl -u elastic:elastic --insecure -X POST "https://localhost:9200/aem-saas-site-content/_doc/0000000000000001" -H "Content-Type: application/json" --data '{"docType": "asset","lastModified": "2025-03-10T14:20:00Z","path": "/content/dam/image.jpg"}'

Write-Host ""
Write-Host ""
Write-Host "Inserting documents into index (field not in template)"
curl -u elastic:elastic --insecure -X POST "https://localhost:9200/aem-saas-site-content/_doc/0000000000000002" -H "Content-Type: application/json" --data '{"docType": "asset","lastModified": "2025-03-10T14:20:00Z","path": "/content/dam/image.jpg", "newfield": "newvalue"}'

Write-Host ""
Write-Host ""
Write-Host "Update documents into index (less fields)"
curl -u elastic:elastic --insecure -X PUT "https://localhost:9200/aem-saas-site-content/_doc/0000000000000003" -H "Content-Type: application/json" --data '{"docType": "asset","lastModified": "2025-03-10T14:20:00Z","path": "/content/dam/image.jpg"}'

Write-Host ""
Write-Host ""
Write-Host "Search for newvalue in newfield"
curl -u elastic:elastic --insecure -X GET "https://localhost:9200/aem-saas-site-content/_search" -H "Content-Type: application/json" --data '{"query": {"match": {"newfield": "newvalue"}}}'


Write-Host ""
Write-Host "Done"


curl -u elastic:elastic --insecure "https://localhost:9200/aem-saas-site-content/"

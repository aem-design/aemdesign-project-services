Write-Host "Path ${pwd} is the current working directory"

# Function to generate test news pages
function Generate-TestNewsPages {
    param(
        [int]$Count = 100,
        [string]$ElasticsearchUrl = "https://localhost:9200",
        [string]$Username = "elastic",
        [string]$Password = "elastic",
        [string]$IndexName = "aem-saas-site-content-test"
    )
    
    Write-Host ""
    Write-Host "Generating $Count test news pages..." -ForegroundColor Green
    
    # Sample news titles for variety
    $newsTitles = @(
        "Australian Open 2024: Djokovic Claims Historic Victory",
        "Tennis Australia Announces New Junior Development Program",
        "Melbourne Park Upgrades Complete Ahead of Grand Slam",
        "Local Tennis Club Hosts Charity Tournament",
        "Tennis Stars Visit Sydney for Exhibition Match",
        "New Tennis Courts Open in Brisbane",
        "Tennis Australia Partners with Schools Program",
        "Grand Slam Legends Return for Special Event",
        "Tennis Equipment Donation Drive Success",
        "Junior Tennis Championship Winners Announced",
        "Tennis Coaching Certification Program Launched",
        "Regional Tennis Tournament Schedule Released",
        "Tennis Australia Celebrates 50th Anniversary",
        "New Tennis Academy Opens in Perth",
        "Tennis Stars Support Mental Health Initiative",
        "Tennis Court Maintenance Program Announced",
        "Tennis Australia Releases Annual Report",
        "Tennis Equipment Technology Advances",
        "Tennis Coaching Excellence Awards",
        "Tennis Community Fundraising Success"
    )
    
    # Sample content templates
    $contentTemplates = @(
        "The latest tennis news brings exciting developments to the sport. {0} has captured the attention of tennis enthusiasts worldwide. This significant event showcases the dedication and skill of our tennis community.",
        "Tennis Australia continues to lead the way in sports development. {0} represents our commitment to excellence and innovation in tennis. The community response has been overwhelmingly positive.",
        "Breaking news in the tennis world: {0}. This development marks a new chapter in Australian tennis history. Fans and players alike are celebrating this milestone achievement.",
        "The tennis community is buzzing with excitement over {0}. This announcement demonstrates Tennis Australia's ongoing commitment to growing the sport across the nation.",
        "Tennis enthusiasts rejoice as {0} becomes a reality. This initiative reflects the passion and dedication of everyone involved in Australian tennis development."
    )
    
    # Sample keywords for variety (simplified format)
    $keywordSets = @(
        @("News", "Tennis courts", "Australian Open"),
        @("Article", "Junior tennis", "Tournaments"),
        @("Video", "Coaching", "Exhibitions"),
        @("News", "Equipment", "Charity events"),
        @("Article", "Development", "Community events")
    )
    
    $successCount = 0
    $errorCount = 0
    
    for ($i = 1; $i -le $Count; $i++) {
        # Generate unique ID
        $docId = [System.Guid]::NewGuid().ToString("N")
        
        # Select random title and content
        $title = $newsTitles | Get-Random
        $contentTemplate = $contentTemplates | Get-Random
        $keywords = $keywordSets | Get-Random
        
        # Generate content with title
        $body = $contentTemplate -f $title
        
        # Add some variety to the content
        $additionalContent = @(
            " Tennis Australia continues to support grassroots development programs.",
            " The tennis community has shown tremendous support for this initiative.",
            " This development aligns with our long-term strategic goals.",
            " Players and coaches have expressed their enthusiasm for this news.",
            " The tennis industry is evolving with these new developments."
        )
        $body += $additionalContent | Get-Random
        
        # Generate timestamp (within last 6 months)
        $randomDays = Get-Random -Minimum 1 -Maximum 180
        $lastModified = (Get-Date).AddDays(-$randomDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        # Create document data
        $document = @{
            template = "/conf/tennisaustralia/settings/wcm/templates/news"
            path = "/content/tennisaustralia/au/en/news$i"
            docType = "page"
            lastModified = [long]((Get-Date $lastModified) - (Get-Date "1970-01-01")).TotalMilliseconds
            keywords = $keywords
            featuredImage = "/content/dam/tennisaustralia/tennis-test-hires-1.jpg"
            title = $title
            body = $body
            description = "Latest tennis news and updates from Tennis Australia"
        } | ConvertTo-Json -Compress
        
        # Upload to Elasticsearch
        try {
            $authString = $Username + ":" + $Password
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authString))
            $headers = @{
                Authorization = "Basic $base64AuthInfo"
                "Content-Type" = "application/json"
            }
            $response = Invoke-RestMethod -Uri "$ElasticsearchUrl/$IndexName/_doc/$docId" -Method POST -Headers $headers -Body $document -SkipCertificateCheck
            $successCount++
            
            if ($i % 10 -eq 0) {
                Write-Host "Generated ${i}/${Count} test news pages..." -ForegroundColor Yellow
            }
        } catch {
            $errorCount++
            Write-Host "Error creating document ${i}: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Test news pages generation completed!" -ForegroundColor Green
    Write-Host "Successfully created: $successCount pages" -ForegroundColor Green
    if ($errorCount -gt 0) {
        Write-Host "Errors encountered: $errorCount pages" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host ""
Write-Host "Uploading template to Elasticsearch"
curl -u elastic:elastic --insecure -H "Content-Type: application/json" -X PUT --data "@${PSScriptRoot}\aem.json" https://localhost:9200/_index_template/aem

Write-Host ""
Write-Host ""
Write-Host "Creating index"
curl -u elastic:elastic --insecure -X PUT https://localhost:9200/aem-saas-site-content-test

Write-Host ""
Write-Host ""
Write-Host "Inserting documents into index (less fields)"
curl -u elastic:elastic --insecure -X POST "https://localhost:9200/aem-saas-site-content-test/_doc/0000000000000001" -H "Content-Type: application/json" --data '{"docType": "asset","jcr:lastModified": "2025-03-10T14:20:00Z","path": "/content/dam/image.jpg"}'

Write-Host ""
Write-Host ""
Write-Host "Inserting documents into index (field not in template)"
curl -u elastic:elastic --insecure -X POST "https://localhost:9200/aem-saas-site-content-test/_doc/0000000000000002" -H "Content-Type: application/json" --data '{"docType": "asset","jcr:lastModified": "2025-03-10T14:20:00Z","path": "/content/dam/image.jpg", "newfield": "newvalue"}'

Write-Host ""
Write-Host ""
Write-Host "Update documents into index (less fields)"
curl -u elastic:elastic --insecure -X PUT "https://localhost:9200/aem-saas-site-content-test/_doc/0000000000000003" -H "Content-Type: application/json" --data '{"docType": "asset","jcr:lastModified": "2025-03-10T14:20:00Z","path": "/content/dam/image.jpg"}'

Write-Host ""
Write-Host ""
Write-Host "Search for newvalue in newfield"
curl -u elastic:elastic --insecure -X GET "https://localhost:9200/aem-saas-site-content-test/_search" -H "Content-Type: application/json" --data '{"query": {"match": {"newfield": "newvalue"}}}'


Write-Host ""
Write-Host "Done"


curl -u elastic:elastic --insecure "https://localhost:9200/aem-saas-site-content-test/"

Write-Host ""
Write-Host "Inserting static test document for Get Document by ID test..."
curl -u elastic:elastic --insecure -X POST "https://localhost:9200/aem-saas-site-content-test/_doc/4f8305670015c1af03f4dbd653c8bc67" -H "Content-Type: application/json" --data '{"template":"/conf/tennisaustralia/settings/wcm/templates/news","path":"/content/tennisaustralia/au/en/news0","keywords":["Video","Article","News","Tennis courts","Australian Open"],"docType":"page","lastModified":1753668981218,"title":"news","body":"1 Test Page Content 2 Test Page Content 3 4 Test Page Content this is a download link to an asset. 5 iframe 6 Test Page Content Link to page without title. 7 Test Page Content Link to a page here. 8 Test Page Content 9 Test Page Content 10 Test Page Content"}'

Write-Host ""
Write-Host "Generating test news pages for search testing..."
# Generate 100 test news pages
Generate-TestNewsPages -Count 100

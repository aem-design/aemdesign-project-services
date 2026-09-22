# Elasticsearch API Test Script
# Test all Elasticsearch API endpoints via AEM proxy
# URL format: http://localhost:4502/bin/elasticsearch.json/index-name/endpoint

# Configuration variables
param(
    [string]$IndexName = "aem-saas-site-content-test",
    [string]$AEM_HOST = "http://localhost:4502",
    [string]$USERNAME = "admin",
    [string]$PASSWORD = "admin"
)

$ELASTICSEARCH_BASE_URL = "$AEM_HOST/bin/elasticsearch.json"

# Logging setup
$SCRIPT_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$LOG_FILE = "$SCRIPT_NAME-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$LOG_PATH = Join-Path $PWD $LOG_FILE

# Function to write to both console and log file
function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $LOG_PATH -Value $logMessage
}

# Function to auto-increment test section numbers
function Write-TestSection {
    param(
        [string]$TestName,
        [string]$Color = "Cyan"
    )
    $script:TestCounter++
    Write-Log "$($script:TestCounter). $TestName" $Color
}

# Initialize test counter
$script:TestCounter = 0

Write-Log "=== Elasticsearch API Test Script ===" "Green"
Write-Log "Testing all endpoints via AEM proxy at $ELASTICSEARCH_BASE_URL" "Yellow"
Write-Log "Target Index: $IndexName" "Cyan"
Write-Log "Using credentials: $USERNAME`:$PASSWORD" "Yellow"
Write-Log "Log file: $LOG_PATH" "Cyan"
Write-Log ""

# Test 1: Basic Search
Write-TestSection "Testing Basic Search..."
$basicSearch = @{
    from = 0
    size = 10
    query = @{
        match = @{
            title = "tennis"
        }
    }
} | ConvertTo-Json -Compress

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $basicSearch
    Write-Log "Basic Search Response: $response" "Green"
} catch {
    Write-Log "Basic Search Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Test 2: Advanced Search with Filters
Write-TestSection "Testing Advanced Search with Filters..."
$advancedSearch = '{"query":{"bool":{"must":[{"multi_match":{"query":"tennis tournament","fields":["title^3","body^2","description"]}}],"filter":[{"term":{"docType":"page"}},{"range":{"lastModified":{"gte":"2024-01-01"}}}]}},"highlight":{"fields":{"title":{},"body":{}}},"sort":[{"lastModified":{"order":"desc"}},"_score"]}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $advancedSearch
    Write-Log "Advanced Search Response: $response" "Green"
} catch {
    Write-Log "Advanced Search Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Test 3: Get Document by ID
Write-TestSection "Testing Get Document by ID..."
try {
    $response = curl -u "$USERNAME`:$PASSWORD" "$ELASTICSEARCH_BASE_URL/$IndexName/_doc/4f8305670015c1af03f4dbd653c8bc67"
    Write-Log "Get Document Response: $response" "Green"
} catch {
    Write-Log "Get Document Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Test 4: Get Index Mapping
Write-TestSection "Testing Get Index Mapping..."
try {
    $response = curl -u "$USERNAME`:$PASSWORD" "$ELASTICSEARCH_BASE_URL/$IndexName/_mapping"
    Write-Log "Index Mapping Response: $response" "Green"
} catch {
    Write-Log "Index Mapping Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Test 5: Get Index Settings
Write-TestSection "Testing Get Index Settings..."
try {
    $response = curl -u "$USERNAME`:$PASSWORD" "$ELASTICSEARCH_BASE_URL/$IndexName/_settings"
    Write-Log "Index Settings Response: $response" "Green"
} catch {
    Write-Log "Index Settings Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Test 6: Count Documents
Write-TestSection "Testing Count Documents..."
$countQuery = @{
    query = @{
        match = @{
            title = "tennis"
        }
    }
} | ConvertTo-Json -Compress

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_count" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $countQuery
    Write-Log "Count Documents Response: $response" "Green"
} catch {
    Write-Log "Count Documents Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""





# Test 7: Simple Match Query
Write-TestSection "Testing Simple Match Query..."
$simpleQuery = @{
    query = @{
        match = @{
            title = "news"
        }
    }
} | ConvertTo-Json -Compress

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $simpleQuery
    Write-Log "Simple Match Response: $response" "Green"
} catch {
    Write-Log "Simple Match Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Test 8: Test Index Existence
Write-TestSection "Testing Index Existence..."
try {
    $response = curl -u "$USERNAME`:$PASSWORD" "$ELASTICSEARCH_BASE_URL/$IndexName"
    Write-Log "Index Existence Response: $response" "Green"
} catch {
    Write-Log "Index Existence Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

# Paging Tests
Write-TestSection "Testing Paging - First Page (0-9)..."
$firstPageQuery = '{"from":0,"size":10,"query":{"match_all":{}},"sort":[{"lastModified":{"order":"desc"}}]}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $firstPageQuery
    Write-Log "First Page Response: $response" "Green"
} catch {
    Write-Log "First Page Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Paging - Second Page (10-19)..."
$secondPageQuery = '{"from":10,"size":10,"query":{"match_all":{}},"sort":[{"lastModified":{"order":"desc"}}]}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $secondPageQuery
    Write-Log "Second Page Response: $response" "Green"
} catch {
    Write-Log "Second Page Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""



# Relevance Tests
Write-TestSection "Testing Relevance - Exact Match Boost..."
$exactMatchQuery = '{"from":0,"size":10,"query":{"bool":{"should":[{"match_phrase":{"title":{"query":"Tennis Coaching Excellence Awards","boost":3.0}}},{"match":{"title":{"query":"Tennis Coaching Excellence Awards","boost":1.0}}}]}}}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $exactMatchQuery
    Write-Log "Exact Match Boost Response: $response" "Green"
} catch {
    Write-Log "Exact Match Boost Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Relevance - Multi-Field Search..."
$multiFieldQuery = '{"from":0,"size":10,"query":{"multi_match":{"query":"tennis","fields":["title^3","body^2","description^1"],"type":"best_fields","fuzziness":"AUTO"}}}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $multiFieldQuery
    Write-Log "Multi-Field Search Response: $response" "Green"
} catch {
    Write-Log "Multi-Field Search Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Relevance - Function Score..."
$functionScoreQuery = '{"from":0,"size":10,"query":{"function_score":{"query":{"match":{"title":"tennis"}},"field_value_factor":{"field":"lastModified","factor":0.000001,"modifier":"log1p"},"score_mode":"sum","boost_mode":"multiply"}}}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $functionScoreQuery
    Write-Log "Function Score Response: $response" "Green"
} catch {
    Write-Log "Function Score Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Relevance - Fuzzy Search..."
$fuzzyQuery = '{"from":0,"size":10,"query":{"fuzzy":{"title":{"value":"tenis","fuzziness":"AUTO","max_expansions":50,"prefix_length":0,"transpositions":true}}}}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $fuzzyQuery
    Write-Log "Fuzzy Search Response: $response" "Green"
} catch {
    Write-Log "Fuzzy Search Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Relevance - Wildcard Search..."
$wildcardQuery = '{"from":0,"size":10,"query":{"wildcard":{"title":{"value":"*Tennis*","boost":1.0}}}}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $wildcardQuery
    Write-Log "Wildcard Search Response: $response" "Green"
} catch {
    Write-Log "Wildcard Search Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Relevance - Keyword Search..."
$keywordQuery = '{"from":0,"size":10,"query":{"term":{"keywords":"Coaching"}}}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $keywordQuery
    Write-Log "Keyword Search Response: $response" "Green"
} catch {
    Write-Log "Keyword Search Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-TestSection "Testing Relevance - Combined Query..."
$combinedQuery = '{"from":0,"size":10,"query":{"bool":{"must":[{"match":{"title":"tennis"}}],"should":[{"match_phrase":{"body":"Tennis Australia"}},{"term":{"keywords":"News"}}],"filter":[{"range":{"lastModified":{"gte":"now-6M"}}}],"minimum_should_match":1}},"sort":[{"_score":{"order":"desc"}},{"lastModified":{"order":"desc"}}]}'

try {
    $response = curl -X POST "$ELASTICSEARCH_BASE_URL/$IndexName/_search" -H "Content-Type: application/json" -u "$USERNAME`:$PASSWORD" -d $combinedQuery
    Write-Log "Combined Query Response: $response" "Green"
} catch {
    Write-Log "Combined Query Failed: $($_.Exception.Message)" "Red"
}
Write-Log ""

Write-Log "=== Test Script Completed ===" "Green"
Write-Log "Check the responses above for any errors or successful results." "Yellow"
Write-Log "Log file saved to: $LOG_PATH" "Cyan" 
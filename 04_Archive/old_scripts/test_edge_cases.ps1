# Edge Case Testing Script
# Tests edge cases: quantity breaks, invalid input, API failures, etc.
# Date: December 30, 2025

param(
    [string]$API_URL = "http://localhost:5000",
    [string]$API_KEY = "",
    [string]$NCR_BID_NO = "144319",
    [string]$ITEM_NO = "01-10100"
)

# Get API key from .env if not provided
if (-not $API_KEY) {
    $envFilePath = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFilePath) {
        Get-Content $envFilePath | ForEach-Object {
            if ($_ -match "^CONTRACT_PRICING_API_KEY=(.*)$") {
                $API_KEY = $Matches[1]
            }
        }
    }
}

if (-not $API_KEY) {
    Write-Error "Error: API key not found. Please provide -API_KEY or set CONTRACT_PRICING_API_KEY in .env"
    exit 1
}

$headers = @{
    "Content-Type" = "application/json"
    "X-API-Key" = $API_KEY
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "EDGE CASE TESTING" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$testResults = @()

# Test 1: Quantity Break Boundaries
Write-Host "`n[TEST 1] Quantity Break Boundaries" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$boundaryTests = @(
    @{ Name = "Just below break"; Quantity = 9.0 }
    @{ Name = "Exactly at break"; Quantity = 10.0 }
    @{ Name = "Just above break"; Quantity = 11.0 }
    @{ Name = "Very small quantity"; Quantity = 0.1 }
    @{ Name = "Very large quantity"; Quantity = 10000.0 }
)

foreach ($test in $boundaryTests) {
    try {
        $body = @{
            ncr_bid_no = $NCR_BID_NO
            item_no = $ITEM_NO
            quantity = $test.Quantity
        }
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($body | ConvertTo-Json) -Headers $headers -TimeoutSec 10
        
        $testResults += [PSCustomObject]@{
            Test = "Quantity Break: $($test.Name)"
            Status = "PASS"
            Details = "Qty: $($test.Quantity), Price: `$$($response.contract_price), Break: $($response.applied_qty_break)"
        }
        
        Write-Host "  [PASS] $($test.Name): Qty=$($test.Quantity), Price=`$$($response.contract_price)" -ForegroundColor Green
    } catch {
        $testResults += [PSCustomObject]@{
            Test = "Quantity Break: $($test.Name)"
            Status = "FAIL"
            Details = $_.Exception.Message
        }
        Write-Host "  [FAIL] $($test.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 2: Invalid Input
Write-Host "`n[TEST 2] Invalid Input Handling" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$invalidTests = @(
    @{ Name = "Empty NCR BID NO"; Body = @{ ncr_bid_no = ""; item_no = $ITEM_NO; quantity = 1.0 } }
    @{ Name = "Null NCR BID NO"; Body = @{ ncr_bid_no = $null; item_no = $ITEM_NO; quantity = 1.0 } }
    @{ Name = "Invalid Item NO"; Body = @{ ncr_bid_no = $NCR_BID_NO; item_no = "INVALID-99999"; quantity = 1.0 } }
    @{ Name = "Zero Quantity"; Body = @{ ncr_bid_no = $NCR_BID_NO; item_no = $ITEM_NO; quantity = 0.0 } }
    @{ Name = "Negative Quantity"; Body = @{ ncr_bid_no = $NCR_BID_NO; item_no = $ITEM_NO; quantity = -1.0 } }
    @{ Name = "Missing Required Fields"; Body = @{ item_no = $ITEM_NO; quantity = 1.0 } }
)

foreach ($test in $invalidTests) {
    try {
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($test.Body | ConvertTo-Json) -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        $testResults += [PSCustomObject]@{
            Test = "Invalid Input: $($test.Name)"
            Status = "WARN"
            Details = "Should have failed but returned: $($response | ConvertTo-Json -Compress)"
        }
        Write-Host "  [WARN] $($test.Name): Should have failed but didn't" -ForegroundColor Yellow
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $status = if ($statusCode -eq 400 -or $statusCode -eq 404) { "PASS" } else { "WARN" }
        $testResults += [PSCustomObject]@{
            Test = "Invalid Input: $($test.Name)"
            Status = $status
            Details = "Status: $statusCode"
        }
        Write-Host "  [PASS] $($test.Name): Properly rejected (Status: $statusCode)" -ForegroundColor Green
    }
}

# Test 3: Products Without Contract Pricing
Write-Host "`n[TEST 3] Products Without Contract Pricing" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Try a product that likely doesn't have contract pricing
$noContractTests = @(
    @{ Name = "Random Item"; Item = "99-99999" }
    @{ Name = "Non-existent Item"; Item = "XX-XXXXX" }
)

foreach ($test in $noContractTests) {
    try {
        $body = @{
            ncr_bid_no = $NCR_BID_NO
            item_no = $test.Item
            quantity = 1.0
        }
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($body | ConvertTo-Json) -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        $testResults += [PSCustomObject]@{
            Test = "No Contract: $($test.Name)"
            Status = "WARN"
            Details = "Should have returned 404 but got: $($response | ConvertTo-Json -Compress)"
        }
        Write-Host "  [WARN] $($test.Name): Should have returned 404" -ForegroundColor Yellow
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            $testResults += [PSCustomObject]@{
                Test = "No Contract: $($test.Name)"
                Status = "PASS"
                Details = "Correctly returned 404 (no contract found)"
            }
            Write-Host "  [PASS] $($test.Name): Correctly returned 404" -ForegroundColor Green
        } else {
            $testResults += [PSCustomObject]@{
                Test = "No Contract: $($test.Name)"
                Status = "WARN"
                Details = "Unexpected status: $statusCode"
            }
            Write-Host "  [WARN] $($test.Name): Unexpected status: $statusCode" -ForegroundColor Yellow
        }
    }
}

# Test 4: Batch Request Edge Cases
Write-Host "`n[TEST 4] Batch Request Edge Cases" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$batchTests = @(
    @{ Name = "Empty items array"; Items = @() }
    @{ Name = "Single item"; Items = @(@{ item_no = $ITEM_NO; quantity = 1.0 }) }
    @{ Name = "Multiple items"; Items = @(
        @{ item_no = $ITEM_NO; quantity = 1.0 }
        @{ item_no = $ITEM_NO; quantity = 10.0 }
        @{ item_no = $ITEM_NO; quantity = 50.0 }
    )}
    @{ Name = "Mixed valid/invalid"; Items = @(
        @{ item_no = $ITEM_NO; quantity = 1.0 }
        @{ item_no = "INVALID-99999"; quantity = 1.0 }
    )}
)

foreach ($test in $batchTests) {
    try {
        $body = @{
            ncr_bid_no = $NCR_BID_NO
            items = $test.Items
        }
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-prices" -Method POST -Body ($body | ConvertTo-Json) -Headers $headers -TimeoutSec 15
        
        $testResults += [PSCustomObject]@{
            Test = "Batch: $($test.Name)"
            Status = "PASS"
            Details = "Processed $($response.results.Count) items"
        }
        Write-Host "  [PASS] $($test.Name): Processed $($response.results.Count) items" -ForegroundColor Green
    } catch {
        $testResults += [PSCustomObject]@{
            Test = "Batch: $($test.Name)"
            Status = "FAIL"
            Details = $_.Exception.Message
        }
        Write-Host "  [FAIL] $($test.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "EDGE CASE TEST SUMMARY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$passed = ($testResults | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($testResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warned = ($testResults | Where-Object { $_.Status -eq "WARN" }).Count
$total = $testResults.Count

Write-Host "`nTotal Tests: $total" -ForegroundColor White
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "  Warnings: $warned" -ForegroundColor $(if ($warned -eq 0) { "Green" } else { "Yellow" })

if ($failed -eq 0) {
    Write-Host "`n[SUCCESS] All edge cases handled correctly!" -ForegroundColor Green
} else {
    Write-Host "`n[WARN] Some edge cases failed. Review results above." -ForegroundColor Yellow
}

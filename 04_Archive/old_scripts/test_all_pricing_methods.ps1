# Test All Pricing Methods Script
# Tests Discount (D), Override (O), Markup (M), and Amount Off (A) pricing methods
# Date: December 30, 2025

param(
    [string]$API_URL = "http://localhost:5000",
    [string]$API_KEY = ""
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
Write-Host "PRICING METHODS TEST" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nTesting all pricing methods:" -ForegroundColor Cyan
Write-Host "  - Discount % (D)" -ForegroundColor White
Write-Host "  - Override Price (O)" -ForegroundColor White
Write-Host "  - Markup % (M)" -ForegroundColor White
Write-Host "  - Amount Off (A)" -ForegroundColor White
Write-Host "`nNOTE: Run 02_Testing\FIND_PRICING_METHODS.sql first to get test data" -ForegroundColor Yellow

# Test data structure: NCR_BID_NO, ITEM_NO, Expected Method
$testCases = @()

Write-Host "`nEnter test cases (or press Enter to use defaults):" -ForegroundColor Cyan
Write-Host "Format: NCR_BID_NO,ITEM_NO,ExpectedMethod" -ForegroundColor Gray
Write-Host "Example: 144319,01-10100,D" -ForegroundColor Gray
Write-Host "`nPress Enter with empty line to start testing..." -ForegroundColor Yellow

$input = Read-Host
while ($input -ne "") {
    $parts = $input -split ","
    if ($parts.Count -eq 3) {
        $testCases += [PSCustomObject]@{
            NCR_BID_NO = $parts[0].Trim()
            ITEM_NO = $parts[1].Trim()
            ExpectedMethod = $parts[2].Trim()
        }
    }
    $input = Read-Host
}

# If no test cases provided, use defaults (Discount method - already tested)
if ($testCases.Count -eq 0) {
    Write-Host "`nNo test cases provided. Using default (Discount method):" -ForegroundColor Yellow
    $testCases = @(
        [PSCustomObject]@{ NCR_BID_NO = "144319"; ITEM_NO = "01-10100"; ExpectedMethod = "D" }
    )
}

$results = @()

foreach ($testCase in $testCases) {
    Write-Host "`n[TEST] $($testCase.ExpectedMethod) - $($testCase.ITEM_NO)" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    $body = @{
        ncr_bid_no = $testCase.NCR_BID_NO
        item_no = $testCase.ITEM_NO
        quantity = 10.0
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($body | ConvertTo-Json) -Headers $headers -TimeoutSec 10
        
        $result = [PSCustomObject]@{
            Method = $response.pricing_method
            Expected = $testCase.ExpectedMethod
            ContractPrice = $response.contract_price
            RegularPrice = $response.regular_price
            DiscountPct = $response.discount_pct
            ItemNo = $testCase.ITEM_NO
            Status = if ($response.pricing_method -eq $testCase.ExpectedMethod) { "PASS" } else { "FAIL" }
        }
        
        $results += $result
        
        Write-Host "[$($result.Status)] Pricing method: $($response.pricing_method)" -ForegroundColor $(if ($result.Status -eq "PASS") { "Green" } else { "Red" })
        Write-Host "  Contract Price: `$$($response.contract_price)" -ForegroundColor White
        Write-Host "  Regular Price: `$$($response.regular_price)" -ForegroundColor White
        
        if ($response.pricing_method -eq "D") {
            Write-Host "  Discount: $($response.discount_pct)%" -ForegroundColor White
        } elseif ($response.pricing_method -eq "O") {
            Write-Host "  Override Price Applied" -ForegroundColor White
        } elseif ($response.pricing_method -eq "M") {
            Write-Host "  Markup: $($response.discount_pct)%" -ForegroundColor White
        } elseif ($response.pricing_method -eq "A") {
            Write-Host "  Amount Off: `$$($response.discount_pct)" -ForegroundColor White
        }
        
        Write-Host "  Rule: $($response.rule_descr)" -ForegroundColor Gray
        
    } catch {
        Write-Host "[FAIL] Test failed" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        
        $results += [PSCustomObject]@{
            Method = "ERROR"
            Expected = $testCase.ExpectedMethod
            ContractPrice = $null
            RegularPrice = $null
            DiscountPct = $null
            ItemNo = $testCase.ITEM_NO
            Status = "FAIL"
        }
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "TEST SUMMARY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$total = $results.Count

Write-Host "`nTotal Tests: $total" -ForegroundColor White
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

Write-Host "`nResults by Method:" -ForegroundColor Cyan
$results | Group-Object Method | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) test(s)" -ForegroundColor White
}

if ($failed -eq 0 -and $total -gt 0) {
    Write-Host "`n[SUCCESS] All pricing methods tested successfully!" -ForegroundColor Green
} elseif ($total -eq 0) {
    Write-Host "`n[INFO] No tests run. Run 02_Testing\FIND_PRICING_METHODS.sql to get test data." -ForegroundColor Yellow
} else {
    Write-Host "`n[WARN] Some tests failed. Review errors above." -ForegroundColor Yellow
}

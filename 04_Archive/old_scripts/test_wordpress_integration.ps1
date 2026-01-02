# WordPress Integration Test Script
# Simulates WordPress plugin behavior for product page, cart, and checkout
# Date: December 30, 2025

param(
    [string]$NCR_BID_NO = "144319",
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
Write-Host "WORDPRESS INTEGRATION TEST" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nSimulating WordPress plugin behavior:" -ForegroundColor Cyan
Write-Host "  - Product page (single price lookup)" -ForegroundColor White
Write-Host "  - Cart (batch price lookup)" -ForegroundColor White
Write-Host "  - Quantity changes" -ForegroundColor White
Write-Host "  - Checkout (verify prices persist)" -ForegroundColor White

# Test 1: Product Page - Single Price Lookup
Write-Host "`n[TEST 1] Product Page - Single Price Lookup" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$testProduct = @{
    ncr_bid_no = $NCR_BID_NO
    item_no = "01-10100"
    quantity = 1.0
}

try {
    $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($testProduct | ConvertTo-Json) -Headers $headers -TimeoutSec 10
    Write-Host "[PASS] Product page price lookup successful" -ForegroundColor Green
    Write-Host "  Contract Price: `$$($response.contract_price)" -ForegroundColor White
    Write-Host "  Regular Price: `$$($response.regular_price)" -ForegroundColor White
    Write-Host "  Discount: $($response.discount_pct)%" -ForegroundColor White
    Write-Host "  Pricing Method: $($response.pricing_method)" -ForegroundColor White
} catch {
    Write-Host "[FAIL] Product page price lookup failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 2: Cart - Batch Price Lookup
Write-Host "`n[TEST 2] Cart - Batch Price Lookup" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$cartItems = @{
    ncr_bid_no = $NCR_BID_NO
    items = @(
        @{ item_no = "01-10100"; quantity = 10.0 }
        @{ item_no = "01-10100"; quantity = 25.0 }
        @{ item_no = "01-10100"; quantity = 50.0 }
    )
}

try {
    $response = Invoke-RestMethod -Uri "$API_URL/api/contract-prices" -Method POST -Body ($cartItems | ConvertTo-Json) -Headers $headers -TimeoutSec 15
    Write-Host "[PASS] Cart batch price lookup successful" -ForegroundColor Green
    Write-Host "  Items processed: $($response.results.Count)" -ForegroundColor White
    foreach ($result in $response.results) {
        Write-Host "  - $($result.item_no) (Qty: $($result.quantity)): `$$($result.contract_price)" -ForegroundColor Gray
    }
} catch {
    Write-Host "[FAIL] Cart batch price lookup failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 3: Quantity Changes - Verify Price Updates
Write-Host "`n[TEST 3] Quantity Changes - Price Updates" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$quantities = @(1.0, 5.0, 10.0, 25.0, 50.0, 100.0)
$priceChanges = @()

foreach ($qty in $quantities) {
    try {
        $body = @{
            ncr_bid_no = $NCR_BID_NO
            item_no = "01-10100"
            quantity = $qty
        }
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($body | ConvertTo-Json) -Headers $headers -TimeoutSec 10
        $priceChanges += [PSCustomObject]@{
            Quantity = $qty
            Price = $response.contract_price
            Break = $response.applied_qty_break
        }
    } catch {
        Write-Host "  [WARN] Failed for quantity $qty" -ForegroundColor Yellow
    }
}

if ($priceChanges.Count -gt 0) {
    Write-Host "[PASS] Quantity changes tested" -ForegroundColor Green
    Write-Host "`n  Quantity | Price    | Qty Break" -ForegroundColor White
    Write-Host "  ---------|----------|----------" -ForegroundColor Gray
    foreach ($change in $priceChanges) {
        Write-Host "  $($change.Quantity.ToString().PadLeft(8)) | $($change.Price.ToString('F2').PadLeft(8)) | $($change.Break)" -ForegroundColor White
    }
    
    # Check if prices change with quantity (indicates quantity breaks working)
    $uniquePrices = ($priceChanges | Select-Object -ExpandProperty Price -Unique).Count
    if ($uniquePrices -gt 1) {
        Write-Host "`n  [OK] Prices vary by quantity - quantity breaks working!" -ForegroundColor Green
    } else {
        Write-Host "`n  [INFO] Prices don't vary by quantity (may be expected)" -ForegroundColor Cyan
    }
} else {
    Write-Host "[FAIL] No quantity changes tested" -ForegroundColor Red
}

# Test 4: Checkout - Verify Prices Persist
Write-Host "`n[TEST 4] Checkout - Price Persistence" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$checkoutItems = @{
    ncr_bid_no = $NCR_BID_NO
    items = @(
        @{ item_no = "01-10100"; quantity = 10.0 }
        @{ item_no = "01-10100"; quantity = 25.0 }
    )
}

try {
    # Simulate checkout: Get prices twice (before and during checkout)
    $response1 = Invoke-RestMethod -Uri "$API_URL/api/contract-prices" -Method POST -Body ($checkoutItems | ConvertTo-Json) -Headers $headers -TimeoutSec 15
    Start-Sleep -Seconds 1
    $response2 = Invoke-RestMethod -Uri "$API_URL/api/contract-prices" -Method POST -Body ($checkoutItems | ConvertTo-Json) -Headers $headers -TimeoutSec 15
    
    $pricesMatch = $true
    for ($i = 0; $i -lt $response1.results.Count; $i++) {
        if ($response1.results[$i].contract_price -ne $response2.results[$i].contract_price) {
            $pricesMatch = $false
            break
        }
    }
    
    if ($pricesMatch) {
        Write-Host "[PASS] Prices persist through checkout simulation" -ForegroundColor Green
        Write-Host "  All prices consistent between requests" -ForegroundColor White
    } else {
        Write-Host "[WARN] Prices changed between requests" -ForegroundColor Yellow
        Write-Host "  This may indicate caching issues" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[FAIL] Checkout price persistence test failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 5: Error Handling - Invalid Input
Write-Host "`n[TEST 5] Error Handling - Invalid Input" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$errorTests = @(
    @{ name = "Missing NCR BID NO"; body = @{ item_no = "01-10100"; quantity = 1.0 } }
    @{ name = "Missing Item NO"; body = @{ ncr_bid_no = $NCR_BID_NO; quantity = 1.0 } }
    @{ name = "Invalid Item NO"; body = @{ ncr_bid_no = $NCR_BID_NO; item_no = "INVALID-SKU"; quantity = 1.0 } }
    @{ name = "Zero Quantity"; body = @{ ncr_bid_no = $NCR_BID_NO; item_no = "01-10100"; quantity = 0.0 } }
    @{ name = "Negative Quantity"; body = @{ ncr_bid_no = $NCR_BID_NO; item_no = "01-10100"; quantity = -1.0 } }
)

foreach ($test in $errorTests) {
    try {
        $response = Invoke-RestMethod -Uri "$API_URL/api/contract-price" -Method POST -Body ($test.body | ConvertTo-Json) -Headers $headers -TimeoutSec 10 -ErrorAction Stop
        Write-Host "  [WARN] $($test.name): Should have failed but didn't" -ForegroundColor Yellow
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400 -or $statusCode -eq 404) {
            Write-Host "  [PASS] $($test.name): Properly rejected (Status: $statusCode)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $($test.name): Unexpected status code: $statusCode" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "INTEGRATION TEST COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

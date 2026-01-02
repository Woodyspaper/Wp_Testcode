# Test Contract Pricing API Directly (No WordPress Login Required)
# Date: December 30, 2025

$apiUrl = "http://localhost:5000/api/contract-price"
$apiKey = "<your-api-key-here>"  # Get from .env file: CONTRACT_PRICING_API_KEY

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Contract Pricing API Direct Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# STEP 1: Get NCR BID NO from CounterPoint
Write-Host "`nSTEP 1: Get NCR BID NO from CounterPoint" -ForegroundColor Yellow
Write-Host "Run this SQL query in SSMS:" -ForegroundColor White
Write-Host @"
SELECT TOP 1
    CUST_NO,
    CUST_NAM,
    NCR_BID_NO
FROM dbo.AR_CUST
WHERE NCR_BID_NO IS NOT NULL
  AND NCR_BID_NO != ''
ORDER BY CUST_NO;
"@ -ForegroundColor Gray

Write-Host "`nEnter NCR BID NO from query result:" -ForegroundColor Yellow
$ncrBidNo = Read-Host "NCR BID NO"

if ([string]::IsNullOrWhiteSpace($ncrBidNo)) {
    Write-Host "`n[ERROR] NCR BID NO is required!" -ForegroundColor Red
    exit 1
}

# STEP 2: Get Product SKU
Write-Host "`nSTEP 2: Enter Product SKU to test" -ForegroundColor Yellow
Write-Host "Example: 01-10100" -ForegroundColor Gray
$itemNo = Read-Host "Product SKU"

if ([string]::IsNullOrWhiteSpace($itemNo)) {
    Write-Host "`n[ERROR] Product SKU is required!" -ForegroundColor Red
    exit 1
}

# STEP 3: Set Quantity
Write-Host "`nSTEP 3: Enter Quantity" -ForegroundColor Yellow
$quantity = Read-Host "Quantity (default: 1.0)"

if ([string]::IsNullOrWhiteSpace($quantity)) {
    $quantity = "1.0"
}

# STEP 4: Test API
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing API..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NCR BID NO: $ncrBidNo" -ForegroundColor White
Write-Host "Item No: $itemNo" -ForegroundColor White
Write-Host "Quantity: $quantity" -ForegroundColor White

$body = @{
    ncr_bid_no = $ncrBidNo
    item_no = $itemNo
    quantity = [double]$quantity
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "X-API-Key" = $apiKey
}

try {
    Write-Host "`nCalling API..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body -Headers $headers -ErrorAction Stop
    
    Write-Host "`n[SUCCESS] API Response:" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 10 | Write-Host
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Test Results:" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    if ($response.contract_price) {
        Write-Host "Contract Price: $($response.contract_price)" -ForegroundColor Green
        Write-Host "Pricing Method: $($response.pricing_method)" -ForegroundColor White
        if ($response.quantity_break) {
            Write-Host "Quantity Break: $($response.quantity_break)" -ForegroundColor White
        }
        Write-Host "`n[OK] Contract pricing is working!" -ForegroundColor Green
    } else {
        Write-Host "No contract price found (may be normal if no contract pricing rule exists)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`n[ERROR] API Call Failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    
    if ($_.ErrorDetails) {
        Write-Host "`nError Details:" -ForegroundColor Yellow
        Write-Host $_.ErrorDetails.Message -ForegroundColor White
    }
    
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Test Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNext: Check database logs:" -ForegroundColor Cyan
Write-Host "  SELECT TOP 10 * FROM dbo.USER_PRICING_API_LOG ORDER BY REQUEST_DT DESC;" -ForegroundColor White

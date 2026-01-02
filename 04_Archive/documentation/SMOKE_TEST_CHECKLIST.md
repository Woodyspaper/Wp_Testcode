# Smoke Test Checklist - Final Step

**Date:** December 30, 2025  
**Status:** Plugin configured - ready for testing

---

## ✅ **CONFIGURATION COMPLETE**

**Plugin Settings:**
- ✅ API URL: `http://10.1.10.49:5000/api/contract-price`
- ✅ API Key: `w0YyAKgirU1l2LXoa3kG4mR8vdSbqxzj`
- ✅ Cache TTL: `300`

**All settings saved successfully!**

---

## 🧪 **SMOKE TEST CHECKLIST**

### **Test 1: API Health Check**

**On API Server (Your Computer):**

```powershell
# Test API health endpoint
python test_api_health.py
```

**Expected Result:**
```json
{
  "status": "ok",
  "database": "connected",
  "query_latency_ms": < 200,
  "timestamp": "..."
}
```

**OR manually:**
```powershell
Invoke-WebRequest -Uri "http://localhost:5000/api/health" -UseBasicParsing
```

**✅ Pass:** API responds with `"status": "ok"` and `"database": "connected"`

---

### **Test 2: API Service Status**

**On API Server:**

```powershell
# Check service is running
Get-Service ContractPricingAPIWaitress
```

**Expected Result:**
```
Status   Name                           DisplayName
------   ----                           -----------
Running  ContractPricingAPIWaitress    Contract Pricing API (Waitress)
```

**✅ Pass:** Service status is "Running"

---

### **Test 3: Single Price Request (API)**

**On API Server:**

```powershell
# Test single price request
$body = @{
    ncr_bid_no = "TEST_BID"
    item_no = "01-10100"
    quantity = 1.0
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "X-API-Key" = "w0YyAKgirU1l2LXoa3kG4mR8vdSbqxzj"
}

Invoke-RestMethod -Uri "http://localhost:5000/api/contract-price" -Method POST -Body $body -Headers $headers
```

**Expected Result:**
```json
{
  "contract_price": 12.50,
  "pricing_method": "contract",
  "quantity_break": null,
  "ncr_bid_no": "TEST_BID",
  "item_no": "01-10100",
  "quantity": 1.0
}
```

**✅ Pass:** API returns a contract price (or `null` if no contract pricing available)

---

### **Test 4: WordPress Plugin Connection**

**In WordPress Admin:**

1. **View a product page** as a logged-in contract customer
2. **Check if contract pricing is applied**
3. **Or check WordPress debug log** for any errors

**Expected Result:**
- ✅ No errors in WordPress
- ✅ Product price reflects contract pricing (if available)
- ✅ No connection errors

---

### **Test 5: API Logs Verification**

**On API Server:**

```powershell
# Check recent API requests
Get-Content logs\pricing_api_waitress.log -Tail 20
```

**Expected Result:**
- ✅ Should see API requests from WordPress server IP (160.153.0.177)
- ✅ Requests show successful responses (200 OK)
- ✅ No error messages

**✅ Pass:** API logs show requests from WordPress server

---

### **Test 6: Database Logging**

**In SSMS (SQL Server Management Studio):**

```sql
-- Check recent API requests in log table
SELECT TOP 20 
    REQUEST_DT,
    NCR_BID_NO,
    ITEM_NO,
    QUANTITY,
    CONTRACT_PRICE,
    RESPONSE_TIME_MS,
    STATUS_CODE
FROM dbo.USER_PRICING_API_LOG
ORDER BY REQUEST_DT DESC;
```

**Expected Result:**
- ✅ Should see recent requests
- ✅ `STATUS_CODE` = 200 (success)
- ✅ `CONTRACT_PRICE` populated (if contract pricing available)

**✅ Pass:** Database log shows API requests

---

### **Test 7: Metrics View**

**In SSMS:**

```sql
-- Check daily metrics
SELECT * 
FROM dbo.VI_PRICING_API_METRICS
ORDER BY METRIC_DATE DESC;
```

**Expected Result:**
- ✅ Today's date shows API calls
- ✅ Error count is 0 or low
- ✅ Average response time is reasonable (< 500ms)

**✅ Pass:** Metrics show successful API usage

---

### **Test 8: Cart Quantity Break Test**

**In WordPress (as logged-in contract customer):**

1. **Add product to cart** with quantity 1
2. **Note the price**
3. **Change quantity** to a higher amount (e.g., 10)
4. **Check if price updates** (quantity breaks may apply)

**Expected Result:**
- ✅ Price updates when quantity changes
- ✅ Different prices for different quantities (if quantity breaks configured)
- ✅ No errors in cart

**✅ Pass:** Quantity breaks work correctly

---

### **Test 9: Batch Pricing Test**

**In WordPress (as logged-in contract customer):**

1. **Add multiple products to cart**
2. **Check cart total**
3. **Verify all products use contract pricing**

**Expected Result:**
- ✅ Multiple products get contract prices
- ✅ Cart total is correct
- ✅ API uses batch endpoint (check logs)

**✅ Pass:** Batch pricing works for multiple items

---

## 📋 **QUICK TEST SUMMARY**

**Minimum Tests to Run:**

1. ✅ **API Health:** `python test_api_health.py`
2. ✅ **Service Status:** `Get-Service ContractPricingAPIWaitress`
3. ✅ **API Logs:** `Get-Content logs\pricing_api_waitress.log -Tail 20`
4. ✅ **WordPress Product:** View product as contract customer
5. ✅ **Database Log:** Check `USER_PRICING_API_LOG` table

**If all 5 pass, deployment is successful!**

---

## 🎯 **DEPLOYMENT COMPLETE CHECKLIST**

- [x] Step 1: SQL Server Setup
- [x] Step 2: Configure .env File
- [x] Step 3: Test API Locally
- [x] Step 4: Deploy API to Production
- [x] Step 5: Configure Firewall
- [x] Step 6: Upload WordPress Plugins
- [x] Step 7: Configure WordPress
- [ ] Step 8: Run Smoke Tests ← **YOU ARE HERE**

**Progress: 7/8 steps complete (87.5%)**

---

## 🚀 **AFTER SMOKE TESTS PASS**

**Deployment is complete!**

**Next steps:**
1. ✅ Monitor API logs for first few days
2. ✅ Check database metrics weekly
3. ✅ Verify contract pricing is working for customers
4. ✅ Address any issues as they arise

---

**Last Updated:** December 30, 2025

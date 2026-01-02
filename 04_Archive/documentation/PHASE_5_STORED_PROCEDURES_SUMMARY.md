# Phase 5: Stored Procedures Summary

**Date:** December 31, 2025  
**Status:** Procedures created, ready for testing

---

## ✅ **STORED PROCEDURES CREATED**

### **1. sp_ValidateStagedOrder**
**Purpose:** Validate staged order before processing

**Parameters:**
- `@StagingID` - ID from USER_ORDER_STAGING

**Returns:**
- `@IsValid` - 1 if valid, 0 if invalid
- `@ErrorMessage` - Error message if invalid

**Validations:**
- Staging record exists
- Customer exists in AR_CUST
- Line items JSON present
- Order not already applied

---

### **2. sp_CreateOrderFromStaging**
**Purpose:** Main procedure to create CounterPoint order from staging

**Parameters:**
- `@StagingID` - ID from USER_ORDER_STAGING

**Returns:**
- `@DocID` - Created document ID (bigint)
- `@TktNo` - Created ticket number (varchar(15))
- `@Success` - 1 if successful, 0 if failed
- `@ErrorMessage` - Error message if failed

**What it does:**
1. Validates staging record
2. Creates PS_DOC_HDR (order header)
3. Generates DOC_ID and TKT_NO
4. Creates PS_DOC_HDR_TOT (order totals)
5. Calls sp_CreateOrderLines to create line items
6. Updates staging record with CP_DOC_ID

---

### **3. sp_CreateOrderLines**
**Purpose:** Parse JSON line items and create PS_DOC_LIN records

**Parameters:**
- `@DocID` - Document ID from PS_DOC_HDR
- `@LineItemsJSON` - JSON array of line items

**Returns:**
- `@LinesCreated` - Number of lines created
- `@TotLinDisc` - Total line discounts
- `@Success` - 1 if successful, 0 if failed
- `@ErrorMessage` - Error message if failed

**What it does:**
1. Parses JSON using OPENJSON (SQL Server 2016+)
2. Validates each item exists in IM_ITEM
3. Gets item details (SELL_UNIT, STK_LOC_ID, CATEG_COD)
4. Calculates extended price and discounts
5. Creates PS_DOC_LIN records sequentially

---

## ⚠️ **IMPORTANT NOTES**

### **Document ID Generation:**
- Currently uses `SCOPE_IDENTITY()` after INSERT
- **May need adjustment** if PS_DOC_HDR.DOC_ID is not IDENTITY
- CounterPoint may have its own ID generation mechanism
- **Test required:** Verify DOC_ID generation works correctly

### **Ticket Number Generation:**
- Format: `Station-TicketNumber` (e.g., "101-000001")
- Currently generates by finding max existing number + 1
- **May need adjustment** based on CounterPoint's actual generation
- **Test required:** Verify TKT_NO format matches CounterPoint

### **JSON Parsing:**
- Uses SQL Server 2016+ `OPENJSON` function
- Expects JSON structure: `[{"sku": "...", "name": "...", "quantity": ..., "price": ..., "total": ...}]`
- Matches structure from `woo_orders.py`

---

## 🔍 **TESTING CHECKLIST**

### **Before Production:**
- [ ] Test DOC_ID generation (verify it's actually IDENTITY or needs different approach)
- [ ] Test TKT_NO generation (verify format matches CounterPoint)
- [ ] Test with sample staged order
- [ ] Verify all three tables created correctly
- [ ] Verify totals calculations
- [ ] Verify line items created correctly
- [ ] Test error handling (invalid customer, missing items, etc.)

---

## 📝 **USAGE EXAMPLE**

```sql
-- Validate order first
DECLARE @IsValid BIT;
DECLARE @ErrorMsg NVARCHAR(500);
EXEC sp_ValidateStagedOrder @StagingID = 1, @IsValid = @IsValid OUTPUT, @ErrorMessage = @ErrorMsg OUTPUT;

-- If valid, create order
IF @IsValid = 1
BEGIN
    DECLARE @DocID BIGINT;
    DECLARE @TktNo VARCHAR(15);
    DECLARE @Success BIT;
    DECLARE @CreateError NVARCHAR(500);
    
    EXEC sp_CreateOrderFromStaging 
        @StagingID = 1,
        @DocID = @DocID OUTPUT,
        @TktNo = @TktNo OUTPUT,
        @Success = @Success OUTPUT,
        @ErrorMessage = @CreateError OUTPUT;
    
    IF @Success = 1
        PRINT 'Order created: ' + CAST(@DocID AS VARCHAR) + ' / ' + @TktNo;
    ELSE
        PRINT 'Error: ' + @CreateError;
END
```

---

---

## 🐍 **PYTHON SCRIPT CREATED**

### **cp_order_processor.py**
**Purpose:** Python interface to call the stored procedures

**Features:**
- List pending staged orders
- Show detailed order information
- Validate individual orders
- Process single orders or batches
- Update validation status in staging table
- Comprehensive error handling and logging

**Usage:**
```bash
# List pending orders
python cp_order_processor.py list

# Show order details
python cp_order_processor.py show 123

# Validate an order
python cp_order_processor.py validate 123

# Process a single order
python cp_order_processor.py process 123

# Process all pending orders
python cp_order_processor.py process --all

# Process a batch
python cp_order_processor.py process --batch WOO_ORDERS_20251231_120000
```

**Integration:**
- Works with `woo_orders.py` (which stages orders)
- Calls stored procedures via pyodbc
- Updates staging table with validation/processing status
- Provides detailed feedback and error messages

---

**Last Updated:** December 31, 2025

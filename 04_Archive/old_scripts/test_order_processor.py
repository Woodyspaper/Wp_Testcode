"""
test_order_processor.py - Test the order processor Python script

This script tests the cp_order_processor.py functionality by:
1. Creating test data in USER_ORDER_STAGING
2. Testing validation
3. Testing order creation
4. Verifying results
"""

import sys
import json
from datetime import datetime
from typing import Optional, Tuple

from database import get_connection, run_query
from cp_order_processor import (
    validate_staged_order,
    create_order_from_staging,
    list_pending_orders,
    show_order_details
)


def find_test_customer() -> Optional[str]:
    """Find a valid customer for testing."""
    result = run_query("""
        SELECT TOP 1 CUST_NO
        FROM dbo.AR_CUST
        WHERE CUST_NO IS NOT NULL
        ORDER BY CUST_NO
    """)
    
    if result:
        return result[0]['CUST_NO']
    return None


def find_test_items() -> Tuple[Optional[str], Optional[str]]:
    """Find valid items for testing."""
    result = run_query("""
        SELECT TOP 2 ITEM_NO
        FROM dbo.IM_ITEM
        WHERE STAT = 'A'
        ORDER BY ITEM_NO
    """)
    
    if len(result) >= 2:
        return result[0]['ITEM_NO'], result[1]['ITEM_NO']
    elif len(result) == 1:
        return result[0]['ITEM_NO'], result[0]['ITEM_NO']
    return None, None


def create_test_staged_order(cust_no: str, item1: str, item2: str) -> int:
    """Create a test staged order and return the staging ID."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        # Create line items JSON
        line_items = [
            {
                "sku": item1,
                "name": "Test Product 1",
                "quantity": 2,
                "price": 10.50,
                "total": 21.00
            },
            {
                "sku": item2,
                "name": "Test Product 2",
                "quantity": 1,
                "price": 15.75,
                "total": 15.75
            }
        ]
        
        line_items_json = json.dumps(line_items)
        
        # Insert test order
        cursor.execute("""
            INSERT INTO dbo.USER_ORDER_STAGING (
                BATCH_ID,
                WOO_ORDER_ID,
                WOO_ORDER_NO,
                CUST_NO,
                CUST_EMAIL,
                ORD_DAT,
                ORD_STATUS,
                PMT_METH,
                SHIP_VIA,
                SUBTOT,
                SHIP_AMT,
                TAX_AMT,
                DISC_AMT,
                TOT_AMT,
                SHIP_NAM,
                SHIP_ADRS_1,
                SHIP_CITY,
                SHIP_STATE,
                SHIP_ZIP_COD,
                SHIP_CNTRY,
                LINE_ITEMS_JSON,
                IS_VALIDATED,
                IS_APPLIED
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            'TEST_ORDER_PYTHON',
            999997,
            'TEST-999997',
            cust_no,
            'test@example.com',
            datetime.now().date(),
            'processing',
            'Credit Card',
            'Standard Shipping',
            36.75,  # Subtotal
            5.00,   # Shipping
            2.50,   # Tax
            0.00,   # Discount
            44.25,  # Total
            'Test Customer',
            '123 Test Street',
            'Miami',
            'FL',
            '33101',
            'US',
            line_items_json,
            0,  # Not validated
            0   # Not applied
        ))
        
        conn.commit()
        
        # Get the staging ID by querying using the unique WOO_ORDER_ID
        cursor.execute("""
            SELECT STAGING_ID 
            FROM dbo.USER_ORDER_STAGING 
            WHERE WOO_ORDER_ID = 999997 AND BATCH_ID = 'TEST_ORDER_PYTHON'
        """)
        result = cursor.fetchone()
        if result:
            staging_id = int(result[0])
        else:
            raise Exception("Could not retrieve staging ID after insert")
        
        return staging_id
        
    except Exception as e:
        conn.rollback()
        print(f"Error creating test order: {e}")
        raise
    finally:
        cursor.close()
        conn.close()


def cleanup_test_data():
    """Clean up test data."""
    conn = get_connection()
    cursor = conn.cursor()
    
    try:
        # Get test order DOC_IDs before deleting staging
        test_orders = run_query("""
            SELECT CP_DOC_ID
            FROM dbo.USER_ORDER_STAGING
            WHERE BATCH_ID = 'TEST_ORDER_PYTHON' AND CP_DOC_ID IS NOT NULL
        """)
        
        # Delete from PS_DOC_LIN, PS_DOC_HDR_TOT, PS_DOC_HDR
        for order in test_orders:
            doc_id = order['CP_DOC_ID']
            try:
                cursor.execute("DELETE FROM dbo.PS_DOC_LIN WHERE DOC_ID = ?", (doc_id,))
                cursor.execute("DELETE FROM dbo.PS_DOC_HDR_TOT WHERE DOC_ID = ?", (doc_id,))
                cursor.execute("DELETE FROM dbo.PS_DOC_HDR WHERE DOC_ID = ?", (doc_id,))
            except Exception as e:
                print(f"  Warning: Could not delete DOC_ID {doc_id}: {e}")
        
        # Delete staging records
        cursor.execute("DELETE FROM dbo.USER_ORDER_STAGING WHERE BATCH_ID = 'TEST_ORDER_PYTHON'")
        conn.commit()
        print("[OK] Test data cleaned up")
        
    except Exception as e:
        conn.rollback()
        print(f"Error cleaning up: {e}")
    finally:
        cursor.close()
        conn.close()


def test_validation(staging_id: int):
    """Test validation function."""
    print(f"\n{'='*80}")
    print("TEST 1: Validation")
    print(f"{'='*80}")
    
    is_valid, error_msg = validate_staged_order(staging_id)
    
    if is_valid:
        print("[OK] Validation PASSED")
        print(f"   Order {staging_id} is valid")
    else:
        print("[FAIL] Validation FAILED")
        print(f"   Error: {error_msg}")
    
    return is_valid


def test_order_creation(staging_id: int):
    """Test order creation function."""
    print(f"\n{'='*80}")
    print("TEST 2: Order Creation")
    print(f"{'='*80}")
    
    success, doc_id, tkt_no, error_msg = create_order_from_staging(staging_id)
    
    if success:
        print("[OK] Order Creation PASSED")
        print(f"   DOC_ID: {doc_id}")
        print(f"   TKT_NO: {tkt_no}")
        
        # Verify the order was created
        print(f"\n   Verifying order in database...")
        order = run_query("""
            SELECT DOC_ID, TKT_NO, CUST_NO, TKT_DT
            FROM dbo.PS_DOC_HDR
            WHERE DOC_ID = ?
        """, (doc_id,))
        
        if order:
            print(f"   [OK] Found order in PS_DOC_HDR")
            print(f"      CUST_NO: {order[0]['CUST_NO']}")
            print(f"      TKT_DT: {order[0]['TKT_DT']}")
        
        # Verify line items
        lines = run_query("""
            SELECT COUNT(*) AS LINE_COUNT
            FROM dbo.PS_DOC_LIN
            WHERE DOC_ID = ?
        """, (doc_id,))
        
        if lines:
            print(f"   [OK] Found {lines[0]['LINE_COUNT']} line items in PS_DOC_LIN")
        
        # Verify totals
        totals = run_query("""
            SELECT SUB_TOT, TAX_AMT, TOT
            FROM dbo.PS_DOC_HDR_TOT
            WHERE DOC_ID = ?
        """, (doc_id,))
        
        if totals:
            print(f"   [OK] Found totals in PS_DOC_HDR_TOT")
            print(f"      Subtotal: ${totals[0]['SUB_TOT']:.2f}")
            print(f"      Tax: ${totals[0]['TAX_AMT']:.2f}")
            print(f"      Total: ${totals[0]['TOT']:.2f}")
        
        return True, doc_id, tkt_no
    else:
        print("[FAIL] Order Creation FAILED")
        print(f"   Error: {error_msg}")
        return False, None, None


def test_duplicate_prevention(staging_id: int):
    """Test that duplicate processing is prevented."""
    print(f"\n{'='*80}")
    print("TEST 3: Duplicate Prevention")
    print(f"{'='*80}")
    
    success, doc_id, tkt_no, error_msg = create_order_from_staging(staging_id)
    
    if not success:
        print("[OK] Duplicate Prevention PASSED")
        print(f"   Correctly rejected duplicate processing")
        print(f"   Error: {error_msg}")
        return True
    else:
        print("[FAIL] Duplicate Prevention FAILED")
        print(f"   Should have rejected duplicate but did not")
        return False


def main():
    """Run all tests."""
    print("="*80)
    print("ORDER PROCESSOR TEST SUITE")
    print("="*80)
    print()
    
    # Find test data
    print("Finding test data...")
    cust_no = find_test_customer()
    item1, item2 = find_test_items()
    
    if not cust_no:
        print("[FAIL] ERROR: No active customer found in AR_CUST")
        print("   Please create at least one active customer for testing")
        return
    
    if not item1 or not item2:
        print("[FAIL] ERROR: Not enough active items found in IM_ITEM")
        print("   Please ensure there are at least 2 active items for testing")
        return
    
    print(f"[OK] Test Customer: {cust_no}")
    print(f"[OK] Test Items: {item1}, {item2}")
    print()
    
    # Cleanup any previous test data
    print("Cleaning up previous test data...")
    cleanup_test_data()
    print()
    
    # Create test order
    print("Creating test staged order...")
    try:
        staging_id = create_test_staged_order(cust_no, item1, item2)
        print(f"[OK] Test order created: STAGING_ID = {staging_id}")
    except Exception as e:
        print(f"[FAIL] Failed to create test order: {e}")
        return
    
    print()
    
    # Show order details
    print("Test Order Details:")
    show_order_details(staging_id)
    print()
    
    # Run tests
    test_results = {}
    
    # Test 1: Validation
    test_results['validation'] = test_validation(staging_id)
    
    if not test_results['validation']:
        print("\n⚠️  Validation failed. Skipping order creation test.")
        cleanup_test_data()
        return
    
    # Test 2: Order Creation
    success, doc_id, tkt_no = test_order_creation(staging_id)
    test_results['creation'] = success
    
    if success:
        # Test 3: Duplicate Prevention
        test_results['duplicate_prevention'] = test_duplicate_prevention(staging_id)
    
    # Summary
    print(f"\n{'='*80}")
    print("TEST SUMMARY")
    print(f"{'='*80}")
    print()
    print("Test Results:")
    print(f"  Validation:           {'[OK] PASSED' if test_results.get('validation') else '[FAIL] FAILED'}")
    print(f"  Order Creation:       {'[OK] PASSED' if test_results.get('creation') else '[FAIL] FAILED'}")
    if 'duplicate_prevention' in test_results:
        print(f"  Duplicate Prevention: {'[OK] PASSED' if test_results['duplicate_prevention'] else '[FAIL] FAILED'}")
    print()
    
    if success:
        print(f"Created Order Details:")
        print(f"  STAGING_ID: {staging_id}")
        print(f"  DOC_ID: {doc_id}")
        print(f"  TKT_NO: {tkt_no}")
        print()
    
    # Ask about cleanup
    print("Test data cleanup:")
    print("  Test orders were created in PS_DOC_HDR, PS_DOC_LIN, PS_DOC_HDR_TOT")
    print("  Staging records will be cleaned up automatically")
    print()
    
    response = input("Clean up test data now? (y/n): ").strip().lower()
    if response == 'y':
        cleanup_test_data()
    else:
        print("Test data left in database for manual inspection")
        print("Run cleanup_test_data() manually or delete:")
        if doc_id:
            print(f"  DELETE FROM dbo.PS_DOC_LIN WHERE DOC_ID = {doc_id};")
            print(f"  DELETE FROM dbo.PS_DOC_HDR_TOT WHERE DOC_ID = {doc_id};")
            print(f"  DELETE FROM dbo.PS_DOC_HDR WHERE DOC_ID = {doc_id};")
        print(f"  DELETE FROM dbo.USER_ORDER_STAGING WHERE BATCH_ID = 'TEST_ORDER_PYTHON';")
    
    print()
    print("="*80)
    print("TEST COMPLETE")
    print("="*80)


if __name__ == "__main__":
    main()

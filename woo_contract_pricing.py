"""
woo_contract_pricing.py - Contract pricing lookup for WooCommerce integration

Handles:
  - Lookup contract prices from CounterPoint database
  - Cache contract prices for performance
  - Handle quantity breaks
  - Fallback to tier pricing if no contract

Usage:
    from woo_contract_pricing import get_contract_price
    
    price = get_contract_price(
        ncr_bid_no='144319',
        item_no='01-10100',
        quantity=10,
        loc_id='01'
    )
"""

import logging
from typing import Optional, Dict
from functools import lru_cache
from datetime import datetime, timedelta

from database import get_connection, connection_ctx
from config import load_integration_config

logger = logging.getLogger(__name__)

# Cache contract prices for 5 minutes to reduce database load
CACHE_TTL_SECONDS = 300


def get_contract_price(
    ncr_bid_no: str,
    item_no: str,
    quantity: float = 1.0,
    loc_id: str = '*'  # Default to '*' (wildcard/default location)
) -> Optional[Dict]:
    """
    Get contract price for a customer/product/quantity combination.
    
    Args:
        ncr_bid_no: Customer's NCR BID # (from AR_CUST.NCR_BID_NO)
        item_no: Product SKU (from IM_ITEM.ITEM_NO)
        quantity: Order quantity (default: 1.0)
        loc_id: Location ID (default: '01')
    
    Returns:
        Dict with price details or None if no contract applies:
        {
            'contract_price': float,
            'regular_price': float,
            'discount_pct': float | None,
            'pricing_method': str,  # 'D', 'O', 'M', 'A'
            'rule_descr': str,
            'applied_qty_break': float,
            'requested_quantity': float
        }
    """
    if not ncr_bid_no or not item_no:
        logger.debug(f"Missing required parameters: ncr_bid_no={ncr_bid_no}, item_no={item_no}")
        return None
    
    try:
        with connection_ctx() as conn:
            cur = conn.cursor()
            
            # Call the SQL function we created
            query = """
                SELECT 
                    CONTRACT_PRICE,
                    REGULAR_PRICE,
                    DISCOUNT_PCT,
                    PRICING_METHOD,
                    RULE_DESCR,
                    APPLIED_QTY_BREAK,
                    REQUESTED_QUANTITY
                FROM dbo.fn_GetContractPrice(?, ?, ?, ?)
            """
            
            cur.execute(query, (ncr_bid_no, item_no, quantity, loc_id))
            row = cur.fetchone()
            
            if row:
                return {
                    'contract_price': float(row[0]) if row[0] is not None else None,
                    'regular_price': float(row[1]) if row[1] is not None else None,
                    'discount_pct': float(row[2]) if row[2] is not None else None,
                    'pricing_method': row[3],
                    'rule_descr': row[4],
                    'applied_qty_break': float(row[5]) if row[5] is not None else None,
                    'requested_quantity': float(row[6]) if row[6] is not None else None
                }
            
            return None
            
    except Exception as e:
        logger.error(f"Error getting contract price: {e}", exc_info=True)
        return None


def get_customer_ncr_bid(woo_customer_id: int) -> Optional[str]:
    """
    Get customer's NCR BID # from WooCommerce customer meta.
    
    Args:
        woo_customer_id: WooCommerce customer/user ID
    
    Returns:
        NCR BID # string or None if not found
    """
    try:
        from woo_client import WooClient
        config = load_integration_config()
        client = WooClient(config)
        
        customer = client.get_customer(woo_customer_id)
        if customer:
            # Look for NCR BID # in meta_data
            meta_data = customer.get('meta_data', [])
            for meta in meta_data:
                if meta.get('key') == 'cp_ncr_bid_no':
                    ncr_bid = meta.get('value', '').strip()
                    return ncr_bid if ncr_bid else None
        
        return None
        
    except Exception as e:
        logger.error(f"Error getting customer NCR BID #: {e}", exc_info=True)
        return None


def get_product_price_for_customer(
    item_no: str,
    woo_customer_id: Optional[int] = None,
    quantity: float = 1.0,
    loc_id: str = '*'  # Default to '*' (wildcard/default location)
) -> Optional[float]:
    """
    Get the best available price for a product/customer combination.
    
    Priority:
    1. Contract pricing (if customer has NCR BID #)
    2. Tier pricing (if customer has tier role)
    3. Regular price (fallback)
    
    Args:
        item_no: Product SKU
        woo_customer_id: WooCommerce customer/user ID (optional)
        quantity: Order quantity (default: 1.0)
        loc_id: Location ID (default: '01')
    
    Returns:
        Best available price or None if product not found
    """
    # Try contract pricing first
    if woo_customer_id:
        ncr_bid = get_customer_ncr_bid(woo_customer_id)
        if ncr_bid:
            contract_price_data = get_contract_price(ncr_bid, item_no, quantity, loc_id)
            if contract_price_data and contract_price_data.get('contract_price'):
                logger.debug(f"Using contract price for {item_no}: {contract_price_data['contract_price']}")
                return contract_price_data['contract_price']
    
    # Fallback to regular price (tier pricing handled by WooCommerce plugin)
    # This function is called when contract pricing is not available
    # Tier pricing should be handled by existing WooCommerce pricing plugin
    return None


# Cache wrapper for contract prices
# Cache key: (ncr_bid_no, item_no, quantity, loc_id)
_contract_price_cache = {}
_cache_timestamps = {}


def _get_cache_key(ncr_bid_no: str, item_no: str, quantity: float, loc_id: str) -> str:
    """Generate cache key for contract price lookup."""
    return f"{ncr_bid_no}:{item_no}:{quantity}:{loc_id}"


def get_contract_price_cached(
    ncr_bid_no: str,
    item_no: str,
    quantity: float = 1.0,
    loc_id: str = '*'  # Default to '*' (wildcard/default location)
) -> Optional[Dict]:
    """
    Get contract price with caching.
    
    Caches results for CACHE_TTL_SECONDS to reduce database load.
    """
    cache_key = _get_cache_key(ncr_bid_no, item_no, quantity, loc_id)
    now = datetime.now()
    
    # Check cache
    if cache_key in _contract_price_cache:
        cache_time = _cache_timestamps.get(cache_key)
        if cache_time and (now - cache_time).total_seconds() < CACHE_TTL_SECONDS:
            logger.debug(f"Cache hit for {cache_key}")
            return _contract_price_cache[cache_key]
    
    # Cache miss - fetch from database
    result = get_contract_price(ncr_bid_no, item_no, quantity, loc_id)
    
    # Store in cache
    if result:
        _contract_price_cache[cache_key] = result
        _cache_timestamps[cache_key] = now
        logger.debug(f"Cached contract price for {cache_key}")
    
    return result


def clear_contract_price_cache():
    """Clear the contract price cache."""
    global _contract_price_cache, _cache_timestamps
    _contract_price_cache.clear()
    _cache_timestamps.clear()
    logger.info("Contract price cache cleared")


if __name__ == '__main__':
    # Test the function
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python woo_contract_pricing.py <NCR_BID_NO> <ITEM_NO> [QUANTITY]")
        sys.exit(1)
    
    ncr_bid = sys.argv[1]
    item_no = sys.argv[2]
    quantity = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    
    result = get_contract_price(ncr_bid, item_no, quantity)
    
    if result:
        print(f"Contract Price: ${result['contract_price']:.2f}")
        print(f"Regular Price: ${result['regular_price']:.2f}")
        if result['discount_pct']:
            print(f"Discount: {result['discount_pct']:.2f}%")
        print(f"Pricing Method: {result['pricing_method']}")
        print(f"Rule: {result['rule_descr']}")
        print(f"Quantity Break: {result['applied_qty_break']}")
    else:
        print("No contract price found")


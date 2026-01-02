"""
contract_pricing_api_enhanced.py - Production-ready REST API for contract pricing

SECURITY FEATURES:
- API key authentication
- Rate limiting
- Request logging
- Health check with DB connectivity

PERFORMANCE:
- Batch pricing endpoint
- Response caching
- Request metrics

Usage:
    # Development
    python contract_pricing_api_enhanced.py
    
    # Production (with gunicorn)
    gunicorn -w 4 -b 0.0.0.0:5000 contract_pricing_api_enhanced:app
"""

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from functools import wraps
import logging
import time
import hashlib
import hmac
import os
import sys
from datetime import datetime
from typing import List, Dict, Optional
from collections import defaultdict

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from woo_contract_pricing import get_contract_price_cached, get_contract_price
from database import get_connection, connection_ctx

app = Flask(__name__)

# CORS - Only allow from WordPress server (configure in production)
ALLOWED_ORIGINS = os.getenv('ALLOWED_ORIGINS', 'http://localhost').split(',')
CORS(app, origins=ALLOWED_ORIGINS)

# Security
API_KEY = os.getenv('CONTRACT_PRICING_API_KEY', 'change-me-in-production')
REQUIRE_API_KEY = os.getenv('REQUIRE_API_KEY', 'true').lower() == 'true'

# Rate limiting
RATE_LIMIT_REQUESTS = int(os.getenv('RATE_LIMIT_REQUESTS', '100'))  # per window
RATE_LIMIT_WINDOW = int(os.getenv('RATE_LIMIT_WINDOW', '60'))  # seconds
_rate_limit_store = defaultdict(list)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Request metrics
_request_metrics = {
    'total_requests': 0,
    'cache_hits': 0,
    'cache_misses': 0,
    'errors': 0,
    'response_times': []
}


def verify_api_key(f):
    """Decorator to verify API key in request header."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not REQUIRE_API_KEY:
            return f(*args, **kwargs)
        
        api_key = request.headers.get('X-API-Key') or request.headers.get('Authorization', '').replace('Bearer ', '')
        
        if not api_key or api_key != API_KEY:
            logger.warning(f"Unauthorized API access attempt from {request.remote_addr}")
            return jsonify({'error': 'Unauthorized'}), 401
        
        return f(*args, **kwargs)
    return decorated_function


def rate_limit(f):
    """Simple rate limiting decorator."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_ip = request.remote_addr
        now = time.time()
        
        # Clean old entries
        _rate_limit_store[client_ip] = [
            t for t in _rate_limit_store[client_ip] 
            if now - t < RATE_LIMIT_WINDOW
        ]
        
        # Check limit
        if len(_rate_limit_store[client_ip]) >= RATE_LIMIT_REQUESTS:
            logger.warning(f"Rate limit exceeded for {client_ip}")
            return jsonify({'error': 'Rate limit exceeded'}), 429
        
        # Record request
        _rate_limit_store[client_ip].append(now)
        
        return f(*args, **kwargs)
    return decorated_function


def log_request(f):
    """Log request details for observability."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        start_time = time.time()
        g.start_time = start_time
        
        try:
            result = f(*args, **kwargs)
            response_time = (time.time() - start_time) * 1000  # ms
            
            # Log request
            logger.info(
                f"Request: {request.method} {request.path} | "
                f"IP: {request.remote_addr} | "
                f"Response: {result[1] if isinstance(result, tuple) else 200} | "
                f"Time: {response_time:.2f}ms"
            )
            
            # Update metrics
            _request_metrics['total_requests'] += 1
            _request_metrics['response_times'].append(response_time)
            if len(_request_metrics['response_times']) > 1000:
                _request_metrics['response_times'] = _request_metrics['response_times'][-1000:]
            
            return result
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            _request_metrics['errors'] += 1
            logger.error(f"Request error: {e} | Time: {response_time:.2f}ms", exc_info=True)
            raise
    
    return decorated_function


@app.route('/api/contract-price', methods=['POST'])
@verify_api_key
@rate_limit
@log_request
def get_contract_price_endpoint():
    """
    Get contract price for a single product.
    
    Request body:
    {
        "ncr_bid_no": "144319",
        "item_no": "01-10100",
        "quantity": 10,
        "loc_id": "01"  # optional
    }
    
    Headers:
        X-API-Key: <api_key>  (required if REQUIRE_API_KEY=true)
    
    Response:
    {
        "contract_price": 25.50,
        "regular_price": 50.00,
        "discount_pct": 49.0,
        "pricing_method": "D",
        "rule_descr": "SUPERIOR PC S CS",
        "applied_qty_break": 10.0,
        "requested_quantity": 10.0
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        ncr_bid_no = data.get('ncr_bid_no')
        item_no = data.get('item_no')
        quantity = float(data.get('quantity', 1.0))
        loc_id = data.get('loc_id', '*')  # Default to '*' (wildcard/default location)
        
        if not ncr_bid_no or not item_no:
            return jsonify({'error': 'Missing required parameters: ncr_bid_no, item_no'}), 400
        
        # Get contract price (with caching)
        result = get_contract_price_cached(ncr_bid_no, item_no, quantity, loc_id)
        
        if result:
            # Track cache hit/miss
            cache_key = f"{ncr_bid_no}:{item_no}:{quantity}:{loc_id}"
            # Note: Cache hit/miss tracking would need to be added to get_contract_price_cached
            return jsonify(result), 200
        else:
            return jsonify({'error': 'No contract price found'}), 404
            
    except Exception as e:
        logger.error(f"Error in contract price endpoint: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@app.route('/api/contract-prices', methods=['POST'])
@verify_api_key
@rate_limit
@log_request
def get_contract_prices_batch():
    """
    Get contract prices for multiple products (batch endpoint).
    
    Request body:
    {
        "ncr_bid_no": "144319",
        "items": [
            {"item_no": "01-10100", "quantity": 10},
            {"item_no": "01-10101", "quantity": 5},
            {"item_no": "01-10102", "quantity": 20}
        ],
        "loc_id": "01"  # optional
    }
    
    Response:
    {
        "results": [
            {
                "item_no": "01-10100",
                "quantity": 10,
                "contract_price": 25.50,
                "regular_price": 50.00,
                ...
            },
            ...
        ],
        "errors": [
            {"item_no": "01-99999", "error": "No contract price found"}
        ]
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        ncr_bid_no = data.get('ncr_bid_no')
        items = data.get('items', [])
        loc_id = data.get('loc_id', '*')  # Default to '*' (wildcard/default location)
        
        if not ncr_bid_no:
            return jsonify({'error': 'Missing required parameter: ncr_bid_no'}), 400
        
        if not items or not isinstance(items, list):
            return jsonify({'error': 'Missing or invalid items array'}), 400
        
        results = []
        errors = []
        
        for item in items:
            item_no = item.get('item_no')
            quantity = float(item.get('quantity', 1.0))
            
            if not item_no:
                errors.append({'item_no': item_no or 'unknown', 'error': 'Missing item_no'})
                continue
            
            try:
                result = get_contract_price_cached(ncr_bid_no, item_no, quantity, loc_id)
                if result:
                    result['item_no'] = item_no
                    result['quantity'] = quantity
                    results.append(result)
                else:
                    errors.append({'item_no': item_no, 'error': 'No contract price found'})
            except Exception as e:
                logger.error(f"Error processing item {item_no}: {e}")
                errors.append({'item_no': item_no, 'error': str(e)})
        
        return jsonify({
            'results': results,
            'errors': errors,
            'total_requested': len(items),
            'total_found': len(results),
            'total_errors': len(errors)
        }), 200
        
    except Exception as e:
        logger.error(f"Error in batch contract prices endpoint: {e}", exc_info=True)
        return jsonify({'error': str(e)}), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """
    Health check endpoint with database connectivity test.
    
    Response:
    {
        "status": "ok" | "degraded",
        "database": "connected" | "disconnected",
        "query_latency_ms": 12.5,
        "uptime_seconds": 3600
    }
    """
    health = {
        'status': 'ok',
        'database': 'disconnected',
        'query_latency_ms': None,
        'timestamp': datetime.now().isoformat()
    }
    
    try:
        start = time.time()
        with connection_ctx() as conn:
            cur = conn.cursor()
            cur.execute("SELECT 1")
            cur.fetchone()
        
        latency = (time.time() - start) * 1000
        health['database'] = 'connected'
        health['query_latency_ms'] = round(latency, 2)
        
        if latency > 1000:  # > 1 second is degraded
            health['status'] = 'degraded'
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        health['status'] = 'degraded'
        health['error'] = str(e)
    
    status_code = 200 if health['status'] == 'ok' else 503
    return jsonify(health), status_code


@app.route('/api/metrics', methods=['GET'])
@verify_api_key
def get_metrics():
    """
    Get request metrics (for monitoring).
    
    Response:
    {
        "total_requests": 1000,
        "cache_hits": 750,
        "cache_misses": 250,
        "errors": 5,
        "avg_response_time_ms": 45.2,
        "p95_response_time_ms": 120.5
    }
    """
    response_times = _request_metrics['response_times']
    
    metrics = {
        'total_requests': _request_metrics['total_requests'],
        'cache_hits': _request_metrics['cache_hits'],
        'cache_misses': _request_metrics['cache_misses'],
        'errors': _request_metrics['errors'],
        'avg_response_time_ms': round(sum(response_times) / len(response_times), 2) if response_times else 0,
        'p95_response_time_ms': round(sorted(response_times)[int(len(response_times) * 0.95)], 2) if response_times else 0
    }
    
    return jsonify(metrics), 200


if __name__ == '__main__':
    # Development mode
    logger.info("Starting contract pricing API (development mode)")
    logger.warning("For production, use: gunicorn -w 4 -b 0.0.0.0:5000 contract_pricing_api_enhanced:app")
    app.run(host='0.0.0.0', port=5000, debug=True)
else:
    # Production mode (gunicorn)
    logger.info("Contract pricing API loaded (production mode)")


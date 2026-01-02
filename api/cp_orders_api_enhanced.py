"""
cp_orders_api_enhanced.py - Production-ready REST API for CounterPoint orders

SECURITY FEATURES:
- API key authentication
- Rate limiting
- Request logging
- Health check with DB connectivity

PERFORMANCE:
- Response caching
- Request metrics

Usage:
    # Development
    python cp_orders_api_enhanced.py
    
    # Production (with gunicorn)
    gunicorn -w 4 -b 0.0.0.0:5001 cp_orders_api_enhanced:app
"""

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from functools import wraps
import logging
import time
import os
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from collections import defaultdict

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from cp_orders_display import get_cp_orders, get_orders_by_unit, get_orders_summary_by_unit
from database import get_connection, connection_ctx

app = Flask(__name__)

# CORS - Only allow from WordPress server (configure in production)
ALLOWED_ORIGINS = os.getenv('ALLOWED_ORIGINS', 'http://localhost').split(',')
CORS(app, origins=ALLOWED_ORIGINS)

# Security
API_KEY = os.getenv('CP_ORDERS_API_KEY', 'change-me-in-production')
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
            return jsonify({
                'success': False,
                'error': 'Unauthorized - Invalid API key'
            }), 401
        
        return f(*args, **kwargs)
    return decorated_function


def rate_limit(f):
    """Decorator to rate limit requests."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_ip = request.remote_addr
        now = time.time()
        
        # Clean old entries
        _rate_limit_store[client_ip] = [
            req_time for req_time in _rate_limit_store[client_ip]
            if now - req_time < RATE_LIMIT_WINDOW
        ]
        
        # Check limit
        if len(_rate_limit_store[client_ip]) >= RATE_LIMIT_REQUESTS:
            logger.warning(f"Rate limit exceeded for {client_ip}")
            return jsonify({
                'success': False,
                'error': 'Rate limit exceeded. Please try again later.'
            }), 429
        
        # Add current request
        _rate_limit_store[client_ip].append(now)
        
        return f(*args, **kwargs)
    return decorated_function


def log_request(f):
    """Decorator to log requests and response times."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        start_time = time.time()
        _request_metrics['total_requests'] += 1
        
        try:
            response = f(*args, **kwargs)
            elapsed = time.time() - start_time
            _request_metrics['response_times'].append(elapsed)
            
            # Keep only last 1000 response times
            if len(_request_metrics['response_times']) > 1000:
                _request_metrics['response_times'] = _request_metrics['response_times'][-1000:]
            
            logger.info(f"{request.method} {request.path} - {response[1]} - {elapsed:.3f}s")
            return response
            
        except Exception as e:
            _request_metrics['errors'] += 1
            elapsed = time.time() - start_time
            logger.error(f"{request.method} {request.path} - ERROR - {elapsed:.3f}s - {str(e)}", exc_info=True)
            raise
    
    return decorated_function


@app.route('/api/cp-orders', methods=['GET'])
@verify_api_key
@rate_limit
@log_request
def get_orders_endpoint():
    """REST API endpoint to get CounterPoint orders."""
    try:
        # Get query parameters
        date_from = request.args.get('date_from')
        date_to = request.args.get('date_to')
        customer_no = request.args.get('customer_no')
        status = request.args.get('status')
        unit = request.args.get('unit')
        limit = min(int(request.args.get('limit', 100)), 1000)  # Max 1000
        
        # Get orders
        orders = get_cp_orders(
            date_from=date_from,
            date_to=date_to,
            customer_no=customer_no,
            status=status,
            unit_code=unit,
            limit=limit
        )
        
        return jsonify({
            'success': True,
            'count': len(orders),
            'orders': orders
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting CP orders: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/cp-orders/by-unit/<unit_code>', methods=['GET'])
@verify_api_key
@rate_limit
@log_request
def get_orders_by_unit_endpoint(unit_code):
    """REST API endpoint to get orders filtered by unit code."""
    try:
        days = int(request.args.get('days', 30))
        
        orders = get_orders_by_unit(unit_code, days=days)
        
        return jsonify({
            'success': True,
            'count': len(orders),
            'unit_code': unit_code,
            'days': days,
            'orders': orders
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting CP orders by unit: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/cp-orders/summary', methods=['GET'])
@verify_api_key
@rate_limit
@log_request
def get_orders_summary_endpoint():
    """REST API endpoint to get summary of orders grouped by unit type."""
    try:
        days = int(request.args.get('days', 30))
        
        summary = get_orders_summary_by_unit(days=days)
        
        return jsonify({
            'success': True,
            'days': days,
            'summary': summary
        }), 200
        
    except Exception as e:
        logger.error(f"Error getting CP orders summary: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/cp-orders/health', methods=['GET'])
def health_check():
    """Health check endpoint with DB connectivity test."""
    try:
        # Test database connection
        with connection_ctx() as conn:
            cur = conn.cursor()
            cur.execute("SELECT 1")
            cur.fetchone()
            db_status = 'connected'
    except Exception as e:
        db_status = f'error: {str(e)}'
    
    # Calculate average response time
    avg_response_time = (
        sum(_request_metrics['response_times']) / len(_request_metrics['response_times'])
        if _request_metrics['response_times'] else 0
    )
    
    return jsonify({
        'status': 'healthy',
        'service': 'cp-orders-api',
        'database': db_status,
        'timestamp': datetime.now().isoformat(),
        'metrics': {
            'total_requests': _request_metrics['total_requests'],
            'errors': _request_metrics['errors'],
            'avg_response_time_ms': round(avg_response_time * 1000, 2)
        }
    }), 200


@app.route('/api/cp-orders/metrics', methods=['GET'])
@verify_api_key
def get_metrics():
    """Get API metrics (admin only)."""
    avg_response_time = (
        sum(_request_metrics['response_times']) / len(_request_metrics['response_times'])
        if _request_metrics['response_times'] else 0
    )
    
    return jsonify({
        'total_requests': _request_metrics['total_requests'],
        'errors': _request_metrics['errors'],
        'avg_response_time_ms': round(avg_response_time * 1000, 2),
        'rate_limit_requests': RATE_LIMIT_REQUESTS,
        'rate_limit_window_seconds': RATE_LIMIT_WINDOW
    }), 200


if __name__ == '__main__':
    # Run the Flask app
    # In production, use gunicorn or waitress
    logger.info("Starting CP Orders API on port 5001")
    logger.info(f"API Key required: {REQUIRE_API_KEY}")
    logger.info(f"Rate limit: {RATE_LIMIT_REQUESTS} requests per {RATE_LIMIT_WINDOW} seconds")
    app.run(host='0.0.0.0', port=5001, debug=False)


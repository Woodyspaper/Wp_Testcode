#!/usr/bin/env python3
"""
API Health Test Script
Purpose: Test if the contract pricing API is running and healthy
"""

import requests
import sys
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
API_BASE_URL = os.getenv('API_BASE_URL', 'http://localhost:5000')
API_KEY = os.getenv('CONTRACT_PRICING_API_KEY', '')

def test_health_endpoint():
    """Test the health endpoint"""
    print("Testing health endpoint...")
    try:
        url = f"{API_BASE_URL}/api/health"
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Health check passed: {data}")
            
            # Check database connection
            if data.get('database') == 'connected':
                print("✅ Database connection: OK")
                return True
            else:
                print(f"⚠️  Database connection: {data.get('database')}")
                return False
        else:
            print(f"❌ Health check failed: HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
    except requests.exceptions.ConnectionError:
        print(f"❌ Cannot connect to API at {API_BASE_URL}")
        print("   Is the API running?")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_pricing_endpoint():
    """Test the pricing endpoint with API key"""
    print("\nTesting pricing endpoint...")
    
    if not API_KEY:
        print("⚠️  No API key configured. Skipping pricing endpoint test.")
        print("   Set CONTRACT_PRICING_API_KEY in .env file")
        return False
    
    try:
        url = f"{API_BASE_URL}/api/contract-price"
        headers = {
            'Content-Type': 'application/json',
            'X-API-Key': API_KEY
        }
        data = {
            'ncr_bid_no': '144319',
            'item_no': '01-10100',
            'quantity': 10.0
        }
        
        response = requests.post(url, json=data, headers=headers, timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Pricing endpoint test passed")
            print(f"   Response: {result}")
            return True
        elif response.status_code == 401:
            print("❌ Authentication failed - check API key")
            return False
        elif response.status_code == 404:
            print("⚠️  No contract price found (this may be expected)")
            print(f"   Response: {response.json()}")
            return True  # Not an error, just no contract
        else:
            print(f"❌ Pricing endpoint failed: HTTP {response.status_code}")
            print(f"   Response: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("=" * 50)
    print("Contract Pricing API Health Test")
    print("=" * 50)
    print(f"API URL: {API_BASE_URL}")
    print(f"API Key: {'***' if API_KEY else 'NOT SET'}")
    print("=" * 50)
    print()
    
    # Test health endpoint
    health_ok = test_health_endpoint()
    
    # Test pricing endpoint if health is OK
    pricing_ok = False
    if health_ok:
        pricing_ok = test_pricing_endpoint()
    else:
        print("\n⚠️  Skipping pricing endpoint test (health check failed)")
    
    # Summary
    print("\n" + "=" * 50)
    print("Test Summary")
    print("=" * 50)
    print(f"Health Endpoint: {'✅ PASS' if health_ok else '❌ FAIL'}")
    print(f"Pricing Endpoint: {'✅ PASS' if pricing_ok else '❌ FAIL/SKIP'}")
    print("=" * 50)
    
    if health_ok and pricing_ok:
        print("\n✅ All tests passed! API is ready.")
        return 0
    elif health_ok:
        print("\n⚠️  Health check passed, but pricing test had issues.")
        print("   This may be normal if no contract exists for test data.")
        return 0
    else:
        print("\n❌ API health check failed. Please check:")
        print("   1. Is the API running?")
        print("   2. Is the API URL correct?")
        print("   3. Can you reach the API server?")
        return 1

if __name__ == '__main__':
    sys.exit(main())

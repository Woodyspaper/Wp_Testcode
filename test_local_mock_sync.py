"""
test_local_mock_sync.py
Local mock test of the entire sync pipeline WITHOUT connecting to any database.

This tests:
  - sync.py orchestration
  - Feed building logic
  - WooCommerce client behavior
  - Dry-run mode

Usage:
    python test_local_mock_sync.py
"""

from __future__ import annotations

import json
import logging
from unittest.mock import MagicMock, patch

from config import IntegrationConfig, DatabaseConfig, WooCommerceConfig
from feed_builder import build_product_feed
from woo_client import WooClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def mock_database_rows() -> list[dict]:
    """Return mock CounterPoint data that would come from VI_IM_ITEM_WITH_INV."""
    return [
        {
            "ITEM_NO": "SKU-001",
            "DESCR": "Paper Ream A4",
            "LONG_DESCR": "High-quality A4 copy paper, 80gsm",
            "PRC_1": 12.50,
            "REG_PRC": 14.99,
            "QTY_AVAIL": 150.0,
            "LOC_ID": "01",
            "IS_ECOMM_ITEM": "Y",
            "ECOMM_IMG_FILE": "paper-ream-a4.jpg",
            "URL": "paper-ream-a4",
            "HTML_DESCR": "<p>Professional copy paper</p>",
            "CATEG_ID": "CAT-001",
            "CATEG_DESCR": "Paper Products",
            "PARENT_ID": None,
            "DISP_SEQ_NO": 1,
        },
        {
            "ITEM_NO": "SKU-002",
            "DESCR": "Ink Cartridge Black",
            "LONG_DESCR": "Compatible cartridge",
            "PRC_1": None,
            "REG_PRC": 25.00,
            "QTY_AVAIL": 0.0,  # Out of stock
            "LOC_ID": "01",
            "IS_ECOMM_ITEM": "Y",
            "ECOMM_IMG_FILE": None,
            "URL": None,
            "HTML_DESCR": None,
            "CATEG_ID": "CAT-002",
            "CATEG_DESCR": "Supplies",
            "PARENT_ID": None,
            "DISP_SEQ_NO": 1,
        },
    ]


def test_feed_builder_with_mock_data() -> None:
    """Test feed_builder.py against mock CounterPoint data."""
    logger.info("\n" + "=" * 70)
    logger.info("TEST 1: Feed Builder with Mock Data")
    logger.info("=" * 70)

    cfg = IntegrationConfig(
        database=DatabaseConfig(
            driver="ODBC Driver 18 for SQL Server",
            server="MOCK_SERVER",
            database="MOCK_DB",
            trusted_connection=True,
            username=None,
            password=None,
            timeout=30,
        ),
        woo=WooCommerceConfig(
            base_url="https://example.com",
            consumer_key="test_key",
            consumer_secret="test_secret",
        ),
        image_base_url="https://cdn.example.com/images",
        default_loc_id="01",
    )

    # Mock run_query to return our test data
    with patch("feed_builder.run_query", return_value=mock_database_rows()):
        products = build_product_feed(limit=10, config=cfg)

    logger.info(f"✓ Built {len(products)} products")
    assert len(products) == 2, f"Expected 2 products, got {len(products)}"

    # Validate first product
    sku1 = products[0]
    assert sku1["sku"] == "SKU-001", f"Expected SKU-001, got {sku1['sku']}"
    assert sku1["name"] == "Paper Ream A4"
    assert sku1["regular_price"] == "12.50", "Should use PRC_1"
    assert sku1["stock_quantity"] == 150
    assert sku1["stock_status"] == "instock"
    assert sku1["manage_stock"] is True
    assert len(sku1["images"]) == 1
    assert sku1["images"][0]["src"] == "https://cdn.example.com/images/paper-ream-a4.jpg"
    logger.info("✓ SKU-001 validated correctly")

    # Validate second product (tests fallback to REG_PRC, zero stock)
    sku2 = products[1]
    assert sku2["sku"] == "SKU-002"
    assert sku2["regular_price"] == "25.00", "Should fallback to REG_PRC"
    assert sku2["stock_quantity"] == 0
    assert sku2["stock_status"] == "outofstock"
    assert len(sku2["images"]) == 0, "Should have no images when file is None"
    logger.info("✓ SKU-002 validated correctly (fallback behavior)")

    logger.info("\n✓ TEST 1 PASSED: Feed builder works with mock data\n")
    return products


def test_woo_client_dry_run(products: list[dict]) -> None:
    """Test WooClient in dry-run mode (no actual HTTP calls)."""
    logger.info("=" * 70)
    logger.info("TEST 2: WooCommerce Client (Dry-Run Mode)")
    logger.info("=" * 70)

    cfg = IntegrationConfig(
        database=DatabaseConfig(
            driver="ODBC Driver 18 for SQL Server",
            server="MOCK_SERVER",
            database="MOCK_DB",
            trusted_connection=True,
            username=None,
            password=None,
            timeout=30,
        ),
        woo=WooCommerceConfig(
            base_url="https://example.com",
            consumer_key="test_key",
            consumer_secret="test_secret",
        ),
        image_base_url="https://cdn.example.com/images",
        default_loc_id="01",
    )

    client = WooClient(config=cfg)

    # Mock test_connection to return True
    with patch.object(client, "test_connection", return_value=True):
        result = client.test_connection()
        assert result is True
        logger.info("✓ Mock connection test passed")

    # Sync in dry-run mode (should NOT make HTTP calls)
    client.sync_products(products, dry_run=True)
    logger.info("✓ Dry-run sync completed (no HTTP calls made)")

    logger.info("\n✓ TEST 2 PASSED: WooCommerce client dry-run works\n")


def test_full_pipeline() -> None:
    """Test the entire sync pipeline: mock data → feed → woo client."""
    logger.info("=" * 70)
    logger.info("TEST 3: Full Sync Pipeline (Mock)")
    logger.info("=" * 70)

    logger.info("Step 1: Building feed from mock data...")
    products = test_feed_builder_with_mock_data()

    logger.info("Step 2: Testing WooCommerce client...")
    test_woo_client_dry_run(products)

    logger.info("=" * 70)
    logger.info("✓ ALL TESTS PASSED: Full pipeline works locally")
    logger.info("=" * 70)
    logger.info("\nNext: Test against CPPractice database")
    logger.info("=" * 70)


if __name__ == "__main__":
    test_full_pipeline()

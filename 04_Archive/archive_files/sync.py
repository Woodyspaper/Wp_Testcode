"""
sync.py
Unified CLI entrypoint for the CounterPoint → WooCommerce sync pipeline.

Flow:
  1. Validate environment (.env file and required variables)
  2. Load product feed from CounterPoint
  3. Sync products to WooCommerce (dry-run by default)

Usage:
    python sync.py                           # Full sync (dry-run mode)
    python sync.py --live                    # Live sync (writes to WooCommerce)
    python sync.py --limit 10                # Sync only first 10 products
    python sync.py --live --limit 5          # Live sync, 5 products only
    python sync.py --products-only            # Sync products only (no inventory)
    python sync.py --inventory-only           # Sync inventory only (no product updates)
    python sync.py --full-sync                # Full sync (products + inventory)
"""

from __future__ import annotations

import argparse
import logging
import os
import sys
from typing import Optional

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from config import load_integration_config
from archive_files.feed_builder import build_product_feed
# from validate_env import validate  # TODO: Create validate_env.py if needed
from woo_client import WooClient

logger = logging.getLogger(__name__)


def setup_logging(level: str = "INFO") -> None:
    """Configure root logger with simple format."""
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def _confirm_live_operation() -> bool:
    """Safety prompt before live operations."""
    print("\n" + "=" * 70)
    print("⚠️  WARNING: LIVE MODE ENABLED")
    print("=" * 70)
    print("This will write data to your WooCommerce store.")
    print("Make sure you have:")
    print("  ✓ Tested in dry-run mode first")
    print("  ✓ Backed up your WooCommerce database")
    print("  ✓ Verified your product feed is correct")
    print("=" * 70)
    response = input("\nType 'YES' to continue with live sync: ")
    return response.strip().upper() == "YES"


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Sync CounterPoint product feed to WooCommerce.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--live",
        action="store_true",
        help="Execute live sync (writes to WooCommerce). Default is dry-run.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max number of products to fetch (default: no limit).",
    )
    parser.add_argument(
        "--products-only",
        action="store_true",
        help="Sync products only (skip inventory updates).",
    )
    parser.add_argument(
        "--inventory-only",
        action="store_true",
        help="Sync inventory only (skip product updates).",
    )
    parser.add_argument(
        "--full-sync",
        action="store_true",
        help="Full sync (products + inventory). This is the default behavior.",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging verbosity (default: INFO).",
    )
    parser.add_argument(
        "--skip-prompt",
        action="store_true",
        help="Skip safety confirmation prompt (use with caution).",
    )

    args = parser.parse_args()
    setup_logging(args.log_level)

    # Determine sync mode
    sync_products = not args.inventory_only
    sync_inventory = not args.products_only
    if args.full_sync:
        sync_products = True
        sync_inventory = True

    # Check DRY_RUN environment variable
    env_dry_run = os.getenv("DRY_RUN", "true").lower() in {"true", "1", "yes"}
    is_live = args.live and not env_dry_run

    # Safety prompt for live operations
    if is_live and not args.skip_prompt:
        if not _confirm_live_operation():
            logger.warning("Live sync cancelled by user.")
            return 0

    logger.info("=" * 70)
    logger.info("CounterPoint → WooCommerce Sync")
    logger.info("=" * 70)
    logger.info("Mode: %s", "LIVE" if is_live else "DRY-RUN")
    logger.info("Products: %s | Inventory: %s", sync_products, sync_inventory)

    # Step 1: Validate environment
    logger.info("\n[Step 1/3] Validating environment...")
    try:
        # Load config (validates environment variables)
        cfg = load_integration_config()
        logger.info("✓ Environment validated")
        # TODO: Add validate_env.py for more comprehensive validation
        # validate()
    except Exception as exc:
        logger.error("Environment validation failed: %s", exc)
        return 1

    # Step 2: Build product feed from CounterPoint
    logger.info("\n[Step 2/3] Building product feed from CounterPoint...")
    try:
        # cfg already loaded in Step 1
        products = build_product_feed(limit=args.limit, config=cfg)
        logger.info("✓ Loaded %d products from CounterPoint", len(products))
        if not products:
            logger.warning("No products found. Check your location ID and e-comm settings.")
            return 0
    except Exception as exc:
        logger.error("Failed to build product feed: %s", exc, exc_info=True)
        return 1

    # Step 3: Sync to WooCommerce
    logger.info("\n[Step 3/3] Syncing to WooCommerce (%s mode)...", "LIVE" if args.live else "DRY-RUN")
    try:
        client = WooClient(config=cfg)

        # Verify connection
        logger.info("Testing WooCommerce connection...")
        if not client.test_connection():
            logger.error("WooCommerce connection test failed. Check credentials.")
            return 1

        # Perform sync based on mode
        if sync_products:
            logger.info("Syncing products...")
            client.sync_products(products, dry_run=not is_live)
            logger.info("✓ Products %s", "synced" if is_live else "preview generated")

        if sync_inventory:
            logger.info("Syncing inventory...")
            client.sync_inventory(products, dry_run=not is_live)
            logger.info("✓ Inventory %s", "synced" if is_live else "preview generated")

    except Exception as exc:
        logger.error("Sync failed: %s", exc, exc_info=True)
        return 1

    logger.info("\n" + "=" * 70)
    logger.info("✓ All steps completed successfully")
    logger.info("=" * 70)
    return 0


if __name__ == "__main__":
    sys.exit(main())

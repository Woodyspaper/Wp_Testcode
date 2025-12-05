"""
WooCommerce REST API helper focused on safe, testable interactions.

Supports:
    - test_connection(): GET small sample to verify credentials.
    - sync_products(): Batch create/update products.
    - sync_inventory(): Batch update inventory/stock quantities.
    - Full error handling and logging.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Dict, List, Optional, Tuple

import requests

from config import IntegrationConfig, load_integration_config

logger = logging.getLogger(__name__)


class WooClient:
    def __init__(self, config: Optional[IntegrationConfig] = None) -> None:
        self.config = config or load_integration_config()
        self.session = requests.Session()
        self.session.auth = (
            self.config.woo.consumer_key,
            self.config.woo.consumer_secret,
        )

    def _url(self, path: str) -> str:
        return f"{self.config.woo.base_url}/wp-json/wc/v3{path}"

    def test_connection(self) -> bool:
        """GET /products?per_page=1 to ensure credentials work."""

        url = self._url("/products")
        params = {"per_page": 1}
        logger.info("Testing WooCommerce connection at %s", url)
        response = self.session.get(url, params=params, timeout=30)
        if response.ok:
            data = response.json()
            logger.info("WooCommerce connection OK; sample=%s", data[:1])
            return True

        logger.error(
            "WooCommerce connection failed: %s %s %s",
            response.status_code,
            response.reason,
            response.text[:500],
        )
        return False

    def _get_existing_products(self, skus: List[str]) -> Dict[str, int]:
        """
        Fetch existing product IDs by SKU.

        Note: WooCommerce API doesn't support filtering by multiple SKUs directly.
        We fetch products in batches and match by SKU client-side.

        Returns:
            Dictionary mapping SKU to WooCommerce product ID.
        """
        if not skus:
            return {}

        existing = {}
        sku_set = set(skus)
        page = 1
        per_page = 100
        max_pages = 50  # Safety limit

        logger.debug("Fetching existing products for %d SKUs", len(skus))

        while page <= max_pages:
            url = self._url("/products")
            params = {"per_page": per_page, "page": page}
            response = self.session.get(url, params=params, timeout=30)

            if not response.ok:
                logger.warning("Failed to fetch existing products: %s", response.status_code)
                break

            data = response.json()
            if not data:
                break

            for product in data:
                sku = product.get("sku")
                if sku and sku in sku_set and "id" in product:
                    existing[sku] = product["id"]
                    if len(existing) >= len(skus):
                        # Found all SKUs, can stop early
                        logger.debug("Found all %d SKUs, stopping fetch", len(skus))
                        return existing

            if len(data) < per_page:
                break
            page += 1

        logger.debug("Found %d of %d requested SKUs", len(existing), len(skus))
        return existing

    def sync_products(
        self, products: List[Dict], dry_run: Optional[bool] = None
    ) -> Tuple[int, int, List[str]]:
        """
        Batch sync products to WooCommerce (create new or update existing).

        Args:
            products: List of WooCommerce product payload dictionaries.
            dry_run: When True, only log what would be sent. If None, checks DRY_RUN env var.

        Returns:
            Tuple of (created_count, updated_count, error_list)
        """
        if dry_run is None:
            dry_run = os.getenv("DRY_RUN", "true").lower() in {"true", "1", "yes"}

        if not products:
            logger.warning("No products to sync")
            return 0, 0, []

        # Separate create vs update
        skus = [p.get("sku") for p in products if p.get("sku")]
        existing = self._get_existing_products(skus) if not dry_run else {}

        to_create = []
        to_update = []

        for product in products:
            sku = product.get("sku")
            if not sku:
                logger.warning("Product missing SKU, skipping: %s", product.get("name", "Unknown"))
                continue

            if sku in existing:
                product["id"] = existing[sku]
                to_update.append(product)
            else:
                to_create.append(product)

        logger.info("Products to create: %d | Products to update: %d", len(to_create), len(to_update))

        if dry_run:
            logger.info("DRY-RUN: Would create %d and update %d products", len(to_create), len(to_update))
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug("Create payload preview: %s", json.dumps(to_create[:2], indent=2)[:1000])
                logger.debug("Update payload preview: %s", json.dumps(to_update[:2], indent=2)[:1000])
            return len(to_create), len(to_update), []

        # Batch operations
        created = 0
        updated = 0
        errors = []

        batch_size = int(os.getenv("SYNC_BATCH_SIZE", "50"))

        # Create new products
        if to_create:
            for i in range(0, len(to_create), batch_size):
                batch = to_create[i : i + batch_size]
                payload = {"create": batch}
                url = self._url("/products/batch")
                logger.info("Creating batch %d-%d of %d products", i + 1, min(i + batch_size, len(to_create)), len(to_create))

                try:
                    response = self.session.post(url, json=payload, timeout=120)
                    if response.ok:
                        result = response.json()
                        created += len(result.get("create", []))
                        logger.info("✓ Created %d products in this batch", len(result.get("create", [])))
                    else:
                        error_msg = f"Batch create failed: {response.status_code} {response.reason}"
                        logger.error(error_msg)
                        errors.append(error_msg)
                except Exception as exc:
                    error_msg = f"Exception during batch create: {exc}"
                    logger.exception(error_msg)
                    errors.append(error_msg)

        # Update existing products
        if to_update:
            for i in range(0, len(to_update), batch_size):
                batch = to_update[i : i + batch_size]
                payload = {"update": batch}
                url = self._url("/products/batch")
                logger.info("Updating batch %d-%d of %d products", i + 1, min(i + batch_size, len(to_update)), len(to_update))

                try:
                    response = self.session.post(url, json=payload, timeout=120)
                    if response.ok:
                        result = response.json()
                        updated += len(result.get("update", []))
                        logger.info("✓ Updated %d products in this batch", len(result.get("update", [])))
                    else:
                        error_msg = f"Batch update failed: {response.status_code} {response.reason}"
                        logger.error(error_msg)
                        errors.append(error_msg)
                except Exception as exc:
                    error_msg = f"Exception during batch update: {exc}"
                    logger.exception(error_msg)
                    errors.append(error_msg)

        logger.info("Sync complete: %d created, %d updated, %d errors", created, updated, len(errors))
        return created, updated, errors

    def sync_inventory(
        self, products: List[Dict], dry_run: Optional[bool] = None
    ) -> Tuple[int, List[str]]:
        """
        Batch update inventory/stock quantities for existing products.

        Args:
            products: List of product dictionaries with SKU and stock_quantity.
            dry_run: When True, only log what would be sent. If None, checks DRY_RUN env var.

        Returns:
            Tuple of (updated_count, error_list)
        """
        if dry_run is None:
            dry_run = os.getenv("DRY_RUN", "true").lower() in {"true", "1", "yes"}

        if not products:
            logger.warning("No products for inventory sync")
            return 0, []

        # Build inventory update payloads (only SKU + stock fields)
        inventory_updates = []
        for product in products:
            sku = product.get("sku")
            if not sku:
                continue

            update = {
                "sku": sku,
                "stock_quantity": product.get("stock_quantity", 0),
                "stock_status": product.get("stock_status", "outofstock"),
                "manage_stock": product.get("manage_stock", True),
            }
            inventory_updates.append(update)

        logger.info("Inventory updates to apply: %d", len(inventory_updates))

        if dry_run:
            logger.info("DRY-RUN: Would update inventory for %d products", len(inventory_updates))
            if logger.isEnabledFor(logging.DEBUG):
                logger.debug("Inventory payload preview: %s", json.dumps(inventory_updates[:3], indent=2)[:1000])
            return len(inventory_updates), []

        # Fetch existing product IDs
        skus = [p["sku"] for p in inventory_updates]
        existing = self._get_existing_products(skus)

        # Add IDs to updates
        for update in inventory_updates:
            sku = update["sku"]
            if sku in existing:
                update["id"] = existing[sku]
            else:
                logger.warning("SKU %s not found in WooCommerce, skipping inventory update", sku)

        # Filter to only products that exist
        valid_updates = [u for u in inventory_updates if "id" in u]
        logger.info("Valid inventory updates: %d", len(valid_updates))

        updated = 0
        errors = []
        batch_size = int(os.getenv("SYNC_BATCH_SIZE", "50"))

        for i in range(0, len(valid_updates), batch_size):
            batch = valid_updates[i : i + batch_size]
            payload = {"update": batch}
            url = self._url("/products/batch")
            logger.info("Updating inventory batch %d-%d of %d", i + 1, min(i + batch_size, len(valid_updates)), len(valid_updates))

            try:
                response = self.session.post(url, json=payload, timeout=120)
                if response.ok:
                    result = response.json()
                    updated += len(result.get("update", []))
                    logger.info("✓ Updated inventory for %d products in this batch", len(result.get("update", [])))
                else:
                    error_msg = f"Inventory batch update failed: {response.status_code} {response.reason}"
                    logger.error(error_msg)
                    errors.append(error_msg)
            except Exception as exc:
                error_msg = f"Exception during inventory update: {exc}"
                logger.exception(error_msg)
                errors.append(error_msg)

        logger.info("Inventory sync complete: %d updated, %d errors", updated, len(errors))
        return updated, errors


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    client = WooClient()
    client.test_connection()


if __name__ == "__main__":
    main()


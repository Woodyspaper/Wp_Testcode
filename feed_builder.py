"""
Product feed builder translating CounterPoint data to WooCommerce-ready payloads.

This module only reads from WOODYS_CP; CounterPoint remains the source of truth.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Sequence

from config import IntegrationConfig, load_integration_config
from database import run_query

logger = logging.getLogger(__name__)


FEED_SQL = """
SELECT {top_clause}
    v.ITEM_NO,
    v.DESCR,
    v.LONG_DESCR,
    v.PRC_1,
    v.REG_PRC,
    v.QTY_AVAIL,
    v.LOC_ID,
    v.IS_ECOMM_ITEM,
    v.ECOMM_IMG_FILE,
    v.URL,
    descr.HTML_DESCR,
    cat.CATEG_ID,
    cat.DESCR AS CATEG_DESCR,
    cat.PARENT_ID,
    cat.DISP_SEQ_NO
FROM VI_IM_ITEM_WITH_INV v
LEFT JOIN EC_ITEM_DESCR descr ON descr.ITEM_NO = v.ITEM_NO
LEFT JOIN EC_CATEG_ITEM ci ON ci.ITEM_NO = v.ITEM_NO
LEFT JOIN EC_CATEG cat ON cat.CATEG_ID = ci.CATEG_ID
WHERE v.LOC_ID = ?
  AND v.IS_ECOMM_ITEM = 'Y'
ORDER BY v.ITEM_NO, cat.DISP_SEQ_NO;
"""


@dataclass
class ProductFeedItem:
    sku: str
    name: str
    regular_price: str
    stock_quantity: int
    stock_status: str
    manage_stock: bool
    description: str
    short_description: Optional[str]
    categories: List[Dict[str, str]]
    images: List[Dict[str, str]]
    slug: Optional[str]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "sku": self.sku,
            "name": self.name,
            "regular_price": self.regular_price,
            "stock_quantity": self.stock_quantity,
            "stock_status": self.stock_status,
            "manage_stock": self.manage_stock,
            "description": self.description,
            "short_description": self.short_description,
            "categories": self.categories,
            "images": self.images,
            "slug": self.slug,
        }


def _build_feed_sql(limit: Optional[int]) -> str:
    top_clause = f"TOP {limit}" if limit else ""
    return FEED_SQL.format(top_clause=top_clause)


def _slugify(value: str) -> str:
    filtered = "".join(ch if ch.isalnum() else "-" for ch in value.lower())
    while "--" in filtered:
        filtered = filtered.replace("--", "-")
    return filtered.strip("-")


def _compute_price(prc_1: Optional[float], reg_prc: Optional[float]) -> str:
    price = prc_1 if prc_1 is not None else reg_prc
    if price is None:
        return "0.00"
    return f"{price:.2f}"


def _stock_status(qty_avail: Optional[float]) -> tuple[int, str]:
    qty = max(int(qty_avail or 0), 0)
    status = "instock" if qty > 0 else "outofstock"
    return qty, status


def _image_payload(image_base_url: Optional[str], filename: Optional[str], alt_text: str) -> List[Dict[str, str]]:
    if not filename or not image_base_url:
        return []
    src = f"{image_base_url}/{filename.lstrip('/')}"
    return [{"src": src, "alt": alt_text}]


def _group_categories(rows: Sequence[Dict[str, Any]]) -> List[Dict[str, str]]:
    categories = []
    seen = set()
    for row in rows:
        cat_slug = row.get("CATEG_DESCR")
        if not cat_slug or cat_slug in seen:
            continue
        categories.append({"slug": cat_slug})
        seen.add(cat_slug)
    return categories


def _description(row: Dict[str, Any]) -> str:
    html_descr = row.get("HTML_DESCR")
    if html_descr:
        return html_descr
    long_descr = row.get("LONG_DESCR")
    return long_descr or ""


def build_product_feed(limit: Optional[int] = 100, config: Optional[IntegrationConfig] = None) -> List[Dict[str, Any]]:
    """
    Fetch CounterPoint e-comm items and map them to WooCommerce payloads.

    Args:
        limit: Optional cap on number of products to pull.
        config: Optional preloaded IntegrationConfig.

    Returns:
        List of product dictionaries.
    """

    cfg = config or load_integration_config()
    sql = _build_feed_sql(limit)
    rows = run_query(sql, (cfg.default_loc_id,))

    feed: List[Dict[str, Any]] = []
    current_sku = None
    sku_rows: List[Dict[str, Any]] = []

    for row in rows:
        sku = row["ITEM_NO"]
        if current_sku and sku != current_sku:
            feed.append(_build_item_payload(sku_rows, cfg))
            sku_rows = []

        sku_rows.append(row)
        current_sku = sku

    if sku_rows:
        feed.append(_build_item_payload(sku_rows, cfg))

    logger.info("Built product feed with %d entries", len(feed))
    return feed


def _build_item_payload(rows: Sequence[Dict[str, Any]], cfg: IntegrationConfig) -> Dict[str, Any]:
    first = rows[0]
    sku = first["ITEM_NO"]
    name = first.get("DESCR", sku)

    price = _compute_price(first.get("PRC_1"), first.get("REG_PRC"))
    qty, stock_status = _stock_status(first.get("QTY_AVAIL"))

    description = _description(first)
    short_description = (first.get("LONG_DESCR") or "")[:255] or None

    categories = _group_categories(rows)
    images = _image_payload(cfg.image_base_url, first.get("ECOMM_IMG_FILE"), name)
    slug_source = first.get("URL") or name
    slug = _slugify(slug_source) if slug_source else None

    item = ProductFeedItem(
        sku=sku,
        name=name,
        regular_price=price,
        stock_quantity=qty,
        stock_status=stock_status,
        manage_stock=True,
        description=description,
        short_description=short_description,
        categories=categories,
        images=images,
        slug=slug,
    )
    payload = item.to_dict()
    logger.debug("Built payload for SKU %s: %s", sku, payload)
    return payload


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    sample_feed = build_product_feed(limit=5)
    for item in sample_feed:
        print(item)



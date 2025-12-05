import pytest

from config import IntegrationConfig, DatabaseConfig, WooCommerceConfig
from feed_builder import _build_item_payload


@pytest.fixture
def integration_config():
    return IntegrationConfig(
        database=DatabaseConfig(
            driver="ODBC Driver 18 for SQL Server",
            server="server",
            database="db",
            trusted_connection=True,
            username=None,
            password=None,
            timeout=30,
        ),
        woo=WooCommerceConfig(
            base_url="https://example.com",
            consumer_key="ck",
            consumer_secret="cs",
        ),
        image_base_url="https://cdn.example.com/img",
        default_loc_id="01",
    )


def build_rows(base: dict, categories=None):
    base_row = {
        "ITEM_NO": "01-10100",
        "DESCR": "NCR Carbonless",
        "LONG_DESCR": "Default long description.",
        "PRC_1": 12.34,
        "REG_PRC": 14.56,
        "QTY_AVAIL": 5,
        "LOC_ID": "01",
        "IS_ECOMM_ITEM": "Y",
        "ECOMM_IMG_FILE": "ncr-5887.jpg",
        "URL": "ncr-carbonless",
        "HTML_DESCR": None,
    }
    base_row.update(base)
    rows = [base_row]
    if categories:
        rows = []
        for cat in categories:
            row = base_row.copy()
            row.update(cat)
            rows.append(row)
    return rows


def test_price_falls_back_to_reg_prc(integration_config):
    rows = build_rows({"PRC_1": None, "REG_PRC": 9.99})
    payload = _build_item_payload(rows, integration_config)
    assert payload["regular_price"] == "9.99"


def test_inventory_clamps_negative_to_zero(integration_config):
    rows = build_rows({"QTY_AVAIL": -4})
    payload = _build_item_payload(rows, integration_config)
    assert payload["stock_quantity"] == 0
    assert payload["stock_status"] == "outofstock"


def test_html_description_preferred(integration_config):
    html = "<p><strong>NCR</strong> carbonless forms.</p>"
    rows = build_rows({"HTML_DESCR": html})
    payload = _build_item_payload(rows, integration_config)
    assert payload["description"] == html


def test_image_url_and_slug_mapping(integration_config):
    rows = build_rows({})
    payload = _build_item_payload(rows, integration_config)
    assert payload["images"][0]["src"] == "https://cdn.example.com/img/ncr-5887.jpg"
    assert payload["slug"] == "ncr-carbonless"


def test_categories_deduplicated(integration_config):
    categories = [
        {"CATEG_DESCR": "print-and-copy-paper", "CATEG_ID": "1"},
        {"CATEG_DESCR": "ncr-carbonless", "CATEG_ID": "2"},
        {"CATEG_DESCR": "ncr-carbonless", "CATEG_ID": "2"},
    ]
    rows = build_rows({}, categories=categories)
    payload = _build_item_payload(rows, integration_config)
    slugs = [cat["slug"] for cat in payload["categories"]]
    assert slugs == ["print-and-copy-paper", "ncr-carbonless"]


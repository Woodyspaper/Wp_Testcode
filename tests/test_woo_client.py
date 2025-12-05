import json
from unittest.mock import patch

import pytest
import requests

from config import IntegrationConfig, DatabaseConfig, WooCommerceConfig
from woo_client import WooClient


@pytest.fixture
def config():
    return IntegrationConfig(
        database=DatabaseConfig(
            driver="driver",
            server="server",
            database="db",
            trusted_connection=True,
            username=None,
            password=None,
            timeout=30,
        ),
        woo=WooCommerceConfig(
            base_url="https://store.test",
            consumer_key="ck",
            consumer_secret="cs",
        ),
        image_base_url=None,
        default_loc_id="01",
    )


@patch("woo_client.requests.Session")
def test_test_connection_success(mock_session_class, config):
    mock_session = mock_session_class.return_value
    mock_response = mock_session.get.return_value
    mock_response.ok = True
    mock_response.json.return_value = [{"id": 1}]

    client = WooClient(config=config)
    assert client.test_connection() is True
    mock_session.get.assert_called()


@patch("woo_client.requests.Session")
def test_sync_products_dry_run(mock_session_class, config, caplog):
    caplog.set_level("INFO")
    client = WooClient(config=config)
    client.sync_products([{"sku": "01", "name": "test"}], dry_run=True)
    assert "DRY-RUN" in caplog.text
    mock_session_class.return_value.post.assert_not_called()


@patch("woo_client.requests.Session")
def test_sync_products_posts_when_not_dry_run(mock_session_class, config):
    mock_session = mock_session_class.return_value
    mock_response = mock_session.post.return_value
    mock_response.ok = True

    client = WooClient(config=config)
    client.sync_products([{"sku": "01", "name": "test"}], dry_run=False)
    mock_session.post.assert_called_once()


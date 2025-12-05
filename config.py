"""
Centralized configuration loading for CounterPoint and WooCommerce integrations.

Environment variables (preferred via a .env file):
    CP_SQL_SERVER          - SQL Server host (e.g., ADWPC-MAIN)
    CP_SQL_DATABASE        - Database name (e.g., WOODYS_CP)
    CP_SQL_DRIVER          - Optional ODBC driver (defaults to ODBC Driver 18 for SQL Server)
    CP_SQL_TRUSTED_CONN    - "true"/"false" for Windows auth (defaults true)
    CP_SQL_USERNAME        - Optional SQL auth username
    CP_SQL_PASSWORD        - Optional SQL auth password
    CP_SQL_TIMEOUT         - Connection timeout in seconds (defaults 30)

    WOO_BASE_URL           - WooCommerce site base URL (https://example.com)
    WOO_CONSUMER_KEY       - WooCommerce consumer key
    WOO_CONSUMER_SECRET    - WooCommerce consumer secret

    IMAGE_BASE_URL         - Base URL for product images (optional)
    DEFAULT_LOC_ID         - Location filter for inventory (defaults to "01")
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional

from dotenv import load_dotenv


_DOTENV_LOADED = False


def _ensure_dotenv_loaded() -> None:
    global _DOTENV_LOADED
    if not _DOTENV_LOADED:
        load_dotenv()
        _DOTENV_LOADED = True


@dataclass(slots=True)
class DatabaseConfig:
    """Configuration for connecting to SQL Server."""

    driver: str
    server: str
    database: str
    trusted_connection: bool
    username: Optional[str]
    password: Optional[str]
    timeout: int


@dataclass(slots=True)
class WooCommerceConfig:
    """Configuration for WooCommerce REST API."""

    base_url: str
    consumer_key: str
    consumer_secret: str


@dataclass(slots=True)
class IntegrationConfig:
    """Container for all configuration segments."""

    database: DatabaseConfig
    woo: WooCommerceConfig
    image_base_url: Optional[str]
    default_loc_id: str


def _get_env(key: str, default: Optional[str] = None) -> Optional[str]:
    _ensure_dotenv_loaded()
    value = os.getenv(key, default)
    return value


def load_integration_config() -> IntegrationConfig:
    """
    Load configuration values from environment variables.

    Raises:
        ValueError: if required configuration is missing.
    """

    driver = _get_env("CP_SQL_DRIVER", "ODBC Driver 18 for SQL Server")
    server = _get_env("CP_SQL_SERVER")
    database = _get_env("CP_SQL_DATABASE")
    trusted_conn = _get_env("CP_SQL_TRUSTED_CONN", "true").lower() in {"1", "true", "yes"}
    username = _get_env("CP_SQL_USERNAME")
    password = _get_env("CP_SQL_PASSWORD")
    timeout = int(_get_env("CP_SQL_TIMEOUT", "30"))

    if not server or not database:
        raise ValueError("CP_SQL_SERVER and CP_SQL_DATABASE must be set.")

    if not trusted_conn and (not username or not password):
        raise ValueError("SQL authentication requires CP_SQL_USERNAME and CP_SQL_PASSWORD.")

    db_config = DatabaseConfig(
        driver=driver,
        server=server,
        database=database,
        trusted_connection=trusted_conn,
        username=username,
        password=password,
        timeout=timeout,
    )

    woo_base_url = _get_env("WOO_BASE_URL")
    woo_key = _get_env("WOO_CONSUMER_KEY")
    woo_secret = _get_env("WOO_CONSUMER_SECRET")

    if not woo_base_url or not woo_key or not woo_secret:
        raise ValueError("WooCommerce configuration is incomplete (WOO_BASE_URL/KEY/SECRET).")

    woo_config = WooCommerceConfig(
        base_url=woo_base_url.rstrip("/"),
        consumer_key=woo_key,
        consumer_secret=woo_secret,
    )

    image_base_url = _get_env("IMAGE_BASE_URL")
    default_loc_id = _get_env("DEFAULT_LOC_ID", "01")

    return IntegrationConfig(
        database=db_config,
        woo=woo_config,
        image_base_url=image_base_url.rstrip("/") if image_base_url else None,
        default_loc_id=default_loc_id,
    )


__all__ = [
    "DatabaseConfig",
    "WooCommerceConfig",
    "IntegrationConfig",
    "load_integration_config",
]


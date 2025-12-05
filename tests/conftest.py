"""Pytest fixtures shared across tests."""

import pytest


@pytest.fixture(autouse=True)
def clear_env(monkeypatch):
    """Ensure tests start with a clean environment."""

    keys = [
        "CP_SQL_SERVER",
        "CP_SQL_DATABASE",
        "CP_SQL_DRIVER",
        "CP_SQL_TRUSTED_CONN",
        "CP_SQL_TIMEOUT",
        "CP_SQL_USERNAME",
        "CP_SQL_PASSWORD",
        "WOO_BASE_URL",
        "WOO_CONSUMER_KEY",
        "WOO_CONSUMER_SECRET",
        "IMAGE_BASE_URL",
        "DEFAULT_LOC_ID",
        "DRY_RUN",
        "LOG_LEVEL",
        "SYNC_BATCH_SIZE",
    ]
    for key in keys:
        monkeypatch.delenv(key, raising=False)


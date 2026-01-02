import sys
import os

# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from unittest.mock import MagicMock, patch

import pyodbc
import pytest

import database


def _set_min_env(monkeypatch):
    monkeypatch.setenv("CP_SQL_SERVER", "server")
    monkeypatch.setenv("CP_SQL_DATABASE", "db")
    monkeypatch.setenv("CP_SQL_DRIVER", "ODBC Driver 18 for SQL Server")
    monkeypatch.setenv("CP_SQL_TRUSTED_CONN", "true")
    monkeypatch.setenv("CP_SQL_TIMEOUT", "30")
    monkeypatch.setenv("WOO_BASE_URL", "https://example.com")
    monkeypatch.setenv("WOO_CONSUMER_KEY", "ck")
    monkeypatch.setenv("WOO_CONSUMER_SECRET", "cs")


@patch("database.pyodbc.connect")
def test_run_query_returns_rows(mock_connect, monkeypatch):
    _set_min_env(monkeypatch)
    cursor = MagicMock()
    cursor.description = [("ITEM_NO",), ("DESCR",)]
    cursor.fetchall.return_value = [("01", "Paper")]
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = cursor
    mock_connect.return_value = mock_conn

    rows = database.run_query("SELECT 1")
    assert rows == [{"ITEM_NO": "01", "DESCR": "Paper"}]
    mock_connect.assert_called()


@patch("database.pyodbc.connect")
def test_run_query_handles_exception(mock_connect, monkeypatch):
    _set_min_env(monkeypatch)
    mock_connect.side_effect = pyodbc.Error("boom")
    rows = database.run_query("SELECT 1")
    assert rows == []


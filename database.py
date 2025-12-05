"""
Database connectivity utilities for WOODYS_CP (CounterPoint) via pyodbc.

Safety Notes:
    - Default usage is READ-ONLY. Avoid writing to production without an explicit
      flag and staged process.
    - Connection details come from environment variables handled in config.py.
"""

from __future__ import annotations

import logging
from contextlib import contextmanager
from typing import Any, Dict, Generator, Iterable, List, Optional, Tuple

import pyodbc

from config import DatabaseConfig, load_integration_config

logger = logging.getLogger(__name__)

_CONNECTION_STRING_CACHE: Optional[str] = None


def _build_connection_string(cfg: DatabaseConfig) -> str:
    global _CONNECTION_STRING_CACHE
    if _CONNECTION_STRING_CACHE:
        return _CONNECTION_STRING_CACHE

    parts = [
        f"DRIVER={{{cfg.driver}}}",
        f"SERVER={cfg.server}",
        f"DATABASE={cfg.database}",
        f"TrustServerCertificate=yes",
        # Encrypt removed - not supported by all driver versions
        f"Connection Timeout={cfg.timeout}",
    ]

    if cfg.trusted_connection:
        parts.append("Trusted_Connection=yes")
    else:
        parts.append(f"UID={cfg.username}")
        parts.append(f"PWD={cfg.password}")

    _CONNECTION_STRING_CACHE = ";".join(parts)
    return _CONNECTION_STRING_CACHE


def get_connection() -> pyodbc.Connection:
    """
    Create and return a live pyodbc connection to WOODYS_CP.

    Returns:
        pyodbc.Connection
    """

    cfg = load_integration_config().database
    conn_str = _build_connection_string(cfg)
    logger.debug("Connecting to SQL Server %s / %s", cfg.server, cfg.database)
    logger.debug("Connection string (password hidden): %s", conn_str.replace(cfg.password or "", "***"))
    return pyodbc.connect(conn_str)


@contextmanager
def connection_ctx() -> Generator[pyodbc.Connection, None, None]:
    """Context manager wrapper so callers can use `with connection_ctx() as conn`."""

    conn = get_connection()
    try:
        yield conn
    finally:
        conn.close()


def run_query(sql: str, params: Optional[Iterable[Any]] = None) -> List[Dict[str, Any]]:
    """
    Execute a read-only query and return rows as list[dict].

    Args:
        sql: Parameterized SQL statement.
        params: Optional iterable of parameter values.

    Returns:
        List of dictionaries mapping column names to values.
    """

    params = tuple(params or [])
    logger.debug("Executing query: %s | params=%s", sql, params)

    try:
        with connection_ctx() as conn:
            conn.timeout = 60
            cursor = conn.cursor()
            cursor.execute(sql, params)
            columns = [col[0] for col in cursor.description]
            rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
            logger.info("Fetched %d rows", len(rows))
            return rows
    except pyodbc.Error as exc:
        logger.exception("Database query failed: %s", exc)
        return []


__all__ = ["get_connection", "run_query", "connection_ctx"]


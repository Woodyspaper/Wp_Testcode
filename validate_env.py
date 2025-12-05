"""
validate_env.py
Validates .env contents and reports missing or unsafe configuration.

This script is read-only: it does not contact SQL Server or WooCommerce.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

REQUIRED_FIELDS = [
    "CP_SQL_SERVER",
    "CP_SQL_DATABASE",
    "CP_SQL_DRIVER",
    "CP_SQL_TIMEOUT",
    "WOO_BASE_URL",
    "WOO_CONSUMER_KEY",
    "WOO_CONSUMER_SECRET",
    "DEFAULT_LOC_ID",
]

OPTIONAL_FIELDS_WITH_DEFAULTS = {
    "DRY_RUN": "true",
    "LOG_LEVEL": "INFO",
    "SYNC_BATCH_SIZE": "50",
    "IMAGE_BASE_URL": "",
    "CP_SQL_TRUSTED_CONN": "true",
}


def validate() -> None:
    env_path = Path(".env")
    if not env_path.exists():
        print("ERROR: .env file not found!")
        print("Copy .env.example to .env and fill in real values.")
        return

    load_dotenv(env_path)

    print("\nValidating environment variables...\n")
    errors: list[str] = []

    for key in REQUIRED_FIELDS:
        value = os.getenv(key)
        if not value or not value.strip():
            errors.append(f"{key} is missing or empty")
        else:
            print(f"{key}: OK")

    print("\nOptional fields (defaults shown if unset):")
    for key, default in OPTIONAL_FIELDS_WITH_DEFAULTS.items():
        val = os.getenv(key, default)
        print(f"   {key} = {val}")

    dry_run = os.getenv("DRY_RUN", "true").lower()
    if dry_run not in {"true", "false"}:
        errors.append("DRY_RUN must be 'true' or 'false'")
    else:
        state = "ON (safe mode)" if dry_run == "true" else "OFF (live writes!)"
        print(f"\nDRY_RUN is {state}")

    if errors:
        print("\nValidation failed:")
        for err in errors:
            print(f"   {err}")
        print("\nFix the above before running the sync.\n")
    else:
        print("\nAll required environment variables look good!\n")


if __name__ == "__main__":
    validate()


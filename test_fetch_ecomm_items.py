"""
Ad-hoc script to pull sample CounterPoint e-comm items for validation.

Usage (PowerShell example):
    setx CP_SQL_SERVER "ADWPC-MAIN"
    setx CP_SQL_DATABASE "WOODYS_CP"
    python test_fetch_ecomm_items.py
"""

from __future__ import annotations

import json
import logging
from typing import List

from database import run_query

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

SAMPLE_SQL = """
SELECT TOP 50
    i.ITEM_NO,
    i.DESCR,
    v.LOC_ID,
    v.QTY_AVAIL,
    v.PRC_1,
    v.REG_PRC,
    i.IS_ECOMM_ITEM,
    i.ECOMM_IMG_FILE,
    i.URL
FROM VI_IM_ITEM_WITH_INV v
JOIN IM_ITEM i ON v.ITEM_NO = i.ITEM_NO
WHERE v.LOC_ID = ?
  AND i.IS_ECOMM_ITEM = 'Y'
ORDER BY i.ITEM_NO;
"""


def fetch_sample(loc_id: str = "01") -> List[dict]:
    return run_query(SAMPLE_SQL, (loc_id,))


def main() -> None:
    items = fetch_sample()
    logging.info("Retrieved %d items", len(items))
    print(json.dumps(items, indent=2, default=str))


if __name__ == "__main__":
    main()



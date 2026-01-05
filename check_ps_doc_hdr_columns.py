"""Check what shipping/contact columns exist in PS_DOC_HDR"""
from database import run_query

sql = """
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' 
  AND TABLE_NAME = 'PS_DOC_HDR' 
  AND (COLUMN_NAME LIKE 'SHIP%' 
       OR COLUMN_NAME LIKE '%PHONE%' 
       OR COLUMN_NAME LIKE '%EMAIL%' 
       OR COLUMN_NAME LIKE '%NAME%'
       OR COLUMN_NAME LIKE '%ADRS%'
       OR COLUMN_NAME LIKE '%CITY%'
       OR COLUMN_NAME LIKE '%STATE%'
       OR COLUMN_NAME LIKE '%ZIP%'
       OR COLUMN_NAME LIKE '%CNTRY%')
ORDER BY COLUMN_NAME
"""

result = run_query(sql)

if result:
    print("\nShipping/Contact columns in PS_DOC_HDR:")
    print("="*60)
    for r in result:
        max_len = f"({r['CHARACTER_MAXIMUM_LENGTH']})" if r['CHARACTER_MAXIMUM_LENGTH'] else ""
        print(f"  {r['COLUMN_NAME']:<30} {r['DATA_TYPE']:<15} {max_len}")
else:
    print("No shipping/contact columns found in PS_DOC_HDR")
    print("(CounterPoint may use a separate ship-to table)")

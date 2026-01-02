#!/usr/bin/env python3
"""
Fix all import path issues in Python files
Adds project root to sys.path for files in subdirectories
"""

import os
import re
import sys

# Files that need the fix (in subdirectories importing root modules)
FILES_TO_FIX = [
    "tests/test_woo_client.py",
    "tests/test_config.py",
    "tests/test_db.py",
    "tests/test_feed_builder.py",
    "archive_files/manage_woo_customers.py",
    "archive_files/csv_tools.py",
    "archive_files/sync.py",
    "archive_files/cp_tools.py",
    "archive_files/export_woo_customers.py",
    "archive_files/feed_builder.py",
    "archive_files/set_sql_memory.py",
    "archive_files/run_tests.py",
    "test_customer_sync.py",
    "test_connection.py",
]

# Pattern to check if file imports root-level modules
ROOT_MODULE_PATTERN = re.compile(
    r'^from\s+(woo_|database|config|cp_orders_display|data_utils|woo_client|cp_product_summary|woo_contract_pricing|woo_customers|woo_products|woo_orders)\w*\s+import',
    re.MULTILINE
)

# Code to add (if not already present)
PATH_FIX_CODE = """# Add project root to Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)
"""

def needs_fix(filepath):
    """Check if file needs the import fix"""
    if not os.path.exists(filepath):
        return False
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if it imports root modules
    has_root_imports = bool(ROOT_MODULE_PATTERN.search(content))
    
    # Check if fix is already applied
    has_fix = 'sys.path.insert(0, project_root)' in content or 'sys.path.insert(0, project_root)' in content
    
    # Check if in subdirectory
    is_subdirectory = os.path.dirname(filepath) and os.path.dirname(filepath) != '.'
    
    return has_root_imports and is_subdirectory and not has_fix

def add_import_fix(filepath):
    """Add import fix to file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find where to insert (after imports, before root module imports)
    insert_index = 0
    for i, line in enumerate(lines):
        if line.startswith('import sys') or line.startswith('import os'):
            insert_index = i + 1
            # Make sure sys and os are imported
            if 'import sys' not in ''.join(lines[:i+1]):
                lines.insert(insert_index, 'import sys\n')
                insert_index += 1
            if 'import os' not in ''.join(lines[:i+1]):
                lines.insert(insert_index, 'import os\n')
                insert_index += 1
            break
    
    # If no sys/os import found, add them at the top
    if insert_index == 0:
        # Find first import
        for i, line in enumerate(lines):
            if line.startswith('import ') or line.startswith('from '):
                insert_index = i
                # Add sys and os imports
                if not any('import sys' in l for l in lines[:i]):
                    lines.insert(insert_index, 'import sys\n')
                    insert_index += 1
                if not any('import os' in l for l in lines[:i]):
                    lines.insert(insert_index, 'import os\n')
                    insert_index += 1
                break
    
    # Insert path fix code
    if insert_index > 0:
        lines.insert(insert_index, '\n' + PATH_FIX_CODE + '\n')
    else:
        # Add at beginning if no imports found
        lines.insert(0, 'import os\nimport sys\n' + PATH_FIX_CODE + '\n')
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    return True

def main():
    """Main function"""
    fixed = []
    skipped = []
    errors = []
    
    for filepath in FILES_TO_FIX:
        if needs_fix(filepath):
            try:
                add_import_fix(filepath)
                fixed.append(filepath)
                print(f"[OK] Fixed: {filepath}")
            except Exception as e:
                errors.append((filepath, str(e)))
                print(f"[ERROR] Error fixing {filepath}: {e}")
        else:
            skipped.append(filepath)
            print(f"[SKIP] Skipped: {filepath} (no fix needed)")
    
    print(f"\n[OK] Fixed: {len(fixed)} files")
    print(f"[SKIP] Skipped: {len(skipped)} files")
    if errors:
        print(f"[ERROR] Errors: {len(errors)} files")
    
    return len(fixed), len(errors)

if __name__ == '__main__':
    main()

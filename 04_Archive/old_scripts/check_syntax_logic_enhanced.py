"""
check_syntax_logic_enhanced.py
Enhanced Syntax and Logic Checker with SQL validation

Usage:
    python check_syntax_logic_enhanced.py <file_path> [--db-check]
    
Checks:
- Python: Syntax, imports, basic logic
- SQL: Syntax validation + column name warnings
- PowerShell: Syntax validation (basic)
"""

import sys
import os
import ast
import re
from pathlib import Path


def check_sql_column_names(content: str, file_path: str) -> list[str]:
    """Check for common SQL column name issues."""
    warnings = []
    
    # Common patterns that might indicate column name issues
    # Look for ORDER BY, WHERE, SELECT with potential column names
    order_by_pattern = r'ORDER\s+BY\s+(\w+)'
    where_pattern = r'WHERE\s+(\w+)\s*[=<>]'
    select_pattern = r'SELECT\s+.*?\s+FROM\s+(\w+)'
    
    # Check for ORDER BY with common wrong column names
    order_by_matches = re.findall(order_by_pattern, content, re.IGNORECASE)
    for col in order_by_matches:
        # Common mistakes
        if col.upper() in ['DAT', 'DATE', 'TIME', 'ID']:
            warnings.append(f"ORDER BY uses generic column name '{col}' - verify column exists")
    
    # Check for WHERE with potential issues
    where_matches = re.findall(where_pattern, content, re.IGNORECASE)
    
    # Check for SELECT * FROM without column verification
    if 'SELECT * FROM' in content.upper() and 'ORDER BY' in content.upper():
        # Extract table name and ORDER BY column
        table_match = re.search(r'FROM\s+(\w+)', content, re.IGNORECASE)
        order_match = re.search(r'ORDER\s+BY\s+(\w+)', content, re.IGNORECASE)
        if table_match and order_match:
            table = table_match.group(1)
            order_col = order_match.group(1)
            warnings.append(
                f"SELECT * FROM {table} ORDER BY {order_col} - "
                f"Verify column '{order_col}' exists in {table}"
            )
    
    return warnings


def check_sql_syntax(file_path: str) -> tuple[bool, list[str]]:
    """Enhanced SQL syntax check with column name validation."""
    errors = []
    warnings = []
    
    try:
        # Try UTF-8 first, fallback to latin-1
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
        except:
            with open(file_path, 'r', encoding='latin-1', errors='replace') as f:
                content = f.read()
        
        # Basic SQL checks
        # Check for balanced parentheses
        if content.count('(') != content.count(')'):
            errors.append("Unbalanced parentheses")
        
        # Check for balanced quotes (more sophisticated)
        # Count single quotes, but ignore SQL comments and escaped quotes
        lines = content.split('\n')
        in_string = False
        quote_count = 0
        for line in lines:
            # Skip comment lines
            if line.strip().startswith('--'):
                continue
            # Count quotes in non-comment lines
            for char in line:
                if char == "'":
                    quote_count += 1
        # SQL strings should have even number of quotes (pairs)
        if quote_count > 0 and quote_count % 2 != 0:
            warnings.append("Possible unbalanced single quotes (may be false positive due to comments)")
        
        # Check for common SQL patterns
        if 'SELECT' in content.upper() or 'INSERT' in content.upper() or 'UPDATE' in content.upper():
            print(f"  [OK] SQL statements: Present")
        
        # Enhanced: Check for column name issues
        column_warnings = check_sql_column_names(content, file_path)
        warnings.extend(column_warnings)
        
        # Check for ORDER BY with generic column names
        if 'ORDER BY' in content.upper():
            # Look for ORDER BY DAT, ORDER BY DATE, etc.
            if re.search(r'ORDER\s+BY\s+(DAT|DATE|TIME|ID)\s', content, re.IGNORECASE):
                warnings.append("ORDER BY uses generic column name - verify actual column name exists")
        
        # Check for transaction handling
        if 'BEGIN TRANSACTION' in content.upper() or 'BEGIN' in content.upper():
            if 'COMMIT' not in content.upper() and 'ROLLBACK' not in content.upper():
                warnings.append("Transaction started but no COMMIT/ROLLBACK found")
        
        # Check for error handling
        if 'TRY' in content.upper() and 'CATCH' not in content.upper():
            warnings.append("TRY block without CATCH")
        
        if errors:
            for e in errors:
                print(f"  [ERROR] Error: {e}")
        if warnings:
            for w in warnings:
                print(f"  [WARN] Warning: {w}")
        
        return len(errors) == 0, errors
        
    except Exception as e:
        error_msg = str(e).encode('ascii', 'replace').decode('ascii')
        errors.append(f"Error reading file: {error_msg}")
        return False, errors


def check_python_syntax(file_path: str) -> tuple[bool, list[str]]:
    """Check Python file syntax and basic logic."""
    errors = []
    warnings = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Syntax check
        try:
            ast.parse(content)
            print(f"  [OK] Syntax: Valid")
        except SyntaxError as e:
            errors.append(f"Syntax Error: {e}")
            print(f"  [ERROR] Syntax: {e}")
            return False, errors
        
        # Basic logic checks
        # Check for error handling
        if 'raise' in content or 'Exception' in content:
            print(f"  [OK] Error handling: Present")
        else:
            warnings.append("No explicit error handling found")
        
        # Check for logging
        if 'log' in content.lower() or 'print' in content:
            print(f"  [OK] Logging: Present")
        else:
            warnings.append("No logging found")
        
        if warnings:
            for w in warnings:
                print(f"  [WARN] Warning: {w}")
        
        return True, errors
        
    except Exception as e:
        errors.append(f"Error reading file: {e}")
        return False, errors


def check_powershell_syntax(file_path: str) -> tuple[bool, list[str]]:
    """Basic PowerShell syntax check."""
    errors = []
    warnings = []
    
    try:
        # Try UTF-8 first, fallback to latin-1
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
        except:
            with open(file_path, 'r', encoding='latin-1', errors='replace') as f:
                content = f.read()
        
        # Basic PowerShell checks
        # Check for balanced braces
        if content.count('{') != content.count('}'):
            errors.append("Unbalanced braces")
        
        # Check for balanced parentheses
        if content.count('(') != content.count(')'):
            errors.append("Unbalanced parentheses")
        
        # Check for common patterns
        if 'function' in content.lower() or 'param' in content.lower():
            print(f"  [OK] PowerShell structure: Present")
        
        # Check for error handling
        if 'try' in content.lower() and 'catch' not in content.lower():
            warnings.append("Try block without Catch")
        
        if errors:
            for e in errors:
                print(f"  [ERROR] Error: {e}")
        if warnings:
            for w in warnings:
                print(f"  [WARN] Warning: {w}")
        
        return len(errors) == 0, errors
        
    except Exception as e:
        error_msg = str(e).encode('ascii', 'replace').decode('ascii')
        errors.append(f"Error reading file: {error_msg}")
        return False, errors


def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python check_syntax_logic_enhanced.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not os.path.exists(file_path):
        print(f"[ERROR] File not found: {file_path}")
        sys.exit(1)
    
    print(f"============================================================")
    print(f"Enhanced Syntax & Logic Check: {file_path}")
    print(f"============================================================")
    print(f"")
    
    file_ext = Path(file_path).suffix.lower()
    
    if file_ext == '.py':
        success, errors = check_python_syntax(file_path)
    elif file_ext == '.sql':
        success, errors = check_sql_syntax(file_path)
    elif file_ext == '.ps1':
        success, errors = check_powershell_syntax(file_path)
    else:
        print(f"[WARN] Unknown file type: {file_ext}")
        print(f"   Supported: .py, .sql, .ps1")
        sys.exit(1)
    
    print(f"")
    print(f"============================================================")
    if success:
        print(f"[PASS] Syntax & Logic Check: PASSED")
    else:
        print(f"[FAIL] Syntax & Logic Check: FAILED")
        for error in errors:
            print(f"   {error}")
    print(f"============================================================")
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

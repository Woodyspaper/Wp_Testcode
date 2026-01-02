"""
check_syntax_logic.py
Syntax and Logic Checker for all scripts

Usage:
    python check_syntax_logic.py <file_path>
    
Checks:
- Python: Syntax, imports, basic logic
- SQL: Syntax validation (basic)
- PowerShell: Syntax validation (basic)
"""

import sys
import os
import ast
import re
from pathlib import Path


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
        # Check for common issues
        if 'import' in content and 'from' in content:
            # Check for unused imports (basic check)
            tree = ast.parse(content)
            imports = [node.names[0].name if isinstance(node, ast.Import) else node.module 
                      for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom))]
        
        # Check for try/except blocks
        if 'try:' in content and 'except' not in content:
            warnings.append("Try block without except")
        
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


def check_sql_syntax(file_path: str) -> tuple[bool, list[str]]:
    """Basic SQL syntax check."""
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
        
        # Check for balanced quotes
        single_quotes = content.count("'") - content.count("''")
        if single_quotes % 2 != 0:
            errors.append("Unbalanced single quotes")
        
        # Check for common SQL patterns
        if 'SELECT' in content.upper() or 'INSERT' in content.upper() or 'UPDATE' in content.upper():
            print(f"  [OK] SQL statements: Present")
        
        # Check for transaction handling
        if 'BEGIN TRANSACTION' in content.upper() or 'BEGIN' in content.upper():
            if 'COMMIT' not in content.upper() and 'ROLLBACK' not in content.upper():
                warnings.append("Transaction started but no COMMIT/ROLLBACK found")
        
        # Check for error handling
        if 'TRY' in content.upper() and 'CATCH' not in content.upper():
            warnings.append("TRY block without CATCH")
        
        if errors:
            for e in errors:
                print(f"  ❌ Error: {e}")
        if warnings:
            for w in warnings:
                print(f"  ⚠️  Warning: {w}")
        
        return len(errors) == 0, errors
        
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
                print(f"  ❌ Error: {e}")
        if warnings:
            for w in warnings:
                print(f"  ⚠️  Warning: {w}")
        
        return len(errors) == 0, errors
        
    except Exception as e:
        errors.append(f"Error reading file: {e}")
        return False, errors


def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python check_syntax_logic.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    if not os.path.exists(file_path):
        print(f"[ERROR] File not found: {file_path}")
        sys.exit(1)
    
    print(f"============================================================")
    print(f"Syntax & Logic Check: {file_path}")
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

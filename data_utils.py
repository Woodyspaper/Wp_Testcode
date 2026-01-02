"""
data_utils.py - Shared data sanitization and validation utilities

This module provides reusable functions for:
- String sanitization (Unicode, control chars, truncation)
- Email validation and normalization
- Phone number normalization
- Name parsing (prefixes, suffixes, hyphenated)
- Address overflow handling
- State/Tax code mapping
- SKU validation

Used by: woo_customers.py, woo_orders.py, csv_tools.py
"""

import re
from typing import Dict, Optional, Tuple, List
from datetime import datetime


# =============================================================================
# FIELD LENGTH LIMITS (matching AR_CUST and PS_DOC tables)
# =============================================================================

AR_CUST_LIMITS = {
    'CUST_NO': 15,
    'NAM': 40,
    'NAM_UPR': 40,
    'FST_NAM': 15,
    'LST_NAM': 25,
    'EMAIL_ADRS_1': 50,
    'PHONE_1': 25,
    'ADRS_1': 40,
    'ADRS_2': 40,
    'ADRS_3': 40,
    'CITY': 20,
    'STATE': 10,
    'ZIP_COD': 15,
    'CNTRY': 20,
    'CATEG_COD': 10,
    'TAX_COD': 10,
    'STR_ID': 10,
}

PS_DOC_LIMITS = {
    'CUST_NO': 15,
    'SHIP_NAM': 40,
    'SHIP_ADRS_1': 40,
    'SHIP_ADRS_2': 40,
    'SHIP_CITY': 20,
    'SHIP_STATE': 10,
    'SHIP_ZIP_COD': 15,
    'SHIP_CNTRY': 20,
    'SHIP_PHONE': 25,
}

# Simplified limits for common use
FIELD_LIMITS = {
    'email': 50,
    'nam': 40,
    'first_name': 15,
    'last_name': 25,
    'phone': 25,
    'address_1': 40,
    'address_2': 40,
    'city': 20,
    'state': 10,
    'postcode': 15,
    'country': 20,
    'ship_nam': 40,
    'ship_address_1': 40,
    'ship_address_2': 40,
    'ship_city': 20,
    'ship_state': 10,
    'ship_postcode': 15,
    'ship_country': 20,
    'ship_phone': 25,
}


# =============================================================================
# NAME PREFIXES AND SUFFIXES
# =============================================================================

NAME_PREFIXES = {
    'mr', 'mr.', 'mrs', 'mrs.', 'ms', 'ms.', 'miss', 'dr', 'dr.',
    'prof', 'prof.', 'rev', 'rev.', 'hon', 'hon.', 'sir', 'dame',
}

NAME_SUFFIXES = {
    'jr', 'jr.', 'sr', 'sr.', 'i', 'ii', 'iii', 'iv', 'v',
    'phd', 'ph.d', 'ph.d.', 'md', 'm.d', 'm.d.', 'esq', 'esq.',
    'cpa', 'dds', 'dvm', 'rn', 'llc', 'inc', 'corp',
}


# =============================================================================
# DISPOSABLE/SPAM EMAIL DOMAINS
# =============================================================================

DISPOSABLE_DOMAINS = {
    'mailinator.com', 'guerrillamail.com', 'tempmail.com', 'throwaway.email',
    '10minutemail.com', 'trashmail.com', 'fakeinbox.com', 'sharklasers.com',
    'spam4.me', 'yopmail.com', 'temp-mail.org', 'dispostable.com',
    'getnada.com', 'maildrop.cc', 'mintemail.com', 'emailondeck.com',
    'guerrillamail.info', 'grr.la', 'discard.email', 'discardmail.com',
    'bonggdalu.site',  # Known spam domain (reported Jan 2026)
}


# =============================================================================
# STATE/TAX CODE MAPPING
# =============================================================================

# Default tax codes by state (Florida-focused, extend as needed)
STATE_TAX_CODES = {
    'FL': {
        'default': 'FL-STATE',
        'counties': {
            'BROWARD': 'FL-BROWARD',
            'DADE': 'FL-DADE',
            'MIAMI-DADE': 'FL-DADE',
            'PALM BEACH': 'FL-PALM',
        }
    },
    'GA': {'default': 'GA-STATE'},
    'TX': {'default': 'TX-STATE'},
    'CA': {'default': 'CA-STATE'},
    'NY': {'default': 'NY-STATE'},
    'NJ': {'default': 'NJ-STATE'},
    # Add more states as needed
}

DEFAULT_TAX_CODE = 'FL-BROWARD'  # Fallback


# =============================================================================
# STRING SANITIZATION
# =============================================================================

def sanitize_string(value, max_length: int = None) -> str:
    """
    Sanitize a string for SQL Server insertion.
    
    Handles:
    - NULL/None values -> empty string
    - Unicode normalization (replace problematic chars)
    - Control character removal (tabs, newlines, null bytes)
    - Whitespace normalization
    - Length truncation
    
    Args:
        value: Any value to sanitize
        max_length: Maximum length (truncate if exceeded)
        
    Returns:
        Cleaned string safe for SQL insertion
    """
    if value is None:
        return ''
    
    # Convert to string if needed
    value = str(value)
    
    # Unicode replacements for common problematic characters
    unicode_replacements = {
        160: ' ',      # non-breaking space -> space
        8211: '-',     # en-dash -> hyphen
        8212: '-',     # em-dash -> hyphen
        8216: "'",     # left single quote
        8217: "'",     # right single quote
        8220: '"',     # left double quote
        8221: '"',     # right double quote
        8230: '...',   # ellipsis
        169: '(c)',    # copyright
        174: '(R)',    # registered
        8482: '(TM)',  # trademark
        176: ' deg',   # degree symbol
        181: 'u',      # micro sign
        215: 'x',      # multiplication sign
        247: '/',      # division sign
        8364: 'EUR',   # Euro sign
        163: 'GBP',    # Pound sign
        165: 'JPY',    # Yen sign
    }
    
    # Build cleaned string
    cleaned = ''
    for char in value:
        code = ord(char)
        
        # Standard printable ASCII (space through tilde)
        if 32 <= code <= 126:
            cleaned += char
        # Known replacements
        elif code in unicode_replacements:
            cleaned += unicode_replacements[code]
        # Extended Latin characters (accented letters) - try to keep
        elif 128 <= code <= 255:
            try:
                char.encode('latin-1')
                cleaned += char
            except UnicodeEncodeError:
                pass  # Skip if can't encode
        # Skip control characters and other problematic chars
    
    # Normalize whitespace (collapse multiple spaces, trim)
    cleaned = ' '.join(cleaned.split())
    
    # Truncate if needed
    if max_length and len(cleaned) > max_length:
        cleaned = cleaned[:max_length].rstrip()
    
    return cleaned


def sanitize_dict(data: Dict, field_limits: Dict = None) -> Dict:
    """
    Apply sanitization to all string values in a dictionary.
    
    Args:
        data: Dictionary of field -> value
        field_limits: Optional dict of field -> max_length
        
    Returns:
        Dictionary with all string values sanitized
    """
    if field_limits is None:
        field_limits = FIELD_LIMITS
    
    result = {}
    for key, value in data.items():
        if isinstance(value, str) or value is None:
            max_len = field_limits.get(key.lower().replace(' ', '_'))
            result[key] = sanitize_string(value, max_len)
        else:
            result[key] = value
    return result


# =============================================================================
# EMAIL VALIDATION
# =============================================================================

def validate_email(email: str) -> Tuple[bool, str, List[str]]:
    """
    Validate and normalize an email address.
    
    Returns:
        Tuple of (is_valid, normalized_email, warnings)
        
    Warnings include:
    - Disposable domain
    - Suspicious patterns (numbers only, etc.)
    - Missing or invalid format
    """
    warnings = []
    
    if not email:
        return False, '', ['Email is empty']
    
    # Normalize
    email = email.strip().lower()
    
    # Basic format check
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_pattern, email):
        return False, email, ['Invalid email format']
    
    # Check for disposable domain
    domain = email.split('@')[1] if '@' in email else ''
    if domain in DISPOSABLE_DOMAINS:
        warnings.append(f'Disposable email domain: {domain}')
    
    # Check for suspicious patterns
    local_part = email.split('@')[0] if '@' in email else ''
    
    # All numbers in local part (often spam)
    if local_part.isdigit():
        warnings.append('Local part is all numbers (suspicious)')
    
    # Very short local part
    if len(local_part) < 3:
        warnings.append('Very short email local part')
    
    # Random-looking strings (many numbers mixed with letters)
    if re.match(r'^[a-z]*\d{4,}[a-z]*$', local_part):
        warnings.append('Email looks auto-generated')
    
    return True, email, warnings


def is_valid_email(email: str) -> bool:
    """Simple email validation check."""
    is_valid, _, _ = validate_email(email)
    return is_valid


# =============================================================================
# PHONE NUMBER HANDLING
# =============================================================================

def normalize_phone(phone: str, country: str = 'US') -> str:
    """
    Normalize a phone number while preserving readability.
    
    Handles:
    - Various formats: (xxx) xxx-xxxx, xxx-xxx-xxxx, xxx.xxx.xxxx
    - Extensions: ext, x, extension
    - International prefixes: +1, 1-
    
    Args:
        phone: Raw phone number
        country: Country code for formatting (default US)
        
    Returns:
        Normalized phone number, max 25 chars
    """
    if not phone:
        return ''
    
    phone = str(phone).strip()
    
    # Extract extension if present
    ext_match = re.search(r'(?:ext\.?|x|extension)\s*(\d+)', phone, re.IGNORECASE)
    extension = ext_match.group(1) if ext_match else ''
    
    # Remove extension from main number for processing
    if ext_match:
        phone = phone[:ext_match.start()].strip()
    
    # Extract digits only
    digits = re.sub(r'\D', '', phone)
    
    # Handle US numbers
    if country.upper() == 'US':
        # Remove leading 1 if present
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        
        # Format as (xxx) xxx-xxxx if we have 10 digits
        if len(digits) == 10:
            formatted = f"({digits[:3]}) {digits[3:6]}-{digits[6:]}"
        else:
            # Keep original if not standard length
            formatted = phone
    else:
        # For international, just keep the cleaned digits with original format hint
        formatted = phone
    
    # Add extension back
    if extension:
        formatted = f"{formatted} ext {extension}"
    
    # Truncate to field limit
    return formatted[:25]


# =============================================================================
# NAME PARSING
# =============================================================================

def parse_name(full_name: str) -> Dict[str, str]:
    """
    Parse a full name into components.
    
    Handles:
    - Prefixes (Mr., Mrs., Dr., etc.)
    - Suffixes (Jr., III, PhD, etc.)
    - Hyphenated last names
    - Multiple middle names
    
    Returns:
        Dict with keys: prefix, first_name, middle_name, last_name, suffix, full_clean
    """
    if not full_name:
        return {
            'prefix': '',
            'first_name': '',
            'middle_name': '',
            'last_name': '',
            'suffix': '',
            'full_clean': '',
        }
    
    # Clean and split
    name = sanitize_string(full_name)
    parts = name.split()
    
    if not parts:
        return {
            'prefix': '',
            'first_name': '',
            'middle_name': '',
            'last_name': '',
            'suffix': '',
            'full_clean': '',
        }
    
    prefix = ''
    suffix = ''
    
    # Check for prefix
    if parts and parts[0].lower().rstrip('.') in {p.rstrip('.') for p in NAME_PREFIXES}:
        prefix = parts.pop(0)
    
    # Check for suffix (at end)
    if parts and parts[-1].lower().rstrip('.') in {s.rstrip('.') for s in NAME_SUFFIXES}:
        suffix = parts.pop()
    
    # Now parse remaining parts
    if len(parts) == 0:
        first_name = ''
        middle_name = ''
        last_name = ''
    elif len(parts) == 1:
        first_name = parts[0]
        middle_name = ''
        last_name = ''
    elif len(parts) == 2:
        first_name = parts[0]
        middle_name = ''
        last_name = parts[1]
    else:
        first_name = parts[0]
        last_name = parts[-1]
        middle_name = ' '.join(parts[1:-1])
    
    # Build clean full name (without prefix/suffix for database)
    full_clean = ' '.join(filter(None, [first_name, middle_name, last_name]))
    
    return {
        'prefix': prefix,
        'first_name': first_name[:15],  # Truncate to AR_CUST limit
        'middle_name': middle_name,
        'last_name': last_name[:25],    # Truncate to AR_CUST limit
        'suffix': suffix,
        'full_clean': full_clean[:40],  # Truncate to NAM limit
    }


def smart_truncate_name(first_name: str, last_name: str) -> Tuple[str, str]:
    """
    Intelligently truncate first and last name to fit AR_CUST limits.
    
    If truncation is needed, tries to keep last name intact
    since it's more important for identification.
    
    Returns:
        Tuple of (truncated_first, truncated_last)
    """
    first_name = sanitize_string(first_name or '')
    last_name = sanitize_string(last_name or '')
    
    # Last name limit: 25
    if len(last_name) > 25:
        # If hyphenated, try to keep both parts
        if '-' in last_name:
            parts = last_name.split('-')
            # Truncate each part proportionally
            total_len = sum(len(p) for p in parts)
            if total_len > 24:  # Leave room for hyphen
                ratio = 24 / total_len
                parts = [p[:max(3, int(len(p) * ratio))] for p in parts]
            last_name = '-'.join(parts)[:25]
        else:
            last_name = last_name[:25]
    
    # First name limit: 15
    if len(first_name) > 15:
        first_name = first_name[:15]
    
    return first_name, last_name


# =============================================================================
# ADDRESS HANDLING
# =============================================================================

# Address Guidelines (from legacy_docs/Address Guidelines.docx)
# - All text should be capitalized
# - Ordinal numbers: 1ST, 2ND, 3RD, 4TH
# - Cardinal directions at end: NE not N.E (no periods)
# - Address Line 2: Unit designators (STE 208, HNGR 4A) or ATTNs
# - Abbreviations: AVE, BLVD, CR, CRT, DR, HNGR, HWY, PK, PL, RM, ST, TER, TRL, WHSE
# - SUITE should NOT be abbreviated

STREET_ABBREVIATIONS = {
    'AVENUE': 'AVE',
    'BOULEVARD': 'BLVD',
    'CIRCLE': 'CR',
    'COURT': 'CRT',
    'DRIVE': 'DR',
    'HANGER': 'HNGR',
    'HIGHWAY': 'HWY',
    'PARKWAY': 'PK',
    'PLACE': 'PL',
    'ROOM': 'RM',
    'STREET': 'ST',
    'TERRANCE': 'TER',
    'TRAIL': 'TRL',
    'WAREHOUSE': 'WHSE',
    # Note: SUITE is NOT abbreviated per guidelines
}

CARDINAL_DIRECTIONS = {
    'NORTH': 'N',
    'SOUTH': 'S',
    'EAST': 'E',
    'WEST': 'W',
    'NORTHEAST': 'NE',
    'NORTHWEST': 'NW',
    'SOUTHEAST': 'SE',
    'SOUTHWEST': 'SW',
}

ORDINAL_NUMBERS = {
    'FIRST': '1ST',
    'SECOND': '2ND',
    'THIRD': '3RD',
    'FOURTH': '4TH',
    'FIFTH': '5TH',
    'SIXTH': '6TH',
    'SEVENTH': '7TH',
    'EIGHTH': '8TH',
    'NINTH': '9TH',
    'TENTH': '10TH',
    'ELEVENTH': '11TH',
    'TWELFTH': '12TH',
    'THIRTEENTH': '13TH',
    'FOURTEENTH': '14TH',
    'FIFTEENTH': '15TH',
    'SIXTEENTH': '16TH',
    'SEVENTEENTH': '17TH',
    'EIGHTEENTH': '18TH',
    'NINETEENTH': '19TH',
    'TWENTIETH': '20TH',
}

def format_address_per_guidelines(address: str) -> str:
    """
    Format address according to Woody's Paper Company Address Guidelines.
    
    Rules:
    - All text capitalized
    - Ordinal numbers: 1ST, 2ND, 3RD, 4TH
    - Cardinal directions at end: NE not N.E (no periods)
    - Street abbreviations: AVE, BLVD, etc. (but SUITE is NOT abbreviated)
    
    Args:
        address: Raw address string
        
    Returns:
        Formatted address string
    """
    if not address:
        return ''
    
    address = sanitize_string(address)
    if not address:
        return ''
    
    # Convert to uppercase
    address = address.upper()
    
    # Replace ordinal numbers
    for word, abbrev in ORDINAL_NUMBERS.items():
        # Match whole words only
        address = re.sub(r'\b' + word + r'\b', abbrev, address, flags=re.IGNORECASE)
    
    # Replace cardinal directions at end of street names (no periods)
    # Pattern: "MAIN STREET NE" -> "MAIN ST NE"
    for direction, abbrev in CARDINAL_DIRECTIONS.items():
        # Match at end of string or before comma/unit designator
        address = re.sub(
            r'\b' + direction + r'\b(?=\s*(?:,|$|STE|SUITE|UNIT|APT|#|HNGR))',
            abbrev,
            address,
            flags=re.IGNORECASE
        )
        # Also handle with periods: "N.E." -> "NE"
        address = re.sub(
            r'\b' + direction[0] + r'\.\s*' + direction[-1] + r'\.',
            abbrev,
            address,
            flags=re.IGNORECASE
        )
    
    # Replace street type abbreviations (but NOT SUITE)
    for street_type, abbrev in STREET_ABBREVIATIONS.items():
        # Match whole words only
        address = re.sub(r'\b' + street_type + r'\b', abbrev, address)
    
    # Clean up multiple spaces
    address = ' '.join(address.split())
    
    return address


def format_address_line_2(line2: str) -> str:
    """
    Format Address Line 2 per guidelines.
    
    Allowed values:
    - Unit designators: STE 208, HNGR 4A
    - ATTNs for departments or business names
    
    Args:
        line2: Raw address line 2
        
    Returns:
        Formatted address line 2 (all caps, proper formatting)
    """
    if not line2:
        return ''
    
    line2 = sanitize_string(line2)
    if not line2:
        return ''
    
    # Convert to uppercase
    line2 = line2.upper()
    
    # Normalize unit designators
    # "Suite 208" -> "STE 208", but "SUITE" stays as "SUITE" (not abbreviated)
    # Actually, per guidelines, SUITE should NOT be abbreviated, so leave it
    # But normalize spacing: "STE208" -> "STE 208"
    line2 = re.sub(r'\b(STE|SUITE|UNIT|APT|APARTMENT|#|HNGR)\s*(\d+[A-Z]?)', r'\1 \2', line2)
    
    # Clean up multiple spaces
    line2 = ' '.join(line2.split())
    
    return line2


def split_long_address(address: str, max_line_length: int = 40) -> Tuple[str, str]:
    """
    Split a long address into two lines intelligently.
    
    Tries to break at:
    1. Suite/Unit/Apt markers (always split these to line 2)
    2. Comma
    3. Last space before limit
    
    Returns:
        Tuple of (address_line_1, address_line_2) - formatted per Address Guidelines
    """
    if not address:
        return '', ''
    
    # Format address per guidelines BEFORE splitting
    address = format_address_per_guidelines(address)
    
    # Look for Suite/Unit/Apt markers FIRST (even if address fits)
    # Suite info should go to line 2 for clarity
    suite_patterns = [
        r'(.+?)(\s+(?:suite|ste|unit|apt|apartment|#)\s*.+)$',
        r'(.+?)(\s*,\s*(?:suite|ste|unit|apt|apartment|#)\s*.+)$',
    ]
    
    for pattern in suite_patterns:
        match = re.search(pattern, address, re.IGNORECASE)
        if match:
            main_address = match.group(1).strip()
            suite_part = match.group(2).strip().lstrip(',').strip()
            # Only split if it helps (main address was too long OR suite makes it cleaner)
            if len(address) > max_line_length or len(main_address) <= max_line_length:
                return main_address[:max_line_length], suite_part[:max_line_length]
    
    # If it fits after checking suite patterns, no split needed
    if len(address) <= max_line_length:
        return address, ''
    
    # Look for comma break
    if ',' in address:
        comma_pos = address.rfind(',', 0, max_line_length)
        if comma_pos > 10:  # Don't break too early
            return address[:comma_pos].strip()[:max_line_length], \
                   address[comma_pos+1:].strip()[:max_line_length]
    
    # Break at last space
    space_pos = address.rfind(' ', 0, max_line_length)
    if space_pos > 10:
        return address[:space_pos].strip()[:max_line_length], \
               address[space_pos+1:].strip()[:max_line_length]
    
    # Hard truncate as last resort
    return address[:max_line_length], ''


def normalize_state(state: str, country: str = 'US') -> str:
    """Normalize state code to uppercase 2-letter format."""
    if not state:
        return ''
    
    state = sanitize_string(state).upper()
    
    # Common full names to abbreviations (US)
    state_names = {
        'FLORIDA': 'FL', 'GEORGIA': 'GA', 'TEXAS': 'TX', 'CALIFORNIA': 'CA',
        'NEW YORK': 'NY', 'NEW JERSEY': 'NJ', 'NORTH CAROLINA': 'NC',
        'SOUTH CAROLINA': 'SC', 'ALABAMA': 'AL', 'TENNESSEE': 'TN',
        'VIRGINIA': 'VA', 'MARYLAND': 'MD', 'PENNSYLVANIA': 'PA',
        'OHIO': 'OH', 'MICHIGAN': 'MI', 'ILLINOIS': 'IL', 'COLORADO': 'CO',
        'ARIZONA': 'AZ', 'NEVADA': 'NV', 'OREGON': 'OR', 'WASHINGTON': 'WA',
    }
    
    return state_names.get(state, state[:10])


def get_tax_code(state: str, city: str = '', county: str = '') -> str:
    """
    Determine the appropriate tax code based on location.
    
    Args:
        state: State code (e.g., 'FL')
        city: City name (optional)
        county: County name (optional)
        
    Returns:
        Tax code string (e.g., 'FL-BROWARD')
    """
    state = normalize_state(state).upper()
    
    if state not in STATE_TAX_CODES:
        return DEFAULT_TAX_CODE
    
    state_config = STATE_TAX_CODES[state]
    
    # Check for county-specific tax code
    if 'counties' in state_config and county:
        county_upper = county.upper()
        if county_upper in state_config['counties']:
            return state_config['counties'][county_upper]
    
    return state_config.get('default', DEFAULT_TAX_CODE)


def abbreviate_tax_code(tax_code: str) -> str:
    """
    Abbreviate tax code to 10 characters maximum (CounterPoint limit).
    
    Uses common abbreviations for Florida counties to ensure codes fit.
    
    Args:
        tax_code: Full tax code (e.g., 'FL-BROWARD')
        
    Returns:
        Abbreviated tax code (max 10 chars, e.g., 'FL-BROWAR')
    """
    if not tax_code:
        return ''
    
    tax_code = tax_code.upper().strip()
    
    # If already 10 or less, return as-is
    if len(tax_code) <= 10:
        return tax_code
    
    # Common Florida county abbreviations
    abbreviations = {
        'FL-BROWARD': 'FL-BROWAR',
        'FL-MIAMI-DADE': 'FL-DADE',
        'FL-DADE': 'FL-DADE',
        'FL-PALM-BEACH': 'FL-PALMB',
        'FL-PALM BEACH': 'FL-PALMB',
        'FL-HILLSBOROUGH': 'FL-HILLS',
        'FL-ORANGE': 'FL-ORANG',
        'FL-PINELLAS': 'FL-PINEL',
        'FL-DUVAL': 'FL-DUVAL',
        'FL-BREVARD': 'FL-BREVA',
    }
    
    # Check for exact match
    if tax_code in abbreviations:
        return abbreviations[tax_code]
    
    # Check for partial match (starts with)
    for full, abbrev in abbreviations.items():
        if tax_code.startswith(full):
            return abbrev
    
    # Generic: truncate to 10 chars
    return tax_code[:10]


# =============================================================================
# SKU/ITEM VALIDATION
# =============================================================================

def normalize_sku(sku: str) -> str:
    """
    Normalize a SKU for matching against CounterPoint ITEM_NO.
    
    Handles:
    - Whitespace trimming
    - Case normalization (uppercase)
    - Common variations (hyphens, underscores)
    """
    if not sku:
        return ''
    
    sku = sanitize_string(sku).upper()
    
    # Remove common packaging suffixes that might differ
    # e.g., "ITEM-100" vs "ITEM-100-BOX"
    # Keep as-is for now, let the matching logic handle it
    
    return sku


# =============================================================================
# AMOUNT/CURRENCY HANDLING
# =============================================================================

def sanitize_amount(value, decimal_places: int = 2) -> float:
    """
    Sanitize a monetary amount.
    
    Handles:
    - String inputs with currency symbols
    - Comma-formatted numbers
    - Negative values
    - Empty/None values
    
    Returns:
        Float rounded to specified decimal places
    """
    if value is None or value == '':
        return 0.0
    
    if isinstance(value, (int, float)):
        return round(float(value), decimal_places)
    
    # String handling
    value = str(value)
    
    # Remove currency symbols and whitespace
    value = re.sub(r'[$€£¥,\s]', '', value)
    
    # Handle parentheses for negative (accounting format)
    if value.startswith('(') and value.endswith(')'):
        value = '-' + value[1:-1]
    
    try:
        return round(float(value), decimal_places)
    except ValueError:
        return 0.0


# =============================================================================
# DATE HANDLING
# =============================================================================

def parse_date(date_value, default=None) -> Optional[datetime]:
    """
    Parse various date formats into a datetime object.
    
    Handles:
    - ISO format: 2025-12-25T10:30:00
    - US format: 12/25/2025
    - European format: 25-12-2025
    - WooCommerce format: 2025-12-25T10:30:00
    """
    if not date_value:
        return default
    
    if isinstance(date_value, datetime):
        return date_value
    
    date_str = str(date_value).strip()
    
    formats = [
        '%Y-%m-%dT%H:%M:%S',   # ISO with time
        '%Y-%m-%d %H:%M:%S',   # SQL Server format
        '%Y-%m-%d',            # ISO date only
        '%m/%d/%Y',            # US format
        '%d-%m-%Y',            # European format
        '%m/%d/%y',            # Short year
    ]
    
    for fmt in formats:
        try:
            return datetime.strptime(date_str[:19], fmt)
        except ValueError:
            continue
    
    return default


def format_date_for_sql(date_value) -> Optional[str]:
    """Format a date for SQL Server insertion."""
    parsed = parse_date(date_value)
    if parsed:
        return parsed.strftime('%Y-%m-%d %H:%M:%S')
    return None


def convert_woo_date_to_local(woo_date_str: str, date_only: bool = False) -> str:
    """
    Convert WooCommerce UTC date to local time for CounterPoint.
    
    WooCommerce stores all dates in UTC (e.g., '2025-12-18T18:30:00').
    CounterPoint uses local time (e.g., Eastern Time).
    
    This function handles the conversion explicitly per sync-invariants.md #7:
    "Timezone normalization is required (Woo UTC → local/CP time)."
    
    Args:
        woo_date_str: WooCommerce date string (ISO format, UTC)
        date_only: If True, return only date (YYYY-MM-DD), else full datetime
        
    Returns:
        Local time string in format 'YYYY-MM-DD' or 'YYYY-MM-DD HH:MM:SS'
        
    Example:
        >>> convert_woo_date_to_local('2025-12-18T18:30:00')  # UTC 6:30 PM
        '2025-12-18 13:30:00'  # EST 1:30 PM (during EST, -5 hours)
    """
    from datetime import timezone
    
    if not woo_date_str:
        return ''
    
    try:
        date_str = str(woo_date_str).strip()
        
        # Remove trailing 'Z' if present and treat as UTC
        if date_str.endswith('Z'):
            date_str = date_str[:-1]
        
        # Parse the date string
        # WooCommerce format: 2025-12-18T18:30:00
        if 'T' in date_str:
            dt_naive = datetime.strptime(date_str[:19], '%Y-%m-%dT%H:%M:%S')
        else:
            dt_naive = datetime.strptime(date_str[:19], '%Y-%m-%d %H:%M:%S')
        
        # Treat as UTC
        dt_utc = dt_naive.replace(tzinfo=timezone.utc)
        
        # Convert to local time (server's timezone)
        dt_local = dt_utc.astimezone()
        
        # Format for output
        if date_only:
            return dt_local.strftime('%Y-%m-%d')
        else:
            return dt_local.strftime('%Y-%m-%d %H:%M:%S')
            
    except (ValueError, TypeError) as e:
        # If parsing fails, return original date portion as fallback
        # Log this for debugging
        import logging
        logging.getLogger(__name__).warning(
            f"Failed to convert WooCommerce date '{woo_date_str}': {e}"
        )
        # Fallback: return first 10 chars (date portion) or first 19 (datetime)
        if date_only:
            return str(woo_date_str)[:10] if woo_date_str else ''
        else:
            return str(woo_date_str)[:19] if woo_date_str else ''


def get_local_timezone_name() -> str:
    """Get the name of the local timezone for logging/display."""
    try:
        from datetime import timezone
        local_offset = datetime.now().astimezone().strftime('%z')
        # Convert +HHMM to +HH:MM format
        offset_str = f"{local_offset[:3]}:{local_offset[3:]}"
        
        # Common timezone abbreviations based on offset
        tz_names = {
            '-05:00': 'EST',
            '-04:00': 'EDT',
            '-06:00': 'CST',
            '-05:00': 'CDT',
            '-08:00': 'PST',
            '-07:00': 'PDT',
        }
        return tz_names.get(offset_str, f'UTC{offset_str}')
    except Exception:
        return 'LOCAL'


# =============================================================================
# DUPLICATE DETECTION
# =============================================================================

def generate_customer_fingerprint(email: str, phone: str, name: str) -> str:
    """
    Generate a fingerprint for duplicate detection.
    
    Uses normalized versions of email, phone, and name
    to identify potential duplicates even with slight variations.
    """
    # Normalize email
    email_clean = (email or '').lower().strip()
    
    # Normalize phone (digits only)
    phone_clean = re.sub(r'\D', '', phone or '')
    if len(phone_clean) == 11 and phone_clean.startswith('1'):
        phone_clean = phone_clean[1:]
    
    # Normalize name (lowercase, no punctuation)
    name_clean = re.sub(r'[^a-z\s]', '', (name or '').lower())
    name_clean = ' '.join(name_clean.split())
    
    return f"{email_clean}|{phone_clean}|{name_clean}"


# =============================================================================
# LOGGING/AUDIT HELPERS
# =============================================================================

def log_data_issue(issue_type: str, record_id, field: str, 
                   original_value, sanitized_value, severity: str = 'WARNING') -> Dict:
    """
    Create a structured log entry for data issues.
    
    Returns a dict suitable for logging or storing in audit table.
    """
    return {
        'timestamp': datetime.now().isoformat(),
        'severity': severity,
        'issue_type': issue_type,
        'record_id': record_id,
        'field': field,
        'original_value': str(original_value)[:100],
        'sanitized_value': str(sanitized_value)[:100],
    }

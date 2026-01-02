"""
check_order_processing_health.py
Quick health check for order processing system

Returns exit code:
  0 = Healthy (all systems operational)
  1 = Warning (minor issues, but functional)
  2 = Critical (major issues, needs attention)
"""

import sys
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta

# Add project root to path
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from database import get_connection, connection_ctx


def check_pending_orders(conn):
    """Check for pending orders and their age."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT 
            COUNT(*) AS PendingCount,
            MIN(CREATED_DT) AS OldestOrder,
            MAX(CREATED_DT) AS NewestOrder
        FROM dbo.USER_ORDER_STAGING
        WHERE IS_APPLIED = 0;
    """)
    row = cursor.fetchone()
    cursor.close()
    
    if row:
        count = row[0] or 0
        oldest = row[1]
        newest = row[2]
        
        if count > 0 and oldest:
            age_hours = (datetime.now() - oldest).total_seconds() / 3600
            return {
                'count': count,
                'oldest_age_hours': age_hours,
                'oldest_date': oldest,
                'newest_date': newest,
                'status': 'critical' if age_hours > 2 else 'warning' if age_hours > 1 else 'ok'
            }
    
    return {'count': 0, 'status': 'ok'}


def check_failed_orders(conn):
    """Check for failed orders (validation errors)."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT 
            COUNT(*) AS FailedCount,
            COUNT(CASE WHEN CREATED_DT < DATEADD(HOUR, -1, GETDATE()) THEN 1 END) AS FailedOver1Hour
        FROM dbo.USER_ORDER_STAGING
        WHERE IS_APPLIED = 0
          AND VALIDATION_ERROR IS NOT NULL;
    """)
    row = cursor.fetchone()
    cursor.close()
    
    if row:
        total = row[0] or 0
        old = row[1] or 0
        return {
            'total': total,
            'over_1_hour': old,
            'status': 'critical' if old > 5 else 'warning' if total > 0 else 'ok'
        }
    
    return {'total': 0, 'over_1_hour': 0, 'status': 'ok'}


def check_last_processing(conn):
    """Check when orders were last processed successfully."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT TOP 1 START_TIME
        FROM dbo.USER_SYNC_LOG
        WHERE OPERATION_TYPE = 'order_processing'
          AND SUCCESS = 1
        ORDER BY START_TIME DESC;
    """)
    row = cursor.fetchone()
    cursor.close()
    
    if row and row[0]:
        last_run = row[0]
        hours_ago = (datetime.now() - last_run).total_seconds() / 3600
        return {
            'last_run': last_run,
            'hours_ago': hours_ago,
            'status': 'critical' if hours_ago > 6 else 'warning' if hours_ago > 3 else 'ok'
        }
    
    return {'last_run': None, 'hours_ago': None, 'status': 'warning'}


def check_recent_errors(conn):
    """Check for recent processing errors."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT COUNT(*) AS ErrorCount
        FROM dbo.USER_SYNC_LOG
        WHERE OPERATION_TYPE = 'order_processing'
          AND SUCCESS = 0
          AND START_TIME >= DATEADD(HOUR, -1, GETDATE());
    """)
    row = cursor.fetchone()
    cursor.close()
    
    if row:
        count = row[0] or 0
        return {
            'count': count,
            'status': 'critical' if count > 3 else 'warning' if count > 0 else 'ok'
        }
    
    return {'count': 0, 'status': 'ok'}


def send_email_alert(subject, body, to_emails=None):
    """Send email alert if configured."""
    if not to_emails:
        to_emails = os.getenv('ORDER_PROCESSING_ALERT_EMAIL', '').split(',')
        to_emails = [e.strip() for e in to_emails if e.strip()]
    
    if not to_emails:
        return False  # Email not configured
    
    smtp_server = os.getenv('ORDER_PROCESSING_SMTP_SERVER', '')
    smtp_port = int(os.getenv('ORDER_PROCESSING_SMTP_PORT', '25'))
    from_email = os.getenv('ORDER_PROCESSING_ALERT_FROM', to_emails[0] if to_emails else '')
    
    if not smtp_server:
        # Try to detect from email domain
        if to_emails:
            email_domain = to_emails[0].split('@')[1] if '@' in to_emails[0] else None
            if email_domain:
                smtp_server = f'smtp.{email_domain}'
            else:
                return False
    
    try:
        msg = MIMEMultipart()
        msg['From'] = from_email
        msg['To'] = ', '.join(to_emails)
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'plain'))
        
        server = smtplib.SMTP(smtp_server, smtp_port)
        if smtp_port in [587, 465]:
            server.starttls()
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"WARNING: Failed to send email alert: {e}")
        return False


def main():
    """Run health check and return appropriate exit code."""
    try:
        with connection_ctx() as conn:
            print("=" * 60)
            print("ORDER PROCESSING HEALTH CHECK")
            print("=" * 60)
            print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print()
            
            overall_status = 'ok'
            issues = []
            
            # Check pending orders
            print("1. Checking pending orders...")
            pending = check_pending_orders(conn)
            if pending['count'] > 0:
                print(f"   ⚠️  {pending['count']} pending order(s)")
                print(f"   Oldest: {pending.get('oldest_age_hours', 0):.1f} hours ago")
                if pending['status'] == 'critical':
                    issues.append(f"CRITICAL: Orders pending > 2 hours ({pending['count']} orders)")
                    overall_status = 'critical'
                elif pending['status'] == 'warning':
                    issues.append(f"WARNING: Orders pending > 1 hour ({pending['count']} orders)")
                    if overall_status == 'ok':
                        overall_status = 'warning'
            else:
                print("   ✅ No pending orders")
            print()
            
            # Check failed orders
            print("2. Checking failed orders...")
            failed = check_failed_orders(conn)
            if failed['total'] > 0:
                print(f"   ⚠️  {failed['total']} failed order(s)")
                if failed['over_1_hour'] > 0:
                    print(f"   {failed['over_1_hour']} failed > 1 hour ago")
                if failed['status'] == 'critical':
                    issues.append(f"CRITICAL: {failed['over_1_hour']} orders failed > 1 hour ago")
                    overall_status = 'critical'
                elif failed['status'] == 'warning':
                    issues.append(f"WARNING: {failed['total']} orders have validation errors")
                    if overall_status == 'ok':
                        overall_status = 'warning'
            else:
                print("   ✅ No failed orders")
            print()
            
            # Check last processing
            print("3. Checking last successful processing...")
            last = check_last_processing(conn)
            if last['last_run']:
                print(f"   ✅ Last run: {last['hours_ago']:.1f} hours ago")
                if last['status'] == 'critical':
                    issues.append(f"CRITICAL: No successful processing in {last['hours_ago']:.1f} hours")
                    overall_status = 'critical'
                elif last['status'] == 'warning':
                    issues.append(f"WARNING: No successful processing in {last['hours_ago']:.1f} hours")
                    if overall_status == 'ok':
                        overall_status = 'warning'
            else:
                print("   ⚠️  No processing history found")
                issues.append("WARNING: No processing history (first run?)")
                if overall_status == 'ok':
                    overall_status = 'warning'
            print()
            
            # Check recent errors
            print("4. Checking recent errors...")
            errors = check_recent_errors(conn)
            if errors['count'] > 0:
                print(f"   ⚠️  {errors['count']} error(s) in last hour")
                if errors['status'] == 'critical':
                    issues.append(f"CRITICAL: {errors['count']} processing errors in last hour")
                    overall_status = 'critical'
                elif errors['status'] == 'warning':
                    issues.append(f"WARNING: {errors['count']} processing errors in last hour")
                    if overall_status == 'ok':
                        overall_status = 'warning'
            else:
                print("   ✅ No recent errors")
            print()
            
            # Summary
            print("=" * 60)
            print("SUMMARY")
            print("=" * 60)
            
            if overall_status == 'ok':
                print("✅ SYSTEM HEALTHY")
                print("   All systems operational")
                return 0
            elif overall_status == 'warning':
                print("⚠️  SYSTEM WARNING")
                print("   Minor issues detected, but system is functional")
                for issue in issues:
                    print(f"   - {issue}")
                return 1
            else:
                print("❌ SYSTEM CRITICAL")
                print("   Major issues detected, immediate attention required")
                for issue in issues:
                    print(f"   - {issue}")
                print()
                print("Recommended actions:")
                print("  1. Check logs: logs/woo_order_processing_*.log")
                print("  2. Check Task Scheduler: WP_WooCommerce_Order_Processing")
                print("  3. Check failed orders: python cp_order_processor.py list")
                print("  4. Manually process: python cp_order_processor.py process --all")
                
                # Send email alert for critical status
                email_body = "CRITICAL: Order Processing System Issues Detected\n\n"
                email_body += "Issues:\n"
                for issue in issues:
                    email_body += f"  - {issue}\n"
                email_body += "\nRecommended actions:\n"
                email_body += "  1. Check logs: logs/woo_order_processing_*.log\n"
                email_body += "  2. Check Task Scheduler: WP_WooCommerce_Order_Processing\n"
                email_body += "  3. Check failed orders: python cp_order_processor.py list\n"
                email_body += "  4. Manually process: python cp_order_processor.py process --all\n"
                
                send_email_alert("CRITICAL: Order Processing System Issues", email_body)
                
                return 2
                
    except Exception as e:
        print(f"❌ ERROR: Health check failed: {e}")
        import traceback
        traceback.print_exc()
        return 2


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)

# DO NOT TOUCH (Production Safety List)

> ⚠️ These settings are critical to production stability. Do not modify without explicit approval and a tested rollback plan.

---

## Checkout / Payments
- Payment gateway credentials (NMI, Stripe, etc.)
- Checkout field editors / validation plugins
- Anything labeled "Webhooks", "REST", "API", "Background jobs"

---

## Shipping (high risk)
- UPS Live Rates settings
- FedEx Live Rates settings
- Shipping zones, methods, access points settings
- Debug/administrator notices settings (don't hide without logging)

---

## Tax (high risk)
- Tax exemption plugins settings
- Automated tax calculation settings
- Customer tax classes

---

## User/Role Systems (integration-critical)
- Roles/capabilities plugins (Members, B2B, etc.)
- Customer role mapping rules
- Any plugin that modifies customer creation during checkout

---

## Caching / Performance (can mask bugs)
- WP Rocket cache rules
- Object cache settings
- CDN cache rules

> ⚠️ Only change caching when you can retest pricing + checkout end-to-end.

---

## Core Updates (requires backup + staging)
- WordPress major updates
- WooCommerce major updates
- Theme updates when Woo templates are overridden

---

## Why This List Exists

Changes to these systems can:
1. Break checkout silently (lost revenue)
2. Corrupt customer/order data (integration failure)
3. Create pricing discrepancies (compliance risk)
4. Mask errors that compound over time

**When in doubt, don't touch it. Ask first.**









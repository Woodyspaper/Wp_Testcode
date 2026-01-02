# Woody's Paper — Cursor Rules (HARD)

## Scope
This project involves WooCommerce (WordPress) ↔ NCR CounterPoint integration.
CounterPoint is the source of truth for: pricing, customers, inventory, tax.

## Non-negotiables
- Never implement pricing logic in WooCommerce beyond DISPLAY rules.
- Never write directly to production DB without explicit instruction.
- Never assume WooCommerce API returns complete truth.
- Never assume webhooks fire.
- Any change must be reversible.

## Stop Conditions (must ask before proceeding)
Stop and ask if:
- The change affects pricing calculation (not display)
- The change touches shipping rates, taxes, checkout, payment gateways
- The change modifies customer role assignment or account matching
- A fix requires editing theme templates or Woo core files
- A change impacts multiple plugins simultaneously
- Rollback plan is not defined

## Output requirements
When proposing a change, always provide:
1) What file/hook/plugin is responsible
2) Minimal change option
3) Rollback steps
4) How to test (guest + logged-in + admin)

## Preferred implementation order
1) Plugin settings / native option
2) Child theme override (woocommerce template override only if necessary)
3) Code Snippets plugin (small, reversible)
4) Custom plugin (best for production)

**Never edit WooCommerce core.**

## Testing checklist (minimum)
- [ ] Product list page shows expected price
- [ ] Single product page shows expected price
- [ ] Variable product: selected variation updates price correctly
- [ ] Add to cart price matches product page
- [ ] Checkout totals match cart
- [ ] Logged-out and logged-in behavior checked

## Ready-to-use prompts

### Prompt A — "Safe Fix Mode"
```
Follow .cursor/rules.md and .cursor/policy.json.
Identify the responsible component (plugin/theme/template/hook) and propose the smallest reversible change.
Include rollback steps and a test plan (guest, logged-in, admin).
If the change touches shipping/tax/payment/pricing calculation, STOP and ask.
```

### Prompt B — "Debug Admin Shipping Notices"
```
I'm seeing admin-only notices: UPS invalid zip, UPS accessory unavailable, FedEx auth failed.
Determine whether customers will see them, and how to fix without hiding real checkout failures.
Provide: likely cause, where to verify settings, and a safe fallback strategy if carrier APIs fail.
```

### Prompt C — "Audit template overrides + compatibility"
```
Check whether the theme overrides WooCommerce templates.
List overridden templates and whether they match current WooCommerce versions.
Provide safest path: update theme vs child theme vs replacing templates.
```



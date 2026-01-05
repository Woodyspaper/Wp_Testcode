# Sync Invariants (Never Break These)

> These are **non-negotiable truths** that the sync system must preserve at all times.

---

## The Nine Invariants

### 1. CounterPoint pricing is authoritative
WooCommerce displays prices. CounterPoint calculates them.

### 2. WooCommerce price display may change; price computation may not move into Woo
You can change *how* prices appear. You cannot change *where* prices come from.

### 3. Never rely solely on Woo `/customers` endpoint
It does not return all customers. Use `role=all` and expect gaps.

### 4. Webhooks are best-effort only; polling is required
Never assume a webhook fired. Always have a polling fallback.

### 5. Guest orders must still create CP customer + CP order
No customer record in Woo ≠ no customer in CounterPoint.

### 6. All API pulls must paginate until empty response
Never trust `X-WP-Total`. Pull until you get `[]`.

### 7. Timezone normalization is required
WooCommerce stores UTC. CounterPoint uses local time. Convert explicitly.

### 8. String sanitation required before SQL
Unicode characters, special quotes, and length limits can break inserts.

### 9. Any failure must be logged with enough context to replay
If it fails, you must be able to diagnose and retry.

---

## Violations

If any code violates these invariants:

1. **STOP** — Do not deploy
2. **DOCUMENT** — Record the violation
3. **FIX** — Restore invariant compliance
4. **VERIFY** — Test the fix

---

## Quick Reference Table

| # | Invariant | Risk if Violated |
|---|-----------|------------------|
| 1 | CP pricing authoritative | Incorrect pricing → revenue loss |
| 2 | No Woo price computation | Price drift → audit failure |
| 3 | Don't trust /customers | Missing customers → broken sync |
| 4 | Polling required | Lost orders → revenue loss |
| 5 | Guest → CP customer | Orphan orders → reconciliation nightmare |
| 6 | Paginate until empty | Partial data → sync corruption |
| 7 | Timezone normalization | Wrong timestamps → order confusion |
| 8 | String sanitation | SQL errors → failed inserts |
| 9 | Log failures for replay | Silent failures → data loss |









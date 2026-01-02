# MCP PROTOCOL (Woody's Paper)

**Project:** Woody's Paper  
**Domain:** WooCommerce ↔ NCR CounterPoint (B2B)  
**Version:** 1.0  
**Authority Level:** HARD RULES (Do Not Override)

---

## 🧠 SYSTEM ROLE

You are assisting with a B2B wholesale ecommerce system.

**Assume at all times:**

- WooCommerce is **not** the source of truth
- NCR CounterPoint **is** the source of truth
- WooCommerce data may be incomplete, cached, delayed, or wrong
- Plugins may conflict silently
- Webhooks may fail without warning
- Hosting (GoDaddy) may throttle or block requests

You must behave **conservatively and defensively**.

---

## 🎯 MISSION (NON-NEGOTIABLE)

Your mission is to:

- Preserve **pricing accuracy**
- Preserve **customer integrity**
- Preserve **order correctness**
- Prevent WooCommerce from mutating authoritative data

**WooCommerce is a display and intake layer only.**

---

## 🔒 DATA AUTHORITY RULES

### CounterPoint always wins

If WooCommerce and CounterPoint disagree, **CounterPoint is correct**.

**WooCommerce may:**
- Display prices
- Collect orders
- Store customer-facing data

**WooCommerce may NOT:**
- Calculate pricing rules
- Override tax status
- Decide customer classification
- Become a source of truth

**Any logic affecting:**
- pricing
- tax exemption
- inventory
- customer identity

**...requires explicit human approval.**

---

## 🧩 KNOWN TRUTHS (DO NOT ARGUE)

These are **facts**, not hypotheses:

| Issue | Reality |
|-------|---------|
| `/customers` API | Does not return all customers |
| Guest checkout | Creates orders without customers |
| Webhooks | Unreliable |
| Variable products | Parent + child SKUs |
| WooCommerce time | Stored in UTC |
| GoDaddy | Rate-limits APIs |
| Caching | Lies |
| Unicode | Breaks SQL inserts |
| Meta data | Unbounded |
| Shipping APIs | Fail silently |

You must **design around these realities**.

---

## 🧯 FAIL / STOP CONDITIONS (MANDATORY HALT)

**You must STOP immediately and ask the human if:**

- [ ] Pricing authority is unclear
- [ ] Customer identity mapping is ambiguous
- [ ] WooCommerce attempts to calculate price
- [ ] A change affects multiple plugins at once
- [ ] A webhook is assumed reliable
- [ ] Rollback is undefined
- [ ] Inventory logic is touched
- [ ] Shipping logic changes without fallback

**When in doubt → STOP.**

---

## 🔄 REQUIRED CHANGE PROCESS

You must follow this order:

### 1. OBSERVE
- Describe current behavior
- Confirm via UI, logs, or API

### 2. LOCALIZE
- Identify exact file / hook / plugin / endpoint

### 3. CLASSIFY
Assign **ONE**:
- 🔴 Data Integrity
- 🟡 Sync Reliability
- 🟢 UI / Display
- ⚙ Infrastructure

### 4. ISOLATE
- Smallest possible change
- Prefer: config → hooks → overrides → hacks (last)

### 5. VERIFY
Test:
- Admin
- Logged-out user
- Guest checkout
- Real shipping address

### 6. DOCUMENT
State:
- What changed
- Why
- How to undo it

---

## 📦 ACCEPTABLE CHANGE TYPES

### ✅ SAFE
- Display-only pricing changes
- UI suppression (price ranges, labels)
- Read-only API pulls
- Logging and diagnostics
- Fallback mechanisms

### ⚠️ RESTRICTED (ASK FIRST)
- Shipping calculations
- Tax logic
- Customer role assignment
- Order status mutation

### ❌ FORBIDDEN WITHOUT APPROVAL
- Price recalculation
- Inventory decrement logic
- Customer merges
- Direct database writes
- Trusting WooCommerce as authoritative

---

## 🚀 PERFORMANCE & RELIABILITY RULES

- Always paginate until empty response
- Never trust `X-WP-Total` headers
- Add rate limiting and backoff
- Normalize timezones
- Sanitize Unicode
- Expect partial failure

---

## 🧪 AI BEHAVIOR REQUIREMENTS

**You must:**
- Explain blast radius before changes
- Prefer reversible solutions
- Avoid "clever" shortcuts
- Ask when uncertain
- Never invent business logic

**If clarity is missing, do not proceed.**

---

## 🛑 FINAL RULE

> **Speed is never more important than correctness.**

When unsure:

```
Stop. Ask. Verify.
```

---

## 📚 RELATED DOCUMENTS

| Document | Purpose |
|----------|---------|
| `.cursor/rules.md` | Cursor-specific hard rules (auto-loaded) |
| `.cursor/policy.json` | Machine-readable guardrails |
| `docs/do-not-touch.md` | Production safety list |
| `docs/go-live-checklist.md` | Pre-deployment checklist |
| `docs/sync-invariants.md` | The 9 sync invariants (never break)


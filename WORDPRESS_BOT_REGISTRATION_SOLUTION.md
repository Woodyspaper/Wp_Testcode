# WordPress Bot Registration Prevention & Cleanup

**Date:** January 2, 2026  
**Issue:** Bot/spam registrations on WordPress/WooCommerce site  
**Status:** ✅ **SOLUTION PROVIDED**

---

## 🚨 **THE PROBLEM**

**Bot registrations are coming in:**
- Example: `bizmindroute@bonggdalu.site`
- These are automated spam registrations
- Clutter the customer database
- May cause issues with customer sync
- Waste database space

---

## 🛡️ **PREVENTION SOLUTIONS**

### **1. WordPress Security Plugins** ⭐⭐⭐ **RECOMMENDED**

#### **Option A: Wordfence Security (Free)**
- **Install:** WordPress Admin → Plugins → Add New → Search "Wordfence"
- **Features:**
  - Firewall protection
  - Login security
  - Bot detection
  - Rate limiting
  - Email domain blocking

#### **Option B: reCAPTCHA v3 (Google)**
- **Install:** WordPress Admin → Plugins → Add New → Search "reCAPTCHA"
- **Features:**
  - Invisible CAPTCHA (no user interaction)
  - Bot detection
  - Works with WooCommerce registration

#### **Option C: Stop Spammers (Free)**
- **Install:** WordPress Admin → Plugins → Add New → Search "Stop Spammers"
- **Features:**
  - Blocks known spam IPs
  - Email domain blocking
  - Registration filtering

---

### **2. WooCommerce-Specific Solutions**

#### **Option A: WooCommerce Anti-Fraud**
- Built into WooCommerce
- Can be configured for registration

#### **Option B: Custom Registration Validation**
- Add required fields (company name, phone)
- Email domain validation
- Honeypot fields

---

### **3. Server-Level Solutions**

#### **Option A: .htaccess Rules**
Block known spam domains at server level.

#### **Option B: Cloudflare (If Using)**
- Enable Bot Fight Mode
- Enable Challenge Passage
- Block suspicious registrations

---

## 🧹 **CLEANUP EXISTING SPAM**

### **Quick Cleanup Script**

I'll create a Python script to identify and delete spam registrations:

**Criteria for Spam Detection:**
- Disposable email domains (temp-mail, etc.)
- Suspicious email patterns
- Missing required fields (company, phone, address)
- No orders placed
- Recent registration with no activity

---

## 📋 **IMMEDIATE ACTIONS**

### **Step 1: Install Security Plugin (5 minutes)**

**Recommended: Wordfence Security**

1. **Install:**
   - WordPress Admin → Plugins → Add New
   - Search "Wordfence Security"
   - Install and Activate

2. **Configure:**
   - Enable Firewall
   - Enable Login Security
   - Enable Rate Limiting
   - Block suspicious registrations

### **Step 2: Enable reCAPTCHA (10 minutes)**

1. **Get reCAPTCHA Keys:**
   - Go to: https://www.google.com/recaptcha/admin
   - Create reCAPTCHA v3 site
   - Get Site Key and Secret Key

2. **Install Plugin:**
   - WordPress Admin → Plugins → Add New
   - Search "reCAPTCHA v3 for Contact Form 7" or "Advanced noCaptcha & invisible Captcha"
   - Install and configure with your keys

3. **Enable for Registration:**
   - Configure to protect registration forms
   - Enable for WooCommerce registration

### **Step 3: Clean Up Existing Spam (15 minutes)**

Run the cleanup script (I'll create it next).

---

## 🔧 **CUSTOM VALIDATION (Advanced)**

### **Add Registration Requirements:**

1. **Require Company Name** - B2B sites should require business name
2. **Require Phone Number** - Legitimate businesses have phones
3. **Email Domain Validation** - Block disposable email domains
4. **Honeypot Field** - Hidden field that bots fill (humans don't)

---

## 📊 **SPAM DETECTION CRITERIA**

### **Email-Based Detection:**
- Disposable email domains (temp-mail.org, etc.)
- Suspicious patterns (random characters)
- Invalid email format

### **Profile-Based Detection:**
- Missing company name
- Missing phone number
- Missing address
- No orders placed
- No activity after registration

### **Pattern-Based Detection:**
- Username matches email (often bot pattern)
- Random character usernames
- Recent bulk registrations from same IP

---

## ✅ **RECOMMENDED SETUP**

### **Quick Setup (30 minutes):**

1. **Install Wordfence Security** (free)
   - Enable firewall
   - Enable login security
   - Configure rate limiting

2. **Install reCAPTCHA v3** (free)
   - Get Google reCAPTCHA keys
   - Configure for registration

3. **Run Cleanup Script**
   - Remove existing spam registrations
   - Clean up database

4. **Configure WooCommerce**
   - Require company name on registration
   - Require phone number
   - Enable email verification

---

## 🚨 **IMMEDIATE FIX**

**To stop registrations immediately:**

1. **Temporarily Disable Public Registration:**
   - WordPress Admin → Settings → General
   - Uncheck "Anyone can register"
   - Save changes

2. **Or Require Admin Approval:**
   - Install "New User Approve" plugin
   - All registrations require admin approval

---

**Next Steps:**
1. I'll create a cleanup script to remove existing spam
2. I'll create a registration validation script
3. I'll document the recommended security setup

---

**Last Updated:** January 2, 2026  
**Status:** 📋 **SOLUTION PROVIDED - Cleanup Script Next**

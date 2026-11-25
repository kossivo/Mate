# App Store Connect Listing & Metadata Pack

This document contains all verified metadata required to publish **Mate** on the Apple App Store.

---

## 1. App Store Metadata

| Field | Value | Constraints / Notes |
|---|---|---|
| **App Name** | `Mate: Smart Daily Planner` | Exactly 25 characters (Max 30) |
| **Subtitle** | `AI Schedule & Calendar Focus` | Exactly 28 characters (Max 30) |
| **Primary Category** | `Productivity` | High conversion category |
| **Secondary Category** | `Utilities` | Secondary search discovery |
| **Keywords** | `productivity,calendar,schedule,planner,time blocking,ai,siri,reminders,todo,focus,agenda` | Exactly 90 characters (Max 100, no spaces after commas) |
| **Support URL** | `https://ngoctran.github.io/Mate/` | Free GitHub Pages link |
| **Marketing URL** | `https://ngoctran.github.io/Mate/` | Optional product landing link |
| **Privacy Policy URL**| `https://ngoctran.github.io/Mate/` | **Mandatory** |

---

## 2. Promotional Text (170 characters max)
> Capture rambling thoughts, auto-schedule focus time around your meetings, and supercharge your day with on-device Apple Intelligence. Zero tracking, 100% private.

---

## 3. Full App Description

```markdown
Turn your rambling thoughts into scheduled reality.

Mate is an intelligent, privacy-first personal productivity assistant built natively for the Apple ecosystem. Unlike traditional to-do lists that require tedious manual time-blocking, Mate bridges your thoughts, tasks, Apple Calendar, and Reminders into a single, automated daily flow.

### UNIVERSAL NATURAL LANGUAGE CAPTURE
Dictate or type complex multi-task sentences in plain English:
"I need to finish my presentation by Friday, call Mum tonight and exercise three times this week."
Mate’s on-device intelligence instantly decomposes your thoughts into structured tasks with inferred deadlines, durations, categories, and recurrence rules.

### DETERMINISTIC SMART SCHEDULING
- Auto-slots tasks into open calendar gaps during your preferred working hours.
- Respects 10-minute meeting transition buffers before and after existing appointments.
- Prevents overlapping commitments and explains transparently if a deadline cannot fit today.
- 1-tap confirmation to sync approved time blocks directly into Apple Calendar.

### APPLE INTELLIGENCE & SIRI SHORTCUTS
- "Hey Siri, capture in Mate" — instant hands-free thought capture.
- "Hey Siri, plan my day with Mate" — automatic schedule optimization in seconds.
- Interactive Home Screen and Lock Screen widgets for quick completion and countdown glance.

### 100% PRIVATE & ON-DEVICE
- Zero Third-Party Telemetry: No tracking, no ads, no external servers.
- No External AI API Subscriptions: All calculations happen locally on your device Neural Engine.
- Private iCloud Sync: Multi-device sync uses Apple's end-to-end encrypted private CloudKit container. We never see your data.

---

### SUBSCRIPTION TERMS (MATE PRO)
Mate offers an optional auto-renewing subscription tier ("Mate Pro") for advanced smart scheduling and Siri shortcuts:
- Monthly Plan: $1.99 / month
- Annual Plan: $9.99 / year (Includes 7-day free trial; save 58%)

Payment will be charged to your Apple ID upon purchase or trial expiration. Subscriptions automatically renew unless canceled at least 24 hours prior to the end of the current billing cycle in your Apple ID Account Settings.

Privacy Policy: https://ngoctran.github.io/Mate/
Terms of Service: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

---

## 4. App Privacy Nutrition Label Declarations (App Store Connect)

When completing the **App Privacy** questionnaire in App Store Connect, select:
1. **Data Collection**: Select **"No, we do not collect data from this app"**.
2. **Tracking**: Select **"No, we do not track users"**.
3. **Privacy Manifest**: Included in app bundle (`PrivacyInfo.xcprivacy` with `NSPrivacyTracking = false`).

---

## 5. In-App Purchase Setup in App Store Connect

Under **Monetization &gt; Subscriptions**:
1. Create Subscription Group: `Mate Pro Subscriptions`
2. Product 1 (Monthly):
   - Reference Name: `Mate Pro Monthly`
   - Product ID: `com.mate.app.subscription.monthly`
   - Price Tier: `$1.99 / month`
3. Product 2 (Annual):
   - Reference Name: `Mate Pro Annual`
   - Product ID: `com.mate.app.subscription.yearly`
   - Price Tier: `$9.99 / year`
   - Introductory Offer: `7 Days Free Trial`

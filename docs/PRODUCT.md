# Product Specification: Mate

## 1. Product Vision & Positioning
**Mate** is an intelligent personal productivity assistant for Apple ecosystem users.

### The Problem
- Traditional to-do apps (Todoist, Things 3, OmniFocus) require manual time blocking, date picking, and constant schedule reorganizing.
- Siri and Apple Reminders capture items as isolated notes or alarms without context, duration estimation, or calendar conflict awareness.
- Generative AI chatbots (ChatGPT, Claude) can propose plans in markdown text, but cannot directly inspect live calendar events, enforce local privacy, or synchronize changes to system calendars.

### The Solution: Mate Orchestration Layer
```
[User Input: Voice / Siri / Text / Share Sheet]
                      │
                      ▼
        [Mate Universal Capture]
                      │
                      ▼
       [Deterministic NLP & Entity Parser]
                      │
                      ▼
    [Smart Scheduling Engine + Calendar State]
  (Evaluates Working Hours, Buffers & Conflicts)
                      │
                      ▼
[User-Approved Plan & Time Blocks -> EventKit Sync]
```

---

## 2. Target Persona & User Stories

### Target Users
1. **Busy Professionals**: Juggling 5-10 daily meetings; need automatic micro-slot allocation for focus work.
2. **Students & Academics**: Managing coursework deadlines, assignments, and study sessions around fixed lecture timetables.
3. **Freelancers & Solopreneurs**: Balancing client deliverables across multiple projects without paying \$15-30/mo for bloated SaaS project management tools.

### Key User Stories
- **US-1 (Natural Language Multi-Capture)**: *As a user on the move, I want to dictate or type a rambling sentence containing multiple errands and deadlines, so that Mate cleanly splits them into individual tasks with inferred priority, duration, and target dates without manual forms.*
- **US-2 (Conflict-Free Auto-Scheduling)**: *As a user with a crowded calendar, I want Mate to schedule my priority tasks into free gaps during my working hours, respecting meeting buffer times and never double-booking.*
- **US-3 (Transparency & Explanation)**: *As a user whose deadline cannot be met, I want Mate to clearly state why a task cannot fit today so I can consciously renegotiate priorities.*
- **US-4 (Siri & Widget Actionability)**: *As an iPhone user, I want to see my next commitment and complete tasks directly from Home Screen and Lock Screen widgets without launching the app.*

---

## 3. Core Functional Modules

### 3.1 Universal Capture
- Natural language text parsing (on-device via regex, tokenization, and `NaturalLanguage` tagger).
- Inferred fields: Title, Category, Deadline, Estimated Duration, Priority, Recurrence.
- Ambiguity quarantine: tasks lacking clear parameters are routed to the Inbox for 1-tap confirmation.

### 3.2 Smart Scheduling Engine
- Deterministic constraint satisfaction solver.
- Input: Unscheduled tasks, existing EventKit calendar blocks, UserPreference.
- Rules:
  1. Respect `workStartHour` and `workEndHour`.
  2. Enforce `meetingBufferMinutes` before and after all fixed commitments.
  3. Sort tasks: Urgent priority > Earliest deadline > Shortest duration.
  4. Never overwrite or move locked blocks (`isLocked == true`).
  5. Generate human-readable failure explanations for unschedulable tasks.

### 3.3 EventKit Synchronization Bridge
- Reads authorized calendars.
- Writes scheduled time blocks as native events or reminders only after explicit user confirmation.
- Stores external identifier links (`externalCalendarEventId`, `externalReminderId`) for bidirectional sync and rollback.

### 3.4 Personal Memory & Preferences
- Explicit user configuration:
  - Working hours (start/end).
  - Meeting buffers (e.g. 10 or 15 minutes).
  - Default task duration (e.g. 30 minutes).
  - Protected focus blocks (e.g. 10:00 - 12:00).
  - Protected weekends toggle.
- 100% user-editable, inspectable, and resettable at any time.

---

## 4. Monetization Model Analysis

The user specified: **"with no lifetime subsciption, and make sure it's ready to be deployed on App Store"**.

### Commercial Evaluation:
1. **Model A: Standard Auto-Renewing Subscription (No Lifetime Option)**
   - Monthly: \$1.99 / month
   - Annual: \$9.99 / year
   - Provides recurring cashflow to support ongoing Apple OS updates and maintenance without external server costs.
2. **Model B: Pure Pay-Once Non-Consumable Purchase (No Subscription at all)**
   - Introductory: \$1.99 one-time unlock
   - Standard: \$4.99 one-time unlock
   - Appeals strongly to Apple users who resent recurring subscriptions for utility apps.
3. **Model C: Freemium with In-App Purchase Tier**
   - Free core: Basic capture, task management, basic calendar view.
   - Pro tier: Smart auto-scheduling, multi-task parsing, custom buffer rules, widget interactivity.

*Architectural Decision*: The `StoreKitManager` module is implemented to verify entitlements dynamically against Apple's StoreKit 2 `Transaction.currentEntitlements`. It supports both non-consumable and auto-renewable configurations interchangeably via App Store Connect product identifiers.

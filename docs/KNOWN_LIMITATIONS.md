# Known Technical Limitations & Boundaries

## 1. Apple Intelligence & Foundation Models
- **No Third-Party Freeform Text Generation API**: Apple's on-device Foundation Model (3B) is not accessible to third-party developers as an arbitrary prompt API (e.g. `generateText`). Integration is strictly constrained to **AppIntents**, **Writing Tools**, and **Image Playground**.
- **Hardware Exclusivity**: Apple Intelligence requires an iPhone 15 Pro, iPhone 16 series, or an Apple Silicon Mac/iPad. Mate's deterministic architecture ensures all core features function seamlessly on older iPhones (iPhone 11 through 15) without degradation.

---

## 2. EventKit & System Calendars
- **Read/Write Permissions**: If the user denies Calendar or Reminders permission, Mate cannot inspect existing meetings. The app must gracefully degrade by offering an in-app schedule that does not sync to native calendars.
- **External Event Ownership**: Events created in Exchange, Google Calendar, or shared iCloud calendars cannot be moved or deleted by Mate without explicit user interaction and permission.

---

## 3. Background Execution Limits
- **iOS Sandbox Restrictions**: iOS does not permit continuous background processing or persistent background polling. Widgets and Live Activities update on system budgets. All scheduling actions must be fast (< 50ms) and initiated by user actions, App Intents, or system background refresh triggers.

---

## 4. iCloud Synchronization
- **Offline & Conflict Merging**: When multiple devices modify the same task offline, Mate applies a deterministic last-write-wins policy based on the `updatedAt` ISO8601 timestamp.

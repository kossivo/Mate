# Apple API Feasibility Matrix & Technical Audit

## Executive Evaluation Status: **CONDITIONAL GO**

This matrix evaluates official Apple APIs against Mate's product requirements, verifying compatibility with iOS 18+, macOS 15+, and App Store Review Guidelines.

---

## Official Apple API Capability Matrix

| Capability / API | Framework | Status | Min OS | Limitations & Notes | App Store Guideline Compliance |
|---|---|---|---|---|---|
| **App Intents & Siri Shortcuts** | `AppIntents` | **Production-Ready** | iOS 16.0+, iOS 18+ for Siri Intelligence | Siri actions must be fast (< 2s). Background execution is time-limited. Cannot do conversational freeform chat without user prompting. | 100% compliant. Required for Siri & Shortcuts integration. |
| **App Entities & Indexing** | `AppIntents`, `CoreSpotlight` | **Production-Ready** | iOS 17.0+ | Entities must be uniquely identifiable (`UUID`). Siri indexes entities for on-screen context. | 100% compliant. |
| **Calendar Access** | `EventKit` | **Production-Ready** | iOS 4.0+, iOS 17+ privacy changes | Requires explicit `NSCalendarsFullAccessUsageDescription` or write-only permission. Cannot read without user consent. | 100% compliant. Guidelines 5.1.1. |
| **Reminders Access** | `EventKit` | **Production-Ready** | iOS 4.0+, iOS 17+ | Requires `NSRemindersFullAccessUsageDescription`. | 100% compliant. |
| **Interactive Widgets** | `WidgetKit`, `AppIntents` | **Production-Ready** | iOS 17.0+ | Small, Medium, Large, Lock Screen widgets. Cannot run arbitrary heavy AI inference inside widget extension. Timeline reloads throttled by OS. | 100% compliant. |
| **Live Activities & Dynamic Island** | `ActivityKit` | **Production-Ready** | iOS 16.1+ | Strictly for active, ongoing sessions (e.g. Focus Timer). Apple rejects apps using Live Activities as permanent dashboards. | 100% compliant. |
| **Local Persistence** | `SwiftData` / `CoreData` | **Production-Ready** | iOS 17.0+ | SwiftData is modern and native. Schema migrations must be versioned to prevent data loss. | 100% compliant. |
| **Cloud Synchronization** | `CloudKit` (Private DB) | **Production-Ready** | iOS 8.0+ | Zero server cost. Data stored strictly in user's personal iCloud quota. Fails if user disabled iCloud. | 100% compliant. Private by design. |
| **Natural Language Parsing** | `NaturalLanguage` | **Production-Ready** | iOS 12.0+ | 100% on-device, zero latency, multi-language tokenization and tagger. | 100% compliant. |
| **Foundation Models / Arbitrary LLM API** | N/A (3rd party) | **Unsupported directly as arbitrary API** | iOS 18.0+ | Apple does **NOT** expose an open `AppleIntelligence.generateText(prompt)` API for 3rd party apps in iOS 18. Apple Intelligence integrates via AppIntents, Writing Tools, and Image Playground. | Using private headers would cause immediate App Store rejection. Must use deterministic NLP + AppIntents. |
| **In-App Purchases & Subscriptions** | `StoreKit 2` | **Production-Ready** | iOS 15.0+ | Modern async/await API. Cryptographically verified transactions on-device via JWS. | 100% compliant with Guidelines 3.1.1 / 3.1.2. |
| **Privacy Manifest** | `PrivacyInfo.xcprivacy` | **Mandatory** | iOS 17.0+ | Mandatory for App Store submission since May 2024. Must declare all required reason APIs (`UserDefaults`, `FileTimestamp`, etc.). | Mandatory for submission. |

---

## Critical Feasibility Findings

1. **Apple Intelligence Integration Reality**:
   - *Myth*: Third-party apps can call Apple's 3B Foundation Model directly to generate freeform text answers.
   - *Fact*: Apple exposes Apple Intelligence to apps strictly through **AppIntents**, **App Shortcuts**, system **Writing Tools**, and **CoreSpotlight semantic indexing**.
   - *Architectural Decision*: Mate builds a deterministic Natural Language parser (`DeterministicCaptureParser`) within the app for instant, battery-efficient offline capture, while exposing rich `@AssistantIntent` actions and `AppEntity` records so Siri and Apple Intelligence can discover, query, and trigger Mate actions natively.

2. **EventKit Approval Model**:
   - External calendar entries are owned by the user or their organization (Exchange, Google, iCloud).
   - Mate will **never** silently overwrite or delete calendar events. All scheduling proposals are previewed and require user approval before writing to EventKit.

3. **Background Execution Limits**:
   - `BackgroundTasks` framework gives unpredictable windows of execution (often 10-30 seconds once or twice daily depending on device battery and charging state).
   - Mate's scheduling engine is designed to execute in < 25 milliseconds, guaranteeing completion well within any background refresh window.

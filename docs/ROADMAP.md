# Product Roadmap & Implementation Phases

## Phase 0: Feasibility & Foundation (Current Milestone — COMPLETED)
- [x] Environment audit (Xcode 16.3, Swift 6.2, macOS 15.8 Sequoia).
- [x] Multidisciplinary agent roster & protocol definition (`AGENTS.md`).
- [x] Official Apple API capability matrix & reality check (`docs/FEASIBILITY.md`).
- [x] Deterministic core domain models (`TaskItem`, `TimeBlock`, `UserPreference`).
- [x] Deterministic capture parser for complex multi-sentence inputs.
- [x] Smart scheduling engine with conflict detection and meeting buffer calculation.
- [x] Automated test suite with 100% pass rate.
- [x] Architectural & Commercial Decision Records (`docs/DECISIONS.md`).
- [x] Formal **GO / NO-GO** recommendation.

---

## Phase 1A: Swift Project & Persistence Architecture (Target: 1-2 Weeks)
- [ ] Initialize Xcode Project targets (`Mate.xcodeproj`) with SwiftData container.
- [ ] Implement local database storage and migration schema.
- [ ] Add `EventKit` integration layer for reading authorized Apple Calendars and Reminders.
- [ ] Build end-to-end unit and integration tests for database persistence.

---

## Phase 1B: Apple Intelligence & Siri AppIntents (Target: 1-2 Weeks)
- [ ] Create `CaptureThoughtIntent` with natural language parameters.
- [ ] Create `PlanMyDayIntent` triggering `SmartSchedulingEngine`.
- [ ] Define `AppEntity` types for Spotlight search and Siri semantic indexing.
- [ ] Implement system `WritingTools` support on text capture inputs.

---

## Phase 1C: iOS User Experience & Widgets (Target: 2 Weeks)
- [ ] Build minimalist SwiftUI dashboard:
  - Today view (timeline, next commitment, top priorities).
  - Quick natural language capture input bar.
  - Plan review sheet with 1-tap accept/renegotiate.
  - Settings & Personal Preferences view.
- [ ] Build `WidgetKit` extensions (Small, Medium, Large, Lock Screen).
- [ ] Implement iOS Share Sheet extension for capturing text from Safari, Mail, Notes.

---

## Phase 1D: StoreKit 2 & App Store Readiness (Target: 1 Week)
- [ ] Implement final StoreKit 2 paywall & transaction verification.
- [ ] Add Apple Privacy Manifest (`PrivacyInfo.xcprivacy`).
- [ ] Add English and Vietnamese localization bundles.
- [ ] TestFlight internal build deployment & App Store submission preparation.

---

## Phase 2: macOS Companion & Ecosystem Expansion (Target: Post-Launch)
- [ ] Lightweight macOS MenuBarExtra app using shared `MateCore`.
- [ ] Global keyboard shortcut for quick capture (`Cmd + Shift + M`).
- [ ] Live Activities & Dynamic Island for active focus sessions.

---

## Phase 3: Advanced Productivity & Apple Watch (Future Vision)
- [ ] Goal & project milestone hierarchy.
- [ ] Apple Watch standalone companion for quick voice capture and next commitment glance.
- [ ] On-device weekly productivity review summaries.

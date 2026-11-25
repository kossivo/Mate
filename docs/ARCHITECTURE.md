# System Architecture & Technical Design

## 1. Architectural Principles
1. **Local-First & Offline Resilience**: The application is fully functional without network connectivity. Data persistence is local-first using SwiftData/CoreData, with optional private iCloud synchronization via CloudKit.
2. **Deterministic Domain Core**: Scheduling arithmetic, conflict detection, buffer calculations, and deadline evaluations are strictly deterministic algorithms.
3. **Modular Swift Package Structure**: Core logic is isolated in `MateCore`, cleanly decoupled from platform UI (SwiftUI), widget extensions (`WidgetKit`), and App Intents (`AppIntents`).
4. **Zero External Dependencies**: No CocoaPods, no bulky third-party SDKs, no external backend servers (no Firebase, Supabase, or AWS). Uses 100% native Apple frameworks.

---

## 2. High-Level System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                          PRESENTATION LAYER                            │
│  ┌────────────────────┐  ┌──────────────────┐  ┌────────────────────┐  │
│  │   iOS SwiftUI App  │  │ macOS MenuBarApp │  │ WidgetKit Extension│  │
│  └─────────┬──────────┘  └────────┬─────────┘  └─────────┬──────────┘  │
│            │                      │                      │             │
│            └──────────────────────┼──────────────────────┘             │
│                                   │                                    │
│  ┌────────────────────────────────▼─────────────────────────────────┐  │
│  │                    App Intents & Siri Layer                      │  │
│  │    (CaptureThoughtIntent, PlanMyDayIntent, CompleteTaskIntent)   │  │
│  └────────────────────────────────┬─────────────────────────────────┘  │
└───────────────────────────────────┼────────────────────────────────────┘
                                    │
┌───────────────────────────────────▼────────────────────────────────────┐
│                       CORE DOMAIN (MateCore)                           │
│  ┌──────────────────────┐ ┌──────────────────────┐ ┌────────────────┐  │
│  │ Deterministic Parser │ │ Smart Scheduling     │ │ User Preference│  │
│  │ (NaturalLanguage/NLP)│ │ Engine               │ │ Store          │  │
│  └──────────┬───────────┘ └──────────┬───────────┘ └───────┬────────┘  │
│             │                        │                     │           │
│             └────────────────────────┼─────────────────────┘           │
│                                      │                                 │
│  ┌───────────────────────────────────▼──────────────────────────────┐  │
│  │                   Domain Models & Enums                          │  │
│  │   (TaskItem, TimeBlock, SchedulingProposal, UserPreference)      │  │
│  └───────────────────────────────────┬──────────────────────────────┘  │
└──────────────────────────────────────┼─────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼─────────────────────────────────┐
│                    PERSISTENCE & INTEGRATION LAYER                     │
│  ┌──────────────────┐ ┌────────────────────┐ ┌───────────────────────┐  │
│  │ SwiftData Storage│ │ EventKit Bridge    │ │ StoreKit 2 Manager    │  │
│  │ (Private CloudKit│ │ (Calendar/Reminders│ │ (Entitlements / JWS) │  │
│  │  Sync Container) │ │  Sync & Locks)     │ │                       │  │
│  └──────────────────┘ └────────────────────┘ └───────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Module Responsibilities

### `MateCore` (Swift Package)
- **`Domain/`**: Pure Swift data structures (`TaskItem`, `TimeBlock`, `UserPreference`, `SchedulingProposal`). Conforms to `Sendable`, `Identifiable`, `Codable`, `Equatable`.
- **`Parser/`**: `DeterministicCaptureParser` splits compound sentences, identifies deadlines, durations, priority, and flags ambiguity.
- **`Scheduler/`**: `SmartSchedulingEngine` computes time slots, respects buffer times, prevents overlapping appointments, and outputs transparent failure diagnostics.
- **`StoreKit/`**: `StoreKitManager` handles entitlement verification, receipt validation, and purchase restoration.

### Presentation & System Extensions (Planned for Phase 1)
- **`MateApp` (iOS)**: Modern SwiftUI navigation (Today, Inbox, Plan, Settings).
- **`MateWidgets`**: Small, Medium, Large, and Lock Screen widgets.
- **`MateIntents`**: Siri App Shortcuts exposing Capture, Plan, and Query actions.
- **`MateMac`**: Lightweight MenuBarExtra for macOS.

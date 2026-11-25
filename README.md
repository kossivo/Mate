# Mate — Apple Intelligence Personal Productivity Assistant

> **Tagline**: The intelligent, privacy-first productivity orchestration layer for Apple devices.

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS%2018%2B%20%7C%20macOS%2015%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Proprietary-lightgrey.svg)]()

---

## Executive Summary

**Mate** is an Apple-native personal productivity assistant designed to turn unstructured thoughts into scheduled reality. Unlike conventional to-do list apps or standalone AI chat bots, Mate acts as a local orchestration layer connecting Apple Intelligence, Siri, EventKit (Apple Calendar and Reminders), and native system widgets with persistent user preferences and deterministic scheduling math.

### Key Highlights
- **100% Local-First & Privacy-Focused**: No external servers, no tracking, zero third-party AI API subscriptions. All schedule calculations and data remain on-device or within the user's private iCloud container.
- **Universal Capture**: Captures complex multi-task natural language (e.g., *"I need to finish my presentation by Friday, call Mum tonight and exercise three times this week"*) and decomposes it into actionable tasks with inferred deadlines, durations, and recurrence rules.
- **Deterministic Scheduling Engine**: Automatically allocates time blocks within user working hours, calculates meeting buffers, detects conflicts with existing Apple Calendar appointments, and explains why any task could not be scheduled.
- **Apple Intelligence & App Intents Integration**: Deeply integrates with Siri App Shortcuts, App Entities, and Interactive Widgets using iOS 18+ AppIntents.
- **StoreKit 2 Ready**: Transparent monetization with zero lifetime subscription gimmicks, fully compliant with Apple App Store Review Guidelines.

---

## Project Structure

```
Mate/
├── Package.swift                     # Core Swift Package definition
├── Sources/
│   └── MateCore/                     # Shared cross-platform domain logic
│       ├── Domain/                   # TaskItem, TimeBlock, UserPreference, SchedulingProposal
│       ├── Parser/                   # Deterministic & NL capture parsing engine
│       ├── Scheduler/                # Deterministic calendar math & conflict resolution
│       ├── StoreKit/                 # StoreKit 2 subscription & purchase verification
│       └── MateVersion.swift
├── Tests/
│   └── MateCoreTests/                # Automated Swift Testing test suite
│       ├── CaptureParserTests.swift  # Multi-task sentence parsing tests
│       ├── SchedulingEngineTests.swift # Buffer, conflict & working hours tests
│       ├── DataModelTests.swift      # JSON & SwiftData serialization tests
│       └── MateVersionTests.swift
├── docs/                             # Engineering & product documentation
│   ├── PRODUCT.md                    # Product specification & PRD
│   ├── FEASIBILITY.md                # Official Apple API capability matrix
│   ├── ARCHITECTURE.md               # Clean architecture & modular design
│   ├── DATA_MODEL.md                 # Entity schema & state transitions
│   ├── PRIVACY.md                    # Privacy manifest & security audit
│   ├── TEST_PLAN.md                  # Comprehensive test matrix & verification
│   ├── ROADMAP.md                    # Phase 0 to Phase 3 milestone roadmap
│   ├── DECISIONS.md                  # Architecture & Commercial Decision Records
│   ├── KNOWN_LIMITATIONS.md          # Technical boundaries & OS constraints
│   └── HANDOVER.md                   # Developer & reviewer handover guide
└── AGENTS.md                         # Autonomous agent team roster & protocols
```

---

## Verification & Testing

To execute the test suite across all modules:
```bash
swift test
```
All tests use Apple's modern Swift Testing framework (`import Testing`) with strict concurrency checking.

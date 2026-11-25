# Developer & Reviewer Handover Guide

## Welcome to Mate
This guide provides developers, testers, and product reviewers with the instructions needed to build, inspect, test, and contribute to **Mate**.

---

## Quickstart Guide

### Prerequisites
- macOS 15.0+ (Sequoia)
- Xcode 16.0+ (Tested on Xcode 16.3 / Swift 6.2)
- Git

### Build & Run Tests
```bash
# Clone or navigate to the repository
cd /Users/ngoctran/Downloads/Mate

# Execute the automated test suite
swift test
```

Expected output:
```
Build complete!
Test run with 8 tests in 3 suites passed after 0.011 seconds.
```

---

## Directory Navigation

- **Domain Models**: [`Sources/MateCore/Domain/Models.swift`](file:///Users/ngoctran/Downloads/Mate/Sources/MateCore/Domain/Models.swift)
- **Universal Capture Parser**: [`Sources/MateCore/Parser/DeterministicCaptureParser.swift`](file:///Users/ngoctran/Downloads/Mate/Sources/MateCore/Parser/DeterministicCaptureParser.swift)
- **Smart Scheduling Engine**: [`Sources/MateCore/Scheduler/SmartSchedulingEngine.swift`](file:///Users/ngoctran/Downloads/Mate/Sources/MateCore/Scheduler/SmartSchedulingEngine.swift)
- **StoreKit 2 Entitlements**: [`Sources/MateCore/StoreKit/StoreKitManager.swift`](file:///Users/ngoctran/Downloads/Mate/Sources/MateCore/StoreKit/StoreKitManager.swift)
- **Test Suite**: [`Tests/MateCoreTests/`](file:///Users/ngoctran/Downloads/Mate/Tests/MateCoreTests/)
- **Product Docs**: [`docs/`](file:///Users/ngoctran/Downloads/Mate/docs/)

---

## Phase 0 Sign-Off & Next Actions
1. Product Owner reviews the Executive Feasibility Assessment and Phase 0 deliverables.
2. Product Owner clarifies the exact monetization preference (Standard Auto-Renewable Subscription vs. One-Time Purchase).
3. Upon approval, proceed to **Phase 1A** (Xcode Project generation, SwiftData persistence, and EventKit integration).

# Mate (formerly Pally) — Multidisciplinary Development Team & Agent Charter

## Overview
This document defines the roles, operating rules, interaction protocols, and decision boundaries for the autonomous multidisciplinary product team building **Mate**: a privacy-first personal productivity assistant for the Apple ecosystem.

---

## Agent Roster & Ownership Boundaries

| Role | Responsibility | Authority Boundary | Primary Deliverables |
|---|---|---|---|
| **Product Manager (PM)** | Overall scope, feature prioritization, business alignment, release readiness. | Owns roadmap, PRDs, scope trade-offs, and final release sign-off. | `README.md`, `docs/PRODUCT.md`, `docs/ROADMAP.md` |
| **Apple Ecosystem Research Agent** | SDK capabilities, Apple Intelligence / Siri AppIntents feasibility, OS limitations. | Validates official Apple APIs; flags private/undocumented API risks. | `docs/FEASIBILITY.md` |
| **Senior Swift & iOS Architect** | System architecture, Swift package modularity, concurrency safety, data persistence. | Owns type designs, module contracts, SwiftData / CloudKit schema migrations. | `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `Sources/MateCore` |
| **macOS Engineer** | macOS companion, MenuBarExtra, global shortcuts, cross-platform UI adaptation. | Mac-specific integration and platform parity. | Mac MenuBar, macOS target configuration |
| **AI Engineer** | Natural language capture parsing, deterministic entity extraction, AppIntents semantic schemas. | Distinguishes LLM interpretation from deterministic business logic. | `DeterministicCaptureParser.swift`, AppIntents definitions |
| **UI/UX Designer** | Apple Human Interface Guidelines (HIG), design tokens, typography, accessibility, minimal UI. | Information hierarchy, VoiceOver, Dynamic Type, Dark Mode. | SwiftUI views, design token specs |
| **Security & Privacy Engineer** | On-device data boundaries, Apple Privacy Manifests (`PrivacyInfo.xcprivacy`), sandboxing. | Approves permission prompts, iCloud sync encryption, zero-telemetry guarantee. | `docs/PRIVACY.md`, `PrivacyInfo.xcprivacy` |
| **QA Engineer** | Test harness, unit tests, edge-case validation, regression prevention. | Can veto any PR/milestone if automated tests fail or evidence is lacking. | `docs/TEST_PLAN.md`, `Tests/MateCoreTests` |
| **DevOps & Release Engineer** | Xcode project structure, code signing, TestFlight pipelines, App Store submission bundle. | App Store Review Guideline compliance, build automation. | CI/CD config, StoreKit configuration |
| **Commercial Strategy Analyst** | Monetization modeling, StoreKit 2 in-app purchases / subscriptions, unit economics. | Financial assumptions, pricing strategy, customer acquisition economics. | `docs/DECISIONS.md`, StoreKit pricing models |

---

## Collaboration Protocol & Invariants

1. **Deterministic Logic Over Probalistic Models**: AI is strictly used for text interpretation; all calendar math, time-zone handling, conflict detection, and StoreKit entitlements are 100% deterministic Swift code.
2. **Privacy First**: Zero third-party telemetry, zero external AI APIs without explicit user approval, local-first storage with optional private iCloud sync.
3. **App Store Compliance**: Strict adherence to App Store Review Guidelines (3.1.1, 3.1.2, 5.1.1, 5.1.2). No private APIs.
4. **Verification Before Assertion**: No claim of feature completion is accepted without automated test execution and logs.

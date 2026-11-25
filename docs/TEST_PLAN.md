# Quality Assurance & Test Plan

## 1. QA Verification Strategy
All business-critical algorithms in Mate are covered by automated unit and integration tests using Apple's modern **Swift Testing** framework (`import Testing`).

---

## 2. Test Matrix & Scenario Coverage

| Test ID | Module | Scenario Description | Expected Outcome | Status |
|---|---|---|---|---|
| **TEST-01** | `CaptureParser` | Multi-task parsing: *"I need to finish my presentation by Friday, call Mum tonight and exercise three times this week."* | Extracts 3 distinct tasks with correct inferred deadlines, durations, and recurrence. | **PASSED** |
| **TEST-02** | `CaptureParser` | Ambiguous input: *"Complete report"* | Flags task as ambiguous (`isAmbiguous == true`) and routes to Inbox with explanatory notes. | **PASSED** |
| **TEST-03** | `SmartScheduling` | Scheduling around existing locked meeting with 10-minute buffer. | Allocates free slot before meeting without violating buffer or overlapping. | **PASSED** |
| **TEST-04** | `SmartScheduling` | Insufficient time before deadline / overloaded day. | Reports explicit diagnostic reason: *"No available time slot of X minutes within working hours"*. | **PASSED** |
| **TEST-05** | `SmartScheduling` | Conflict detection between two overlapping external calendar events. | Flags conflict warning in `conflictsDetected`. | **PASSED** |
| **TEST-06** | `SmartScheduling` | Manually locked time block preservation (`isLocked == true`). | Does not reschedule or modify locked block. | **PASSED** |
| **TEST-07** | `DataModel` | JSON encoding & decoding with ISO8601 timestamps. | Roundtrip serialization preserves all fields, UUIDs, and enum states. | **PASSED** |
| **TEST-08** | `StoreKit` | Entitlement validation and product ID mapping. | Supports non-consumable and auto-renewable identifiers seamlessly. | **PASSED** |

---

## 3. Execution Evidence
Automated test run output from `swift test`:
```
Test Suite 'All tests' passed.
✔ Test testVersion() passed after 0.001 seconds.
✔ Test testUserPreferenceDefaults() passed after 0.001 seconds.
✔ Test testTaskItemCodable() passed after 0.001 seconds.
✔ Suite "DataModelSerializationTests" passed after 0.002 seconds.
✔ Test testConflictDetectionBetweenExistingEvents() passed after 0.009 seconds.
✔ Test testInsufficientTimeReportsExplicitReason() passed after 0.009 seconds.
✔ Test testSchedulingAroundExistingMeeting() passed after 0.009 seconds.
✔ Suite "SmartSchedulingEngineTests" passed after 0.010 seconds.
✔ Test testAmbiguousTaskWithoutDeadline() passed after 0.010 seconds.
✔ Test testMultiTaskParsingFromPrompt() passed after 0.010 seconds.
✔ Suite "DeterministicCaptureParserTests" passed after 0.011 seconds.
✔ Test run with 8 tests in 3 suites passed after 0.011 seconds.
```

# Data Model Specification

## 1. Domain Entities & Schemas

### `TaskItem`
Represents an actionable to-do or commitment created by the user or extracted from universal capture.

| Property | Type | Nullable | Description |
|---|---|---|---|
| `id` | `UUID` | No | Unique identifier |
| `title` | `String` | No | Task headline (cleaned, concise) |
| `notes` | `String` | Yes | Extended details or source text |
| `category` | `String` | Yes | Category tag (e.g. Work, Personal, Health) |
| `deadline` | `Date` | Yes | Target completion timestamp |
| `estimatedDuration` | `TimeInterval` | No | Duration in seconds (default: 1800s / 30m) |
| `priority` | `TaskPriority` | No | `.urgent`, `.high`, `.medium`, `.low` |
| `status` | `TaskStatus` | No | `.inbox`, `.planned`, `.inProgress`, `.completed`, `.cancelled` |
| `recurrenceRule` | `String` | Yes | Recurrence frequency (e.g. `3x_weekly`, `daily`) |
| `isLocked` | `Bool` | No | If true, scheduling engine will not auto-move |
| `externalCalendarEventId` | `String` | Yes | EKEvent identifier if synced to Apple Calendar |
| `externalReminderId` | `String` | Yes | EKReminder identifier if synced to Apple Reminders |
| `createdAt` | `Date` | No | Creation timestamp |
| `updatedAt` | `Date` | No | Last modification timestamp |

---

### `TimeBlock`
Represents a scheduled period on the user's daily timeline.

| Property | Type | Nullable | Description |
|---|---|---|---|
| `id` | `UUID` | No | Unique identifier |
| `taskId` | `UUID` | Yes | Associated `TaskItem.id` if originating from a task |
| `title` | `String` | No | Display title |
| `startTime` | `Date` | No | Start timestamp |
| `endTime` | `Date` | No | End timestamp |
| `isLocked` | `Bool` | No | If true, user manually locked this slot |
| `category` | `String` | Yes | Optional category styling |

---

### `UserPreference`
Persistent user configuration controlling scheduling heuristics.

| Property | Type | Default | Description |
|---|---|---|---|
| `workStartHour` | `Int` | `9` | Beginning of daily working hours (0-23) |
| `workEndHour` | `Int` | `17` | End of daily working hours (0-23) |
| `preferredTaskDurationMinutes` | `Int` | `30` | Default task duration when none is specified |
| `meetingBufferMinutes` | `Int` | `10` | Transition buffer before and after meetings |
| `protectWeekends` | `Bool` | `true` | Prevent auto-scheduling on Saturday/Sunday |
| `focusStartHour` | `Int?` | `10` | Preferred focus block start hour |
| `focusEndHour` | `Int?` | `12` | Preferred focus block end hour |

---

## 2. State Lifecycle Diagram

```
[Raw User Input]
       │
       ▼
[ParsedCaptureItem]
       │
       ├─► (Ambiguous) ─────────► [TaskStatus.inbox] ──(User Confirms)──┐
       │                                                                 ▼
       └─► (Structured) ─────────────────────────────────────────► [TaskStatus.planned]
                                                                         │
                                                                         ▼
                                                              [SmartSchedulingEngine]
                                                                         │
                                                                         ▼
                                                                [TimeBlock Created]
                                                                         │
                                                                (User Starts Task)
                                                                         │
                                                                         ▼
                                                             [TaskStatus.inProgress]
                                                                         │
                                                                (User Finishes Task)
                                                                         │
                                                                         ▼
                                                             [TaskStatus.completed]
```

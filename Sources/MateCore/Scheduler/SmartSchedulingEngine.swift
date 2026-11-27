import Foundation

public final class SmartSchedulingEngine: @unchecked Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /// Rounds date up to the next 15-minute boundary (:00, :15, :30, :45)
    public static func roundUpTo15Minutes(_ date: Date, calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let remainder = minute % 15
        if remainder == 0 && second == 0 {
            return date
        }
        let minutesToAdd = 15 - remainder
        var comp = DateComponents()
        comp.minute = minutesToAdd
        comp.second = -second
        return calendar.date(byAdding: comp, to: date) ?? date
    }

    /// Rounds date down to the previous 15-minute boundary (:00, :15, :30, :45)
    public static func roundDownTo15Minutes(_ date: Date, calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let remainder = minute % 15
        var comp = DateComponents()
        comp.minute = -remainder
        comp.second = -second
        return calendar.date(byAdding: comp, to: date) ?? date
    }

    /// Snaps an integer minute (0-59) to the nearest 15-minute increment (0, 15, 30, 45)
    public static func snapMinuteTo15(_ minute: Int) -> Int {
        let remainder = minute % 15
        if remainder < 8 {
            return max(0, minute - remainder)
        } else {
            let next = minute + (15 - remainder)
            return next >= 60 ? 45 : next
        }
    }

    /// Snaps a duration in seconds to multiples of 15 minutes (minimum 15m = 900s)
    public static func snapDurationTo15Minutes(_ duration: TimeInterval) -> TimeInterval {
        let quarterHours = max(1.0, (duration / 900.0).rounded())
        return quarterHours * 900.0
    }

    /// Schedules candidate tasks around existing locked calendar commitments within user-preferred working hours.
    /// All time slots, starts, and ends strictly align to 15-minute boundaries (:00, :15, :30, :45).
    public func schedule(
        tasks: [TaskItem],
        existingCommitments: [TimeBlock],
        preferences: UserPreference,
        targetDate: Date,
        referenceDate: Date? = nil,
        preserveOrder: Bool = false
    ) -> SchedulingProposal {
        var scheduledBlocks: [TimeBlock] = []
        var unscheduled: [UnscheduledTaskReason] = []
        var conflicts: [String] = []

        // 1. Establish the day's schedulable time boundary (e.g. 09:00 - 17:00, aligned to 15m)
        let startMin = Self.snapMinuteTo15(preferences.workStartMinute)
        let endMin = Self.snapMinuteTo15(preferences.workEndMinute)

        guard let rawDayStart = calendar.date(bySettingHour: preferences.workStartHour, minute: startMin, second: 0, of: targetDate),
              let rawDayEnd = calendar.date(bySettingHour: preferences.workEndHour, minute: endMin, second: 0, of: targetDate),
              rawDayStart < rawDayEnd else {
            return SchedulingProposal(
                scheduledBlocks: [],
                unscheduledTasks: tasks.map { UnscheduledTaskReason(taskId: $0.id, taskTitle: $0.title, reason: "Invalid working hours window") },
                conflictsDetected: ["Day start is not before day end"]
            )
        }

        let dayStart = Self.roundDownTo15Minutes(rawDayStart, calendar: calendar)
        let dayEnd = Self.roundDownTo15Minutes(rawDayEnd, calendar: calendar)

        // 2. Extract busy intervals from existing commitments that overlap with targetDate (excluding all-day events / holidays)
        let sortedCommitments = existingCommitments
            .filter { !$0.isAllDay && $0.endTime > dayStart && $0.startTime < dayEnd }
            .sorted { $0.startTime < $1.startTime }

        // Check for internal conflicts within existing commitments
        for i in 0..<sortedCommitments.count {
            for j in (i + 1)..<sortedCommitments.count {
                let first = sortedCommitments[i]
                let second = sortedCommitments[j]
                if first.endTime > second.startTime {
                    conflicts.append("Existing commitment conflict between '\(first.title)' and '\(second.title)'")
                }
            }
        }

        // 3. Calculate available free slots respecting meeting buffers, snapped to 15m grid
        var availableSlots: [(start: Date, end: Date)] = []
        var pointer = dayStart

        // If referenceDate provided (e.g. midday / rescue scheduling), start from next 15-min mark
        if let ref = referenceDate {
            let snappedRef = Self.roundUpTo15Minutes(ref, calendar: calendar)
            if calendar.isDate(ref, inSameDayAs: targetDate) && snappedRef > dayStart {
                pointer = min(snappedRef, dayEnd)
            }
        }

        let bufferSec = Double(Self.snapMinuteTo15(preferences.meetingBufferMinutes) * 60)

        for block in sortedCommitments {
            // Apply buffer before meeting snapped down to 15m
            let bufferedStart = Self.roundDownTo15Minutes(block.startTime.addingTimeInterval(-bufferSec), calendar: calendar)
            if pointer < bufferedStart {
                availableSlots.append((start: pointer, end: bufferedStart))
            }
            // Apply buffer after meeting snapped up to 15m
            let bufferedEnd = Self.roundUpTo15Minutes(block.endTime.addingTimeInterval(bufferSec), calendar: calendar)
            if pointer < bufferedEnd {
                pointer = bufferedEnd
            }
        }

        if pointer < dayEnd {
            availableSlots.append((start: pointer, end: dayEnd))
        }

        // 4. Tasks candidate selection (preserve manual order if requested, else sort by priority -> deadline -> duration)
        let candidateTasks: [TaskItem]
        if preserveOrder {
            candidateTasks = tasks.filter { $0.status != .completed && $0.status != .cancelled }
        } else {
            candidateTasks = tasks
                .filter { $0.status != .completed && $0.status != .cancelled }
                .sorted { (lhs, rhs) -> Bool in
                    if lhs.priority != rhs.priority {
                        return lhs.priority < rhs.priority
                    }
                    if let lhsDeadline = lhs.deadline, let rhsDeadline = rhs.deadline {
                        if lhsDeadline != rhsDeadline {
                            return lhsDeadline < rhsDeadline
                        }
                    } else if lhs.deadline != nil {
                        return true
                    } else if rhs.deadline != nil {
                        return false
                    }
                    return lhs.estimatedDuration < rhs.estimatedDuration
                }
        }

        // 5. Place tasks into available slots (all 15-min aligned)
        var remainingSlots = availableSlots

        for task in candidateTasks {
            var isScheduled = false

            if task.isLocked {
                unscheduled.append(UnscheduledTaskReason(taskId: task.id, taskTitle: task.title, reason: "Task is locked to manual time block"))
                continue
            }

            let taskDuration = Self.snapDurationTo15Minutes(task.estimatedDuration)

            for slotIndex in 0..<remainingSlots.count {
                let slot = remainingSlots[slotIndex]
                let slotDuration = slot.end.timeIntervalSince(slot.start)

                if slotDuration >= taskDuration {
                    let taskStart = Self.roundUpTo15Minutes(slot.start, calendar: calendar)
                    let taskEnd = taskStart.addingTimeInterval(taskDuration)

                    if taskEnd > slot.end {
                        continue
                    }

                    // Verify deadline is respected if set
                    if let deadline = task.deadline, taskEnd > deadline {
                        unscheduled.append(UnscheduledTaskReason(
                            taskId: task.id,
                            taskTitle: task.title,
                            reason: "Insufficient time before task deadline (\(deadline.formatted()))"
                        ))
                        isScheduled = true
                        break
                    }

                    // Create scheduled TimeBlock (guaranteed 15m boundaries)
                    let block = TimeBlock(
                        taskId: task.id,
                        title: task.title,
                        startTime: taskStart,
                        endTime: taskEnd,
                        isLocked: false,
                        category: task.category
                    )
                    scheduledBlocks.append(block)

                    // Update remaining slot
                    if taskEnd < slot.end {
                        remainingSlots[slotIndex] = (start: taskEnd, end: slot.end)
                    } else {
                        remainingSlots.remove(at: slotIndex)
                    }

                    isScheduled = true
                    break
                }
            }

            if !isScheduled {
                let startStr = String(format: "%02d:%02d", preferences.workStartHour, startMin)
                let endStr = String(format: "%02d:%02d", preferences.workEndHour, endMin)
                unscheduled.append(UnscheduledTaskReason(
                    taskId: task.id,
                    taskTitle: task.title,
                    reason: "No available time slot of \(Int(taskDuration / 60)) minutes within working hours (\(startStr)-\(endStr))"
                ))
            }
        }

        return SchedulingProposal(
            scheduledBlocks: scheduledBlocks,
            unscheduledTasks: unscheduled,
            conflictsDetected: conflicts
        )
    }

    /// Reallocates and reorders tasks strictly by priority (urgent -> high -> medium -> low),
    /// matching high priorities to prime focus hours first and returning the updated task list and scheduled time blocks.
    public func reallocateTasksByPriority(
        tasks: [TaskItem],
        existingCommitments: [TimeBlock],
        preferences: UserPreference = UserPreference(),
        targetDate: Date = Date(),
        referenceDate: Date? = nil
    ) -> (reallocatedTasks: [TaskItem], proposal: SchedulingProposal) {
        let sortedTasks = tasks.sorted { (lhs, rhs) -> Bool in
            if lhs.status == .completed && rhs.status != .completed { return false }
            if lhs.status != .completed && rhs.status == .completed { return true }
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            if let lhsDeadline = lhs.deadline, let rhsDeadline = rhs.deadline {
                if lhsDeadline != rhsDeadline {
                    return lhsDeadline < rhsDeadline
                }
            } else if lhs.deadline != nil {
                return true
            } else if rhs.deadline != nil {
                return false
            }
            return lhs.estimatedDuration < rhs.estimatedDuration
        }

        let proposal = schedule(
            tasks: sortedTasks,
            existingCommitments: existingCommitments,
            preferences: preferences,
            targetDate: targetDate,
            referenceDate: referenceDate,
            preserveOrder: false
        )

        return (reallocatedTasks: sortedTasks, proposal: proposal)
    }
}

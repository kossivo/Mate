import Foundation

public final class SmartSchedulingEngine: @unchecked Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /// Schedules candidate tasks around existing locked calendar commitments within user-preferred working hours.
    public func schedule(
        tasks: [TaskItem],
        existingCommitments: [TimeBlock],
        preferences: UserPreference,
        targetDate: Date
    ) -> SchedulingProposal {
        var scheduledBlocks: [TimeBlock] = []
        var unscheduled: [UnscheduledTaskReason] = []
        var conflicts: [String] = []

        // 1. Establish the day's schedulable time boundary (e.g. 09:00 - 17:00)
        guard let dayStart = calendar.date(bySettingHour: preferences.workStartHour, minute: 0, second: 0, of: targetDate),
              let dayEnd = calendar.date(bySettingHour: preferences.workEndHour, minute: 0, second: 0, of: targetDate),
              dayStart < dayEnd else {
            return SchedulingProposal(
                scheduledBlocks: [],
                unscheduledTasks: tasks.map { UnscheduledTaskReason(taskId: $0.id, taskTitle: $0.title, reason: "Invalid working hours window") },
                conflictsDetected: ["Day start is not before day end"]
            )
        }

        // 2. Extract busy intervals from existing commitments that overlap with targetDate
        let sortedCommitments = existingCommitments
            .filter { $0.endTime > dayStart && $0.startTime < dayEnd }
            .sorted { $0.startTime < $1.startTime }

        // Check for any internal conflicts within existing commitments
        for i in 0..<sortedCommitments.count {
            for j in (i + 1)..<sortedCommitments.count {
                let first = sortedCommitments[i]
                let second = sortedCommitments[j]
                if first.endTime > second.startTime {
                    conflicts.append("Existing commitment conflict between '\(first.title)' and '\(second.title)'")
                }
            }
        }

        // 3. Calculate available free slots respecting meeting buffers
        var availableSlots: [(start: Date, end: Date)] = []
        var pointer = dayStart

        for block in sortedCommitments {
            // Apply buffer before meeting
            let bufferedStart = block.startTime.addingTimeInterval(-Double(preferences.meetingBufferMinutes * 60))
            if pointer < bufferedStart {
                availableSlots.append((start: pointer, end: bufferedStart))
            }
            // Apply buffer after meeting
            let bufferedEnd = block.endTime.addingTimeInterval(Double(preferences.meetingBufferMinutes * 60))
            if pointer < bufferedEnd {
                pointer = bufferedEnd
            }
        }

        if pointer < dayEnd {
            availableSlots.append((start: pointer, end: dayEnd))
        }

        // 4. Sort tasks by:
        // Priority (urgent > high > medium > low) -> Deadline (earliest first) -> Duration (shortest first)
        let sortedTasks = tasks
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

        // 5. Place tasks into available slots
        var remainingSlots = availableSlots

        for task in sortedTasks {
            var isScheduled = false

            // If task is locked to a specific external event or fixed time, don't auto-move without permission
            if task.isLocked {
                unscheduled.append(UnscheduledTaskReason(taskId: task.id, taskTitle: task.title, reason: "Task is locked to manual time block"))
                continue
            }

            for slotIndex in 0..<remainingSlots.count {
                let slot = remainingSlots[slotIndex]
                let slotDuration = slot.end.timeIntervalSince(slot.start)

                if slotDuration >= task.estimatedDuration {
                    let taskStart = slot.start
                    let taskEnd = taskStart.addingTimeInterval(task.estimatedDuration)

                    // Verify deadline is respected if set
                    if let deadline = task.deadline, taskEnd > deadline {
                        unscheduled.append(UnscheduledTaskReason(
                            taskId: task.id,
                            taskTitle: task.title,
                            reason: "Insufficient time before task deadline (\(deadline.formatted()))"
                        ))
                        isScheduled = true // Handled as unscheduled with explicit reason
                        break
                    }

                    // Create scheduled TimeBlock
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
                unscheduled.append(UnscheduledTaskReason(
                    taskId: task.id,
                    taskTitle: task.title,
                    reason: "No available time slot of \(Int(task.estimatedDuration / 60)) minutes within working hours (\(preferences.workStartHour):00-\(preferences.workEndHour):00)"
                ))
            }
        }

        return SchedulingProposal(
            scheduledBlocks: scheduledBlocks,
            unscheduledTasks: unscheduled,
            conflictsDetected: conflicts
        )
    }
}

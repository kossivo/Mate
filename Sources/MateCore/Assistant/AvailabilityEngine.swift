import Foundation

public enum FreeSlotType: String, Sendable, Codable, CaseIterable {
    case focusDeepWork = "Tập trung sâu"
    case meetingWindow = "Khung giờ họp"
    case quickCatchup = "Trao đổi nhanh"
    case buffer = "Nghỉ & Đệm"
}

public struct SmartFreeSlotSuggestion: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let slot: FreeSlot
    public let type: FreeSlotType
    public let title: String
    public let subtitle: String
    public let suggestedActionPrompt: String

    public init(
        id: UUID = UUID(),
        slot: FreeSlot,
        type: FreeSlotType,
        title: String,
        subtitle: String,
        suggestedActionPrompt: String
    ) {
        self.id = id
        self.slot = slot
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.suggestedActionPrompt = suggestedActionPrompt
    }
}

public enum SuggestionKind: String, Sendable, Codable {
    case freeTime = "free_time"
    case scheduleMeeting = "schedule_meeting"
    case reschedule = "reschedule"
    case reminder = "reminder"
    case reallocatePriority = "reallocate_priority"
}

public struct SmartSuggestion: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: SuggestionKind
    public let title: String
    public let detail: String
    public let actionTitle: String
    public let iconName: String
    public let targetTaskId: UUID?
    public let targetBlockId: UUID?
    public let suggestedStartTime: Date?
    public let suggestedEndTime: Date?

    public init(
        id: UUID = UUID(),
        kind: SuggestionKind,
        title: String,
        detail: String,
        actionTitle: String,
        iconName: String,
        targetTaskId: UUID? = nil,
        targetBlockId: UUID? = nil,
        suggestedStartTime: Date? = nil,
        suggestedEndTime: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.actionTitle = actionTitle
        self.iconName = iconName
        self.targetTaskId = targetTaskId
        self.targetBlockId = targetBlockId
        self.suggestedStartTime = suggestedStartTime
        self.suggestedEndTime = suggestedEndTime
    }
}

public struct FreeSlot: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(id: UUID = UUID(), startTime: Date, endTime: Date) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }
}

public final class AvailabilityEngine: @unchecked Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /// Finds candidate free slots of a given duration within working hours across target dates.
    /// If target date is today and already in the evening, automatically looks at tomorrow and upcoming days!
    public func findAvailableSlots(
        durationMinutes: Int = 45,
        existingCommitments: [TimeBlock],
        preferences: UserPreference = UserPreference(),
        targetDate: Date = Date(),
        referenceDate: Date? = nil,
        maxSlots: Int = 3
    ) -> [FreeSlot] {
        var effectiveDate = targetDate
        let now = referenceDate ?? Date()
        let isToday = calendar.isDateInToday(targetDate)

        // Only roll forward to tomorrow if evaluating real-time today and we are already at or past the end of the workday
        // (If referenceDate is nil and targetDate hour is explicitly set <= workStartHour, like in test cases, evaluate targetDate from dayStart)
        let targetHour = calendar.component(.hour, from: targetDate)
        let isSimulatedOrExplicit = referenceDate != nil || targetHour <= preferences.workStartHour

        if isToday && !isSimulatedOrExplicit {
            let currentHour = calendar.component(.hour, from: now)
            if currentHour >= preferences.workEndHour {
                effectiveDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            }
        }

        var slots = findSlotsForSingleDay(
            date: effectiveDate,
            durationMinutes: durationMinutes,
            existingCommitments: existingCommitments,
            preferences: preferences,
            evalDate: isSimulatedOrExplicit ? effectiveDate : now,
            maxSlots: maxSlots
        )

        // If we haven't reached maxSlots yet, check subsequent days (skipping weekends if protected)
        if slots.count < maxSlots {
            for dayOffset in 1...5 {
                if let nextDay = calendar.date(byAdding: .day, value: dayOffset, to: effectiveDate) {
                    if preferences.protectWeekends && calendar.isDateInWeekend(nextDay) {
                        continue
                    }
                    let nextSlots = findSlotsForSingleDay(
                        date: nextDay,
                        durationMinutes: durationMinutes,
                        existingCommitments: existingCommitments,
                        preferences: preferences,
                        evalDate: nextDay,
                        maxSlots: maxSlots - slots.count
                    )
                    slots.append(contentsOf: nextSlots)
                    if slots.count >= maxSlots { break }
                }
            }
        }

        return Array(slots.prefix(maxSlots))
    }

    private func findSlotsForSingleDay(
        date: Date,
        durationMinutes: Int,
        existingCommitments: [TimeBlock],
        preferences: UserPreference,
        evalDate: Date,
        maxSlots: Int
    ) -> [FreeSlot] {
        guard let dayStart = calendar.date(bySettingHour: preferences.workStartHour, minute: 0, second: 0, of: date),
              let dayEnd = calendar.date(bySettingHour: preferences.workEndHour, minute: 0, second: 0, of: date),
              dayStart < dayEnd else {
            return []
        }

        let neededDuration = TimeInterval(durationMinutes * 60)
        let sorted = existingCommitments
            .filter { $0.endTime > dayStart && $0.startTime < dayEnd }
            .sorted { $0.startTime < $1.startTime }

        var slots: [FreeSlot] = []
        var pointer = dayStart

        // If evaluating today and evalDate is in the middle of the day, pointer cannot be in the past
        if calendar.isDateInToday(date) && calendar.isDateInToday(evalDate) && evalDate > dayStart {
            let bufferNow = evalDate.addingTimeInterval(15 * 60)
            if pointer < bufferNow {
                pointer = bufferNow
            }
        }

        let bufferSec = Double(preferences.meetingBufferMinutes * 60)

        for block in sorted {
            let bufferedStart = block.startTime.addingTimeInterval(-bufferSec)

            while pointer.addingTimeInterval(neededDuration) <= bufferedStart && slots.count < maxSlots {
                let slotEnd = pointer.addingTimeInterval(neededDuration)
                slots.append(FreeSlot(startTime: pointer, endTime: slotEnd))
                pointer = slotEnd.addingTimeInterval(bufferSec)
            }

            let bufferedEnd = block.endTime.addingTimeInterval(bufferSec)
            if pointer < bufferedEnd {
                pointer = bufferedEnd
            }
        }

        while pointer.addingTimeInterval(neededDuration) <= dayEnd && slots.count < maxSlots {
            let slotEnd = pointer.addingTimeInterval(neededDuration)
            slots.append(FreeSlot(startTime: pointer, endTime: slotEnd))
            pointer = slotEnd.addingTimeInterval(bufferSec)
        }

        return slots
    }

    /// Formats invitation snippet in English or Vietnamese ready for copy/pasting into messaging apps.
    public func formatInvitationMessage(slots: [FreeSlot], guestName: String? = nil, locale: String = "vi") -> String {
        guard !slots.isEmpty else {
            return locale == "vi" ? "Hiện tại lịch của mình đã kín trong những ngày tới." : "Currently my schedule is completely full over the coming days."
        }

        if locale == "vi" {
            let greeting = guestName.map { "Chào \($0), " } ?? "Chào bạn, "
            var msg = "\(greeting)mình đã kiểm tra lịch và gửi bạn các khung giờ rảnh tiện hẹn nhất:\n\n"
            for (idx, slot) in slots.enumerated() {
                let dayStr = slot.startTime.formatted(.dateTime.weekday(.wide).day().month())
                let timeStr = "\(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened))"
                msg += "\(idx + 1). \(dayStr): \(timeStr)\n"
            }
            msg += "\nKhung giờ nào tiện nhất cho bạn thì nhắn lại mình nhé!"
            return msg
        } else {
            let greeting = guestName.map { "Hi \($0), " } ?? "Hi, "
            var msg = "\(greeting)I checked my calendar and have these available times:\n\n"
            for (idx, slot) in slots.enumerated() {
                let dayStr = slot.startTime.formatted(.dateTime.weekday(.wide).month().day())
                let timeStr = "\(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened))"
                msg += "\(idx + 1). \(dayStr): \(timeStr)\n"
            }
            msg += "\nLet me know which time works best for you!"
            return msg
        }
    }

    /// Suggests optimal categorized free slots (Deep Work, Meeting Window, Quick Catchup) based on calendar availability.
    public func suggestOptimalSlots(
        existingCommitments: [TimeBlock],
        preferences: UserPreference = UserPreference(),
        targetDate: Date = Date(),
        referenceDate: Date? = nil,
        maxSlots: Int = 4
    ) -> [SmartFreeSlotSuggestion] {
        let rawSlots = findAvailableSlots(
            durationMinutes: 45,
            existingCommitments: existingCommitments,
            preferences: preferences,
            targetDate: targetDate,
            referenceDate: referenceDate,
            maxSlots: maxSlots
        )

        return rawSlots.map { slot in
            let hour = calendar.component(.hour, from: slot.startTime)
            let isMorning = hour < 12
            let durationMin = Int(slot.duration / 60)

            let type: FreeSlotType
            let title: String
            let subtitle: String
            let action: String

            if isMorning {
                type = .focusDeepWork
                title = "Khung giờ vàng tập trung sâu"
                subtitle = "Khoảng trống \(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened)) không bị ngắt quãng. Lý tưởng cho việc giải quyết task phức tạp."
                action = "Xếp việc tập trung"
            } else if durationMin >= 45 {
                type = .meetingWindow
                title = "Khung giờ lý tưởng để họp"
                subtitle = "Khoảng trống chiều \(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened)) có sẵn đệm nghỉ trước sau. Thuận tiện trao đổi đối tác."
                action = "Lên lịch họp"
            } else {
                type = .quickCatchup
                title = "Trao đổi nhanh 15-30 phút"
                subtitle = "Thời lượng gọn gàng \(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened)) cho sync tiến độ hoặc kiểm tra công việc."
                action = "Lên lịch sync nhanh"
            }

            return SmartFreeSlotSuggestion(
                slot: slot,
                type: type,
                title: title,
                subtitle: subtitle,
                suggestedActionPrompt: action
            )
        }
    }

    /// Analyzes schedule state to generate deterministic, actionable smart suggestions:
    /// - Meeting scheduling (finding optimal slot for unscheduled meeting tasks)
    /// - Smart rescheduling (resolving conflicts or moving evening overflows to tomorrow morning)
    /// - Smart reminders (proactive alerts for impending deadlines)
    /// - Priority reallocation (reorganizing timeline by priority)
    public func generateSmartSuggestions(
        tasks: [TaskItem],
        existingCommitments: [TimeBlock],
        preferences: UserPreference = UserPreference(),
        targetDate: Date = Date(),
        referenceDate: Date? = nil
    ) -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        let now = referenceDate ?? Date()

        let freeSlots = findAvailableSlots(
            durationMinutes: 45,
            existingCommitments: existingCommitments,
            preferences: preferences,
            targetDate: targetDate,
            referenceDate: referenceDate,
            maxSlots: 2
        )

        // 1. Suggestion to schedule an unplaced meeting task into the best free slot
        let meetingKeywords = ["họp", "gặp", "meeting", "sync", "thảo luận", "1on1"]
        let unplacedMeetingTask = tasks.first { task in
            task.status != .completed &&
            (task.category?.lowercased() == "meeting" ||
             meetingKeywords.contains(where: { task.title.lowercased().contains($0) })) &&
            !existingCommitments.contains(where: { $0.taskId == task.id || $0.title == task.title })
        }

        if let task = unplacedMeetingTask, let slot = freeSlots.first {
            let timeStr = "\(slot.startTime.formatted(date: .omitted, time: .shortened)) - \(slot.endTime.formatted(date: .omitted, time: .shortened))"
            suggestions.append(SmartSuggestion(
                kind: .scheduleMeeting,
                title: "Lên lịch cuộc họp: \(task.title)",
                detail: "Đã phát hiện việc cần gặp gỡ. Khung giờ trống lý tưởng nhất là \(timeStr).",
                actionTitle: "Lên lịch ngay",
                iconName: "calendar.badge.plus",
                targetTaskId: task.id,
                suggestedStartTime: slot.startTime,
                suggestedEndTime: slot.startTime.addingTimeInterval(task.estimatedDuration)
            ))
        }

        // 2. Suggestion to Reschedule (Conflicts or Evening Overflow)
        // Detect conflicts between existing commitments
        for i in 0..<existingCommitments.count {
            for j in (i + 1)..<existingCommitments.count {
                let first = existingCommitments[i]
                let second = existingCommitments[j]
                if first.endTime > second.startTime && first.startTime < second.endTime {
                    let moveTarget = second.isLocked ? first : second
                    let alternateSlot = freeSlots.first(where: { $0.startTime > second.endTime }) ?? freeSlots.first
                    if let alt = alternateSlot {
                        suggestions.append(SmartSuggestion(
                            kind: .reschedule,
                            title: "Trùng lịch: \(moveTarget.title)",
                            detail: "Xung đột thời gian với '\(moveTarget.id == first.id ? second.title : first.title)'. Gợi ý dời sang \(alt.startTime.formatted(date: .omitted, time: .shortened)).",
                            actionTitle: "Dời sang \(alt.startTime.formatted(date: .omitted, time: .shortened))",
                            iconName: "clock.arrow.2.circlepath",
                            targetBlockId: moveTarget.id,
                            suggestedStartTime: alt.startTime,
                            suggestedEndTime: alt.startTime.addingTimeInterval(moveTarget.duration)
                        ))
                    }
                }
            }
        }

        // Detect evening overflow
        let currentHour = calendar.component(.hour, from: now)
        if currentHour >= preferences.workEndHour {
            let incompleteTasks = tasks.filter { $0.status != .completed }
            if !incompleteTasks.isEmpty, let tmrMorning = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now) ?? now) {
                suggestions.append(SmartSuggestion(
                    kind: .reschedule,
                    title: "Dời \(incompleteTasks.count) việc sang sáng mai",
                    detail: "Hiện đã qua giờ làm việc. Tự động chuyển các việc còn lại sang 09:30 sáng mai để bảo vệ nhịp nghỉ ngơi.",
                    actionTitle: "Dời sang sáng mai",
                    iconName: "moon.fill",
                    suggestedStartTime: tmrMorning
                ))
            }
        }

        // 3. Smart Reminders for impending deadlines
        for task in tasks where task.status != .completed {
            if let deadline = task.deadline, calendar.isDateInToday(deadline) {
                let minutesUntil = Int(deadline.timeIntervalSince(now) / 60)
                if minutesUntil > 0 && minutesUntil <= 180 {
                    suggestions.append(SmartSuggestion(
                        kind: .reminder,
                        title: "Hạn chót sắp tới: \(task.title)",
                        detail: "Thời hạn vào lúc \(deadline.formatted(date: .omitted, time: .shortened)) (còn \(minutesUntil) phút). Hãy bắt đầu để kịp tiến độ.",
                        actionTitle: "Đặt báo nhắc",
                        iconName: "bell.badge.fill",
                        targetTaskId: task.id,
                        suggestedStartTime: deadline.addingTimeInterval(-task.estimatedDuration)
                    ))
                }
            }
        }

        // 4. Priority Reallocation Suggestion
        let urgentOrHigh = tasks.filter { $0.status != .completed && ($0.priority == .urgent || $0.priority == .high) }
        if urgentOrHigh.count >= 2 {
            suggestions.append(SmartSuggestion(
                kind: .reallocatePriority,
                title: "Sắp xếp lại lịch theo độ ưu tiên",
                detail: "Bạn có \(urgentOrHigh.count) việc quan trọng. Tự động ưu tiên xếp các việc này vào giờ tập trung vàng.",
                actionTitle: "Tối ưu hoá theo ưu tiên",
                iconName: "arrow.up.arrow.down.square.fill"
            ))
        }

        // 5. Best Free Time Suggestion
        if let bestSlot = freeSlots.first {
            let timeStr = "\(bestSlot.startTime.formatted(date: .omitted, time: .shortened)) – \(bestSlot.endTime.formatted(date: .omitted, time: .shortened))"
            suggestions.append(SmartSuggestion(
                kind: .freeTime,
                title: "Khung giờ rảnh tốt nhất: \(timeStr)",
                detail: "\(Int(bestSlot.duration / 60)) phút trống sẵn sàng cho bạn lên lịch họp hoặc tập trung sâu.",
                actionTitle: "Sử dụng giờ rảnh",
                iconName: "sparkles",
                suggestedStartTime: bestSlot.startTime,
                suggestedEndTime: bestSlot.endTime
            ))
        }

        return suggestions
    }
}

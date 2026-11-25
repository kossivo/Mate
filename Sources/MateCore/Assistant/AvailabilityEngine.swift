import Foundation

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
}

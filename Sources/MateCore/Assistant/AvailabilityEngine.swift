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
    public func findAvailableSlots(
        durationMinutes: Int = 45,
        existingCommitments: [TimeBlock],
        preferences: UserPreference = UserPreference(),
        targetDate: Date = Date(),
        maxSlots: Int = 3
    ) -> [FreeSlot] {
        guard let dayStart = calendar.date(bySettingHour: preferences.workStartHour, minute: 0, second: 0, of: targetDate),
              let dayEnd = calendar.date(bySettingHour: preferences.workEndHour, minute: 0, second: 0, of: targetDate),
              dayStart < dayEnd else {
            return []
        }

        let neededDuration = TimeInterval(durationMinutes * 60)
        let sorted = existingCommitments
            .filter { $0.endTime > dayStart && $0.startTime < dayEnd }
            .sorted { $0.startTime < $1.startTime }

        var slots: [FreeSlot] = []
        var pointer = dayStart

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
            return locale == "vi" ? "Hiện tại lịch của mình đã kín trong ngày này." : "Currently my schedule is completely full on this day."
        }

        if locale == "vi" {
            let greeting = guestName.map { "Chào \($0), " } ?? "Chào bạn, "
            var msg = "\(greeting)mình đã kiểm tra lịch và có các khung giờ rảnh sau:\n"
            for (idx, slot) in slots.enumerated() {
                let dayStr = slot.startTime.formatted(.dateTime.weekday(.wide).day().month())
                let timeStr = "\(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened))"
                msg += "\(idx + 1). \(dayStr): \(timeStr)\n"
            }
            msg += "Khung giờ nào tiện nhất cho bạn nhắn mình nhé!"
            return msg
        } else {
            let greeting = guestName.map { "Hi \($0), " } ?? "Hi, "
            var msg = "\(greeting)I checked my schedule and have these available slots:\n"
            for (idx, slot) in slots.enumerated() {
                let dayStr = slot.startTime.formatted(.dateTime.weekday(.wide).month().day())
                let timeStr = "\(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened))"
                msg += "\(idx + 1). \(dayStr): \(timeStr)\n"
            }
            msg += "Let me know which time works best for you!"
            return msg
        }
    }
}

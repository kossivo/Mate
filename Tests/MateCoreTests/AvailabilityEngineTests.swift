import Testing
import Foundation
@testable import MateCore

@Suite("AvailabilityEngineTests")
struct AvailabilityEngineTests {

    @Test func testFindThreeFreeSlotsAroundMeeting() {
        let engine = AvailabilityEngine()
        let calendar = Calendar(identifier: .gregorian)

        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        // Meeting from 11:00 to 12:30
        let meetingStart = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: targetDate)!
        let meetingEnd = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: targetDate)!
        let meeting = TimeBlock(title: "Client Sync", startTime: meetingStart, endTime: meetingEnd, isLocked: true)

        let prefs = UserPreference(workStartHour: 9, workEndHour: 17, meetingBufferMinutes: 10)

        let slots = engine.findAvailableSlots(
            durationMinutes: 45,
            existingCommitments: [meeting],
            preferences: prefs,
            targetDate: targetDate,
            maxSlots: 3
        )

        #expect(slots.count == 3)
        // First slot should be morning before meeting: 09:00 to 09:45
        #expect(slots[0].startTime == targetDate)
        #expect(slots[0].duration == 45 * 60)

        // Test formatting in Vietnamese
        let msgVI = engine.formatInvitationMessage(slots: slots, guestName: "Linh", locale: "vi")
        #expect(msgVI.contains("Chào Linh"))
        #expect(msgVI.contains("1."))
        #expect(msgVI.contains("2."))
        #expect(msgVI.contains("3."))

        // Test formatting in English
        let msgEN = engine.formatInvitationMessage(slots: slots, guestName: "Alex", locale: "en")
        #expect(msgEN.contains("Hi Alex"))
    }
}

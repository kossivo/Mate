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

        let prefs = UserPreference(workStartHour: 9, workEndHour: 17, meetingBufferMinutes: 10, protectWeekends: false)

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

    @Test func testSuggestOptimalFreeSlots() {
        let engine = AvailabilityEngine()
        let calendar = Calendar(identifier: .gregorian)
        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        let meetingStart = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: targetDate)!
        let meetingEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: targetDate)!
        let meeting = TimeBlock(title: "Design Review", startTime: meetingStart, endTime: meetingEnd, isLocked: true)

        let prefs = UserPreference(workStartHour: 9, workEndHour: 17, meetingBufferMinutes: 10, protectWeekends: false)

        let suggestions = engine.suggestOptimalSlots(
            existingCommitments: [meeting],
            preferences: prefs,
            targetDate: targetDate,
            referenceDate: targetDate,
            maxSlots: 3
        )

        #expect(!suggestions.isEmpty)
        let first = suggestions[0]
        #expect(first.type == .focusDeepWork)
        #expect(first.title.contains("Deep Focus"))
        #expect(first.suggestedActionPrompt == "Assign Focus Task")
    }

    @Test func testGenerateSmartSuggestions() {
        let engine = AvailabilityEngine()
        let calendar = Calendar(identifier: .gregorian)
        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        // Task with meeting category
        let meetingTask = TaskItem(
            title: "Gặp thảo luận hợp đồng với Nam",
            category: "Meeting",
            estimatedDuration: 45 * 60,
            priority: .urgent
        )

        // Task with approaching deadline
        let deadlineTask = TaskItem(
            title: "Hoàn thành slide báo cáo",
            deadline: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: targetDate),
            estimatedDuration: 60 * 60,
            priority: .high
        )

        let prefs = UserPreference(workStartHour: 9, workEndHour: 17, meetingBufferMinutes: 10, protectWeekends: false)

        let suggestions = engine.generateSmartSuggestions(
            tasks: [meetingTask, deadlineTask],
            existingCommitments: [],
            preferences: prefs,
            targetDate: targetDate,
            referenceDate: targetDate
        )

        #expect(!suggestions.isEmpty)
        let scheduleMeeting = suggestions.first { $0.kind == .scheduleMeeting }
        #expect(scheduleMeeting != nil)
        #expect(scheduleMeeting?.title.contains("Gặp thảo luận hợp đồng với Nam") == true)

        let priorityReallocation = suggestions.first { $0.kind == .reallocatePriority }
        #expect(priorityReallocation != nil)
    }

    @Test func testFindFreeSlotsWithExactMinutePreferences() {
        let engine = AvailabilityEngine()
        let calendar = Calendar(identifier: .gregorian)
        let targetDate = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!

        let prefs = UserPreference(workStartHour: 8, workStartMinute: 30, workEndHour: 17, workEndMinute: 30, meetingBufferMinutes: 10, protectWeekends: false)

        let slots = engine.findAvailableSlots(
            durationMinutes: 45,
            existingCommitments: [],
            preferences: prefs,
            targetDate: targetDate,
            referenceDate: targetDate,
            maxSlots: 2
        )

        #expect(!slots.isEmpty)
        let firstSlot = slots[0]
        let slotStartHour = calendar.component(.hour, from: firstSlot.startTime)
        let slotStartMinute = calendar.component(.minute, from: firstSlot.startTime)
        #expect(slotStartHour == 8)
        #expect(slotStartMinute == 30)
    }
}

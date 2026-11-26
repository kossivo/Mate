import Testing
import Foundation
@testable import MateCore

@Suite("SmartSchedulingEngineTests")
struct SmartSchedulingEngineTests {

    @Test func testSchedulingAroundExistingMeeting() {
        let engine = SmartSchedulingEngine()
        let calendar = Calendar(identifier: .gregorian)

        var comp = DateComponents()
        comp.year = 2026
        comp.month = 11
        comp.day = 26 // Thursday
        comp.hour = 9
        comp.minute = 0
        let targetDate = calendar.date(from: comp)!

        // Existing meeting 10:00 - 11:00
        let meetingStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: targetDate)!
        let meetingEnd = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: targetDate)!
        let existingMeeting = TimeBlock(
            title: "Team Standup",
            startTime: meetingStart,
            endTime: meetingEnd,
            isLocked: true
        )

        // Task to schedule: 45 minutes
        let task = TaskItem(
            title: "Prepare Slide Deck",
            estimatedDuration: 45 * 60,
            priority: .high
        )

        let prefs = UserPreference(
            workStartHour: 9,
            workEndHour: 17,
            meetingBufferMinutes: 10
        )

        let proposal = engine.schedule(
            tasks: [task],
            existingCommitments: [existingMeeting],
            preferences: prefs,
            targetDate: targetDate
        )

        #expect(proposal.scheduledBlocks.count == 1)
        #expect(proposal.unscheduledTasks.isEmpty)

        let scheduled = proposal.scheduledBlocks[0]
        #expect(scheduled.title == "Prepare Slide Deck")
        // Available slot before meeting: 09:00 to 09:50 (due to 10 min buffer before 10:00).
        // 45 min task fits from 09:00 to 09:45!
        #expect(scheduled.startTime == targetDate) // 09:00
        #expect(scheduled.endTime <= meetingStart)
    }

    @Test func testInsufficientTimeReportsExplicitReason() {
        let engine = SmartSchedulingEngine()
        let calendar = Calendar(identifier: .gregorian)

        var comp = DateComponents()
        comp.year = 2026
        comp.month = 11
        comp.day = 26
        comp.hour = 9
        let targetDate = calendar.date(from: comp)!

        // Huge meeting taking almost whole day: 09:30 to 16:30
        let bigMeetingStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: targetDate)!
        let bigMeetingEnd = calendar.date(bySettingHour: 16, minute: 30, second: 0, of: targetDate)!
        let bigMeeting = TimeBlock(title: "All Day Workshop", startTime: bigMeetingStart, endTime: bigMeetingEnd, isLocked: true)

        // Task needs 2 hours (120 min)
        let largeTask = TaskItem(
            title: "Write Architecture Spec",
            estimatedDuration: 120 * 60,
            priority: .urgent
        )

        let prefs = UserPreference(workStartHour: 9, workEndHour: 17, meetingBufferMinutes: 10)

        let proposal = engine.schedule(
            tasks: [largeTask],
            existingCommitments: [bigMeeting],
            preferences: prefs,
            targetDate: targetDate
        )

        #expect(proposal.scheduledBlocks.isEmpty)
        #expect(proposal.unscheduledTasks.count == 1)
        #expect(proposal.unscheduledTasks[0].reason.contains("No available time slot"))
    }

    @Test func testConflictDetectionBetweenExistingEvents() {
        let engine = SmartSchedulingEngine()
        let calendar = Calendar(identifier: .gregorian)

        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let event1 = TimeBlock(title: "Meeting A", startTime: targetDate, endTime: targetDate.addingTimeInterval(3600))
        let event2 = TimeBlock(title: "Meeting B", startTime: targetDate.addingTimeInterval(1800), endTime: targetDate.addingTimeInterval(5400))

        let proposal = engine.schedule(
            tasks: [],
            existingCommitments: [event1, event2],
            preferences: UserPreference(),
            targetDate: targetDate
        )

        #expect(!proposal.conflictsDetected.isEmpty)
    }

    @Test func testReallocateTasksByPriority() {
        let engine = SmartSchedulingEngine()
        let calendar = Calendar(identifier: .gregorian)
        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        let lowTask = TaskItem(title: "Check social media", priority: .low)
        let mediumTask = TaskItem(title: "Follow up email", priority: .medium)
        let urgentTask = TaskItem(title: "Fix critical production bug", priority: .urgent)
        let highTask = TaskItem(title: "Finish client presentation", priority: .high)

        let result = engine.reallocateTasksByPriority(
            tasks: [lowTask, mediumTask, urgentTask, highTask],
            existingCommitments: [],
            preferences: UserPreference(),
            targetDate: targetDate
        )

        // Urgent should be first, followed by High, Medium, Low
        #expect(result.reallocatedTasks.count == 4)
        #expect(result.reallocatedTasks[0].title == "Fix critical production bug")
        #expect(result.reallocatedTasks[1].title == "Finish client presentation")
        #expect(result.reallocatedTasks[2].title == "Follow up email")
        #expect(result.reallocatedTasks[3].title == "Check social media")

        // First scheduled block should be the urgent task
        #expect(!result.proposal.scheduledBlocks.isEmpty)
        #expect(result.proposal.scheduledBlocks[0].title == "Fix critical production bug")
    }

    @Test func testStoreKitDeviceWhitelisting() async {
        let storeKit = StoreKitManager.shared
        storeKit.setWhitelisted(true)
        #expect(storeKit.isWhitelisted == true)
        #expect(storeKit.isPro == true)
        let unlocked = await storeKit.isPremiumUnlocked()
        #expect(unlocked == true)
    }

    @Test func testAllDayHolidayDoesNotBlockDailyTaskScheduling() {
        let engine = SmartSchedulingEngine()
        let calendar = Calendar(identifier: .gregorian)
        let targetDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

        // All-day holiday covering 00:00 to 24:00
        let holidayStart = calendar.startOfDay(for: targetDate)
        let holidayEnd = calendar.date(byAdding: .day, value: 1, to: holidayStart)!
        let holidayBlock = TimeBlock(
            title: "National Holiday",
            startTime: holidayStart,
            endTime: holidayEnd,
            isLocked: true,
            category: "Holiday",
            isAllDay: true
        )

        let task = TaskItem(title: "Complete report draft", estimatedDuration: 1800, priority: .high)

        let proposal = engine.schedule(
            tasks: [task],
            existingCommitments: [holidayBlock],
            preferences: UserPreference(),
            targetDate: targetDate
        )

        // The all-day holiday must NOT block the schedule
        #expect(proposal.scheduledBlocks.count == 1)
        #expect(proposal.scheduledBlocks[0].title == "Complete report draft")
        #expect(proposal.unscheduledTasks.isEmpty)
    }

    @Test func testTaskPriorityOrderingAndManualRanking() {
        let engine = SmartSchedulingEngine()
        let lowTask = TaskItem(title: "Low Task", estimatedDuration: 1800, priority: .low)
        let medTask = TaskItem(title: "Med Task", estimatedDuration: 1800, priority: .medium)
        let highTask = TaskItem(title: "High Task", estimatedDuration: 1800, priority: .high)
        let urgentTask = TaskItem(title: "Urgent Task", estimatedDuration: 1800, priority: .urgent)

        let unordered = [lowTask, medTask, highTask, urgentTask]
        let result = engine.reallocateTasksByPriority(tasks: unordered, existingCommitments: [])

        #expect(result.reallocatedTasks[0].priority == .urgent)
        #expect(result.reallocatedTasks[1].priority == .high)
        #expect(result.reallocatedTasks[2].priority == .medium)
        #expect(result.reallocatedTasks[3].priority == .low)

        // Verify TaskPriority properties
        #expect(TaskPriority.urgent.title == "Urgent")
        #expect(TaskPriority.high.title == "High")
        #expect(TaskPriority.allCases.count == 4)
    }
}

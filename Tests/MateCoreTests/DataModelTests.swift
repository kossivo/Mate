import Testing
import Foundation
@testable import MateCore

@Suite("DataModelSerializationTests")
struct DataModelSerializationTests {

    @Test func testTaskItemCodable() throws {
        let task = TaskItem(
            title: "Review PR #42",
            notes: "Make sure unit tests pass",
            category: "Engineering",
            deadline: Date(),
            estimatedDuration: 1800,
            priority: .urgent,
            status: .inProgress,
            isLocked: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TaskItem.self, from: data)

        #expect(decoded.id == task.id)
        #expect(decoded.title == task.title)
        #expect(decoded.priority == .urgent)
        #expect(decoded.status == .inProgress)
    }

    @Test func testUserPreferenceDefaults() {
        let prefs = UserPreference()
        #expect(prefs.workStartHour == 9)
        #expect(prefs.workStartMinute == 0)
        #expect(prefs.workEndHour == 17)
        #expect(prefs.workEndMinute == 0)
        #expect(prefs.meetingBufferMinutes == 10)
        #expect(prefs.protectWeekends == true)
    }

    @Test func testUserPreferenceExactMinutes() {
        let prefs = UserPreference(workStartHour: 8, workStartMinute: 30, workEndHour: 17, workEndMinute: 45)
        #expect(prefs.workStartHour == 8)
        #expect(prefs.workStartMinute == 30)
        #expect(prefs.workEndHour == 17)
        #expect(prefs.workEndMinute == 45)
    }

    @Test func testUserPreferenceLegacyDecodingBackwardCompatibility() throws {
        // Simulating older JSON without workStartMinute or workEndMinute
        let legacyJSON = """
        {
            "workStartHour": 8,
            "workEndHour": 18,
            "preferredTaskDurationMinutes": 25,
            "meetingBufferMinutes": 15,
            "protectWeekends": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(UserPreference.self, from: legacyJSON)
        #expect(decoded.workStartHour == 8)
        #expect(decoded.workStartMinute == 0)
        #expect(decoded.workEndHour == 18)
        #expect(decoded.workEndMinute == 0)
        #expect(decoded.meetingBufferMinutes == 15)
        #expect(decoded.protectWeekends == false)
    }

    @Test func testNoteItemMatchesExactContent() {
        let note1 = NoteItem(title: "Ideas", content: "  Meeting notes with team\n  ")
        #expect(note1.matchesExactContent(of: "meeting notes with team"))
        #expect(note1.matchesExactContent(of: "Meeting notes with team\n"))
        #expect(!note1.matchesExactContent(of: "Different content"))
    }

    @Test func testTimeBlockWithIsAllDay() {
        let block = TimeBlock(
            title: "Thanksgiving Day",
            startTime: Date(),
            endTime: Date().addingTimeInterval(86400),
            isLocked: true,
            category: "Holiday",
            isAllDay: true
        )
        #expect(block.isAllDay == true)
        #expect(block.category == "Holiday")
    }

    @Test func testTimeBlockLegacyDecodingBackwardCompatibility() throws {
        let legacyJSON = """
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "title": "Strategy Sync",
            "startTime": 1700000000,
            "endTime": 1700003600,
            "isLocked": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(TimeBlock.self, from: legacyJSON)
        #expect(decoded.title == "Strategy Sync")
        #expect(decoded.isAllDay == false)
    }

    @Test func testNoteItemCodable() throws {
        let note = NoteItem(
            title: "Meeting with Client",
            content: "Discuss Q4 roadmap and contract signing."
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(note)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NoteItem.self, from: data)

        #expect(decoded.id == note.id)
        #expect(decoded.title == "Meeting with Client")
        #expect(decoded.content.contains("roadmap"))
    }

    @Test @MainActor func testDataManagerTaskPersistenceAndToggle() {
        let store = DataManager.shared
        let uniqueTitle = "Task_\(UUID().uuidString)"
        let task = TaskItem(title: uniqueTitle, priority: .high)
        store.addTask(task)
        #expect(store.tasks.contains(where: { $0.id == task.id }))

        store.toggleTaskCompletion(task)
        let toggled = store.tasks.first(where: { $0.id == task.id })
        #expect(toggled?.status == .completed)

        store.deleteTask(withId: task.id)
        #expect(!store.tasks.contains(where: { $0.id == task.id }))
    }

    @Test @MainActor func testDataManagerProposalApplicationPreservesLocked() {
        let store = DataManager.shared
        let lockedBlock = TimeBlock(
            title: "Board Meeting",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            isLocked: true
        )
        store.scheduledBlocks = [lockedBlock]

        let newBlock = TimeBlock(
            title: "Focus Time",
            startTime: Date().addingTimeInterval(3600),
            endTime: Date().addingTimeInterval(7200),
            isLocked: false
        )
        let proposal = SchedulingProposal(scheduledBlocks: [newBlock])
        store.applyProposal(proposal)

        #expect(store.scheduledBlocks.contains(where: { $0.title == "Board Meeting" }))
        #expect(store.scheduledBlocks.contains(where: { $0.title == "Focus Time" }))
    }

    @Test func testStoreKitProductFetchFallback() async {
        let storeKit = StoreKitManager.shared
        let products = await storeKit.fetchAvailableProducts()
        #expect(products.count == 2)
        #expect(products.contains(where: { $0.isAnnual }))
        #expect(products.contains(where: { !$0.isAnnual }))
    }
}

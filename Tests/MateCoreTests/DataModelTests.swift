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
        #expect(prefs.workEndHour == 17)
        #expect(prefs.meetingBufferMinutes == 10)
        #expect(prefs.protectWeekends == true)
    }
}

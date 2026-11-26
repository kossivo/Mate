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
}

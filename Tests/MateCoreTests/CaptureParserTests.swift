import Testing
import Foundation
@testable import MateCore

@Suite("DeterministicCaptureParserTests")
struct DeterministicCaptureParserTests {

    @Test func testMultiTaskParsingFromPrompt() {
        let parser = DeterministicCaptureParser()
        let input = "I need to finish my presentation by Friday, call Mum tonight and exercise three times this week."

        // Reference date: Wednesday 10:00 AM
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 11
        comp.day = 25 // Wednesday
        comp.hour = 10
        comp.minute = 0
        let calendar = Calendar(identifier: .gregorian)
        let refDate = calendar.date(from: comp)!

        let results = parser.parse(text: input, referenceDate: refDate)

        #expect(results.count == 3)

        // Task 1: Presentation
        let task1 = results[0]
        #expect(task1.title.lowercased().contains("presentation"))
        #expect(task1.deadline != nil)
        #expect(task1.estimatedDuration == 3600) // 1 hr default

        // Task 2: Call Mum
        let task2 = results[1]
        #expect(task2.title.lowercased().contains("mum") || task2.title.lowercased().contains("call"))
        #expect(task2.deadline != nil)
        #expect(task2.estimatedDuration == 900) // 15 mins default

        // Task 3: Exercise
        let task3 = results[2]
        #expect(task3.title.lowercased().contains("exercise"))
        #expect(task3.recurrence == "3x_weekly")
        #expect(task3.category == "Health & Routine")
    }

    @Test func testAmbiguousTaskWithoutDeadline() {
        let parser = DeterministicCaptureParser()
        let input = "Complete report"
        let results = parser.parse(text: input)

        #expect(results.count == 1)
        #expect(results[0].isAmbiguous == true)
        #expect(!results[0].ambiguityNotes.isEmpty)
    }
}

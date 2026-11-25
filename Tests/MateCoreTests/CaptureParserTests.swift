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

    @Test func testVietnameseMultiTaskParsing() {
        let parser = DeterministicCaptureParser()
        let input = "Tôi cần hoàn thành slide trước thứ 6, gọi cho mẹ tối nay và tập thể dục 3 lần tuần này"

        var comp = DateComponents()
        comp.year = 2026
        comp.month = 11
        comp.day = 25 // Wednesday
        comp.hour = 10
        let calendar = Calendar(identifier: .gregorian)
        let refDate = calendar.date(from: comp)!

        let results = parser.parse(text: input, referenceDate: refDate)

        #expect(results.count == 3)
        // Task 1: Slide
        #expect(results[0].title.lowercased().contains("slide"))
        #expect(results[0].deadline != nil)
        #expect(results[0].category == "Work")

        // Task 2: Gọi mẹ
        #expect(results[1].title.lowercased().contains("mẹ") || results[1].title.lowercased().contains("gọi"))
        #expect(results[1].deadline != nil)
        #expect(results[1].category == "Personal")

        // Task 3: Tập thể dục
        #expect(results[2].title.lowercased().contains("tập thể dục"))
        #expect(results[2].recurrence == "3x_weekly")
        #expect(results[2].category == "Health & Routine")
    }

    @Test func testExactHourVietnameseParsing() {
        let parser = DeterministicCaptureParser()
        let input = "Họp với Nam lúc 15h30 ngày mai gấp"
        let results = parser.parse(text: input)

        #expect(results.count == 1)
        #expect(results[0].priority == .urgent)
        #expect(results[0].deadline != nil)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: results[0].deadline!)
        let min = calendar.component(.minute, from: results[0].deadline!)
        #expect(hour == 15)
        #expect(min == 30)
    }

    @Test func testTomorrowAppointmentWithDotTime() {
        let parser = DeterministicCaptureParser()
        // Wednesday Nov 25, 2026 at 18:00 (after 8:30)
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 11
        comp.day = 25
        comp.hour = 18
        comp.minute = 0
        let calendar = Calendar(identifier: .gregorian)
        let refDate = calendar.date(from: comp)!

        let input = "Mai hẹn lúc 8.30"
        let results = parser.parse(text: input, referenceDate: refDate)

        #expect(results.count == 1)
        let item = results[0]
        #expect(item.deadline != nil)
        guard let deadline = item.deadline else { return }

        // Must be tomorrow (Nov 26, 2026), NOT today (Nov 25), and hour 8, min 30
        let day = calendar.component(.day, from: deadline)
        let hour = calendar.component(.hour, from: deadline)
        let minute = calendar.component(.minute, from: deadline)

        #expect(day == 26)
        #expect(hour == 8)
        #expect(minute == 30)
        #expect(deadline > refDate) // Must not be overdue!
        #expect(item.category == "Meeting")
        #expect(item.itemType == .event)
    }

    @Test func testEventVsTaskItemTypeDetection() {
        let parser = DeterministicCaptureParser()

        // Event: hẹn, họp, meeting
        let eventResults = parser.parse(text: "Mai hẹn lúc 8.30 gặp Nam")
        #expect(!eventResults.isEmpty)
        #expect(eventResults[0].itemType == .event)

        let meetingResults = parser.parse(text: "Họp dự án lúc 14h")
        #expect(!meetingResults.isEmpty)
        #expect(meetingResults[0].itemType == .event)

        // Task: nhắc, mua, hoàn thành
        let taskResults = parser.parse(text: "Nhắc mua sữa lúc 18h tối nay")
        #expect(!taskResults.isEmpty)
        #expect(taskResults[0].itemType == .task)

        let reportResults = parser.parse(text: "Hoàn thành báo cáo trước 17h")
        #expect(!reportResults.isEmpty)
        #expect(reportResults[0].itemType == .task)
    }
}

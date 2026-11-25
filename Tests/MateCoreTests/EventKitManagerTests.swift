import Testing
import Foundation
@testable import MateCore

@Suite("EventKitManagerTests")
struct EventKitManagerTests {

    @Test func testMockEventKitSync() async throws {
        let now = Date()
        let event1 = TimeBlock(
            title: "Client Sync",
            startTime: now,
            endTime: now.addingTimeInterval(3600),
            isLocked: true
        )

        let mock = MockEventKitManager(stubbedEvents: [event1])

        let hasAccess = try await mock.requestCalendarAccess()
        #expect(hasAccess == true)

        let fetched = try await mock.fetchEvents(
            from: now.addingTimeInterval(-60),
            to: now.addingTimeInterval(7200)
        )
        #expect(fetched.count == 1)
        #expect(fetched[0].title == "Client Sync")
        #expect(fetched[0].isLocked == true)

        let newBlock = TimeBlock(
            title: "Focus Block: Presentation",
            startTime: now.addingTimeInterval(3600),
            endTime: now.addingTimeInterval(7200)
        )

        let eventId = try await mock.createCalendarEvent(from: newBlock)
        #expect(eventId.contains("mock-event-"))
        #expect(mock.createdEvents.count == 1)
        #expect(mock.createdEvents[0].title == "Focus Block: Presentation")
    }
}

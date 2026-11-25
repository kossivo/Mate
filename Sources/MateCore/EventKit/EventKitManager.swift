import Foundation
import EventKit

public protocol EventKitManaging: Sendable {
    func requestCalendarAccess() async throws -> Bool
    func requestRemindersAccess() async throws -> Bool
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [TimeBlock]
    func createCalendarEvent(from block: TimeBlock) async throws -> String
    func removeCalendarEvent(externalId: String) async throws -> Bool
}

public final class EventKitManager: EventKitManaging, @unchecked Sendable {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func requestCalendarAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    public func requestRemindersAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await eventStore.requestFullAccessToReminders()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    public func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [TimeBlock] {
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents.map { ekEvent in
            TimeBlock(
                id: UUID(),
                taskId: nil,
                title: ekEvent.title ?? "Calendar Commitment",
                startTime: ekEvent.startDate,
                endTime: ekEvent.endDate,
                isLocked: true, // External calendar events are locked by default
                category: "Calendar"
            )
        }
    }

    public func createCalendarEvent(from block: TimeBlock) async throws -> String {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = block.title
        ekEvent.startDate = block.startTime
        ekEvent.endDate = block.endTime
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(ekEvent, span: .thisEvent)
        return ekEvent.eventIdentifier ?? UUID().uuidString
    }

    public func removeCalendarEvent(externalId: String) async throws -> Bool {
        guard let ekEvent = eventStore.event(withIdentifier: externalId) else {
            return false
        }
        try eventStore.remove(ekEvent, span: .thisEvent)
        return true
    }
}

/// In-memory mock for automated headless testing without requiring OS user prompts.
public final class MockEventKitManager: EventKitManaging, @unchecked Sendable {
    public var stubbedEvents: [TimeBlock] = []
    public var createdEvents: [TimeBlock] = []
    public var shouldGrantAccess: Bool = true

    public init(stubbedEvents: [TimeBlock] = []) {
        self.stubbedEvents = stubbedEvents
    }

    public func requestCalendarAccess() async throws -> Bool {
        return shouldGrantAccess
    }

    public func requestRemindersAccess() async throws -> Bool {
        return shouldGrantAccess
    }

    public func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [TimeBlock] {
        return stubbedEvents.filter { $0.endTime > startDate && $0.startTime < endDate }
    }

    public func createCalendarEvent(from block: TimeBlock) async throws -> String {
        createdEvents.append(block)
        return "mock-event-\(block.id.uuidString)"
    }

    public func removeCalendarEvent(externalId: String) async throws -> Bool {
        return true
    }
}

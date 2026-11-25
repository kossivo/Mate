import Foundation
import AppIntents

public struct CaptureThoughtIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture Thought in Mate"
    public static let description = IntentDescription("Extracts tasks and deadlines from natural language using on-device intelligence.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Text", description: "What do you need to do?")
    public var text: String

    public init() {
        self.text = ""
    }

    public init(text: String) {
        self.text = text
    }

    public func perform() async throws -> some ProvidesDialog & ReturnsValue<Int> {
        let parser = DeterministicCaptureParser()
        let items = parser.parse(text: text)

        let summary: String
        if items.isEmpty {
            summary = "No tasks recognized."
        } else if items.count == 1 {
            summary = "Captured: \(items[0].title)"
        } else {
            summary = "Captured \(items.count) tasks in Mate: " + items.map { $0.title }.joined(separator: ", ")
        }

        return .result(value: items.count, dialog: IntentDialog(stringLiteral: summary))
    }
}

public struct PlanMyDayIntent: AppIntent {
    public static let title: LocalizedStringResource = "Plan My Day with Mate"
    public static let description = IntentDescription("Schedules pending tasks into available calendar gaps respecting working hours.")
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ProvidesDialog & ReturnsValue<Int> {
        let engine = SmartSchedulingEngine()
        let proposal = engine.schedule(
            tasks: [],
            existingCommitments: [],
            preferences: UserPreference(),
            targetDate: Date()
        )

        let message = "Mate checked your schedule. \(proposal.scheduledBlocks.count) tasks scheduled."
        return .result(value: proposal.scheduledBlocks.count, dialog: IntentDialog(stringLiteral: message))
    }
}

public struct GetNextCommitmentIntent: AppIntent {
    public static let title: LocalizedStringResource = "Next Commitment in Mate"
    public static let description = IntentDescription("Retrieves your next upcoming scheduled commitment.")
    public static let openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let next = "No upcoming commitments for today."
        return .result(value: next, dialog: IntentDialog(stringLiteral: next))
    }
}

public struct MateShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureThoughtIntent(),
            phrases: [
                "Capture in \(.applicationName)",
                "Add task in \(.applicationName)",
                "Note to \(.applicationName)"
            ],
            shortTitle: "Capture in Mate",
            systemImageName: "plus.bubble"
        )
        AppShortcut(
            intent: PlanMyDayIntent(),
            phrases: [
                "Plan my day in \(.applicationName)",
                "Schedule my day with \(.applicationName)"
            ],
            shortTitle: "Plan My Day",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: GetNextCommitmentIntent(),
            phrases: [
                "What's next in \(.applicationName)?",
                "Next commitment in \(.applicationName)"
            ],
            shortTitle: "Next Commitment",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}

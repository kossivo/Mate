import Testing
import Foundation
@testable import MateCore

@Suite("AppIntentsTests")
struct AppIntentsTests {

    @Test func testCaptureThoughtIntentExecution() async throws {
        let intent = CaptureThoughtIntent(text: "Call Doctor tomorrow and buy groceries")
        let result = try await intent.perform()

        #expect(result.value == 2)
    }

    @Test func testPlanMyDayIntentExecution() async throws {
        let intent = PlanMyDayIntent()
        let result = try await intent.perform()

        #expect((result.value ?? -1) >= 0)
    }

    @Test func testShortcutsProviderPhrases() {
        let shortcuts = MateShortcutsProvider.appShortcuts
        #expect(shortcuts.count == 3)
    }
}

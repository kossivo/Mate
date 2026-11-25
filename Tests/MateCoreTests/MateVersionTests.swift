import Testing
@testable import MateCore

@Test func testVersion() {
    #expect(MateVersion.appName == "Mate")
    #expect(MateVersion.version == "1.0.0")
}

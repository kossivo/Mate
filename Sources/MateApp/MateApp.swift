import SwiftUI
#if canImport(MateCore)
import MateCore
#endif

@main
public struct MateApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

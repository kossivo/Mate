import SwiftUI
#if canImport(MateCore)
import MateCore
#endif

@main
public struct MateApp: App {
    public init() {
        #if canImport(MateCore)
        #if DEBUG || targetEnvironment(simulator)
        StoreKitManager.shared.setWhitelisted(true)
        #endif
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.locale, Locale(identifier: "en_US"))
        }
    }
}

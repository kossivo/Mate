import SwiftUI
#if canImport(MateCore)
import MateCore
#endif

@main
public struct MateApp: App {
    public init() {
        #if canImport(MateCore)
        StoreKitManager.shared.setWhitelisted(true)
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

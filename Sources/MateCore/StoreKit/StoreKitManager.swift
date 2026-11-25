import Foundation
import StoreKit

public enum MateTier: String, Codable, Sendable {
    case free
    case premium
}

public protocol StoreKitManaging: Sendable {
    func isPremiumUnlocked() async -> Bool
    func restorePurchases() async throws -> Bool
}

public final class StoreKitManager: StoreKitManaging, @unchecked Sendable {
    public static let shared = StoreKitManager()

    // Configurable product identifiers to support either Non-Consumable or Auto-Renewable subscription
    public static let nonConsumablePremiumId = "com.mate.app.premium.lifetime"
    public static let monthlySubscriptionId = "com.mate.app.subscription.monthly"
    public static let yearlySubscriptionId = "com.mate.app.subscription.yearly"

    private var cachedStatus: MateTier = .free

    /// Whitelist status for simulator and developer testing devices
    public var isWhitelisted: Bool {
        #if DEBUG || targetEnvironment(simulator)
        return true
        #else
        return UserDefaults.standard.bool(forKey: "com.mate.isProWhitelisted")
        #endif
    }

    public var isPro: Bool {
        if isWhitelisted { return true }
        return cachedStatus == .premium
    }

    public init() {
        // Automatically persist whitelist for developer testing and simulator environments
        #if DEBUG || targetEnvironment(simulator)
        UserDefaults.standard.set(true, forKey: "com.mate.isProWhitelisted")
        cachedStatus = .premium
        #else
        if UserDefaults.standard.bool(forKey: "com.mate.isProWhitelisted") {
            cachedStatus = .premium
        }
        #endif
    }

    public func setWhitelisted(_ whitelisted: Bool) {
        UserDefaults.standard.set(whitelisted, forKey: "com.mate.isProWhitelisted")
        if whitelisted {
            cachedStatus = .premium
        } else {
            cachedStatus = .free
        }
    }

    public func isPremiumUnlocked() async -> Bool {
        if isWhitelisted {
            cachedStatus = .premium
            return true
        }

        // In StoreKit 2, iterate over currentEntitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    if transaction.productID == Self.nonConsumablePremiumId ||
                       transaction.productID == Self.monthlySubscriptionId ||
                       transaction.productID == Self.yearlySubscriptionId {
                        cachedStatus = .premium
                        return true
                    }
                }
            }
        }
        return false
    }

    public func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        return await isPremiumUnlocked()
    }
}

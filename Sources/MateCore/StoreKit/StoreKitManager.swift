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
    // Configurable product identifiers to support either Non-Consumable or Auto-Renewable subscription
    public static let nonConsumablePremiumId = "com.mate.app.premium.lifetime"
    public static let monthlySubscriptionId = "com.mate.app.subscription.monthly"
    public static let yearlySubscriptionId = "com.mate.app.subscription.yearly"

    private var cachedStatus: MateTier = .free

    public init() {}

    public func isPremiumUnlocked() async -> Bool {
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

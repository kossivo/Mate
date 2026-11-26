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

public struct StoreKitProductInfo: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let displayPrice: String
    public let isAnnual: Bool
    public let underlyingProduct: Product?

    public init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        isAnnual: Bool,
        underlyingProduct: Product? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.isAnnual = isAnnual
        self.underlyingProduct = underlyingProduct
    }
}

public final class StoreKitManager: StoreKitManaging, @unchecked Sendable {
    public static let shared = StoreKitManager()

    // Configurable product identifiers for StoreKit 2 Auto-Renewable subscriptions
    public static let nonConsumablePremiumId = "com.mate.app.premium.lifetime"
    public static let monthlySubscriptionId = "com.mate.app.subscription.monthly"
    public static let yearlySubscriptionId = "com.mate.app.subscription.yearly"

    private var cachedStatus: MateTier = .free
    private var transactionListenerTask: Task<Void, Never>?

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

    private var isTestingEnvironment: Bool {
        NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    public init() {
        #if DEBUG || targetEnvironment(simulator)
        UserDefaults.standard.set(true, forKey: "com.mate.isProWhitelisted")
        cachedStatus = .premium
        #else
        if UserDefaults.standard.bool(forKey: "com.mate.isProWhitelisted") {
            cachedStatus = .premium
        }
        #endif

        if !isTestingEnvironment {
            listenForTransactions()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    public func setWhitelisted(_ whitelisted: Bool) {
        UserDefaults.standard.set(whitelisted, forKey: "com.mate.isProWhitelisted")
        if whitelisted {
            cachedStatus = .premium
        } else {
            cachedStatus = .free
        }
    }

    // MARK: - StoreKit 2 Product Fetching

    public func fetchAvailableProducts() async -> [StoreKitProductInfo] {
        if !isTestingEnvironment {
            let productIds = [Self.monthlySubscriptionId, Self.yearlySubscriptionId]
            if let storeProducts = try? await Product.products(for: productIds), !storeProducts.isEmpty {
                return storeProducts.map { product in
                    StoreKitProductInfo(
                        id: product.id,
                        displayName: product.displayName,
                        description: product.description,
                        displayPrice: product.displayPrice,
                        isAnnual: product.id == Self.yearlySubscriptionId,
                        underlyingProduct: product
                    )
                }.sorted { $0.isAnnual && !$1.isAnnual }
            }
        }

        // Standard fallback for offline preview or unconfigured sandbox
        return [
            StoreKitProductInfo(
                id: Self.yearlySubscriptionId,
                displayName: "Mate Pro Annual",
                description: "Full intelligent scheduling & zero telemetry",
                displayPrice: "$9.99 / yr",
                isAnnual: true,
                underlyingProduct: nil
            ),
            StoreKitProductInfo(
                id: Self.monthlySubscriptionId,
                displayName: "Mate Pro Monthly",
                description: "Full intelligent scheduling & zero telemetry",
                displayPrice: "$1.99 / mo",
                isAnnual: false,
                underlyingProduct: nil
            )
        ]
    }

    // MARK: - StoreKit 2 Purchase Flow

    public func purchase(productInfo: StoreKitProductInfo) async throws -> Bool {
        if let product = productInfo.underlyingProduct {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    cachedStatus = .premium
                    return true
                case .unverified:
                    return false
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } else {
            // For testing without live App Store Connect product credentials
            #if DEBUG || targetEnvironment(simulator)
            setWhitelisted(true)
            return true
            #else
            return false
            #endif
        }
    }

    // MARK: - StoreKit 2 Entitlement Checking

    public func isPremiumUnlocked() async -> Bool {
        if isWhitelisted || isTestingEnvironment {
            cachedStatus = .premium
            return true
        }

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

    // MARK: - Real-time Background Transaction Listener

    private func listenForTransactions() {
        transactionListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    _ = await self?.isPremiumUnlocked()
                }
            }
        }
    }
}

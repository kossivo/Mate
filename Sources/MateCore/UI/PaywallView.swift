import SwiftUI
import StoreKit

public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var products: [StoreKitProductInfo] = []
    @State private var selectedIndex: Int = 0 // 0: Annual, 1: Monthly
    @State private var isProcessing: Bool = false
    @State private var showingRestoreAlert: Bool = false
    @State private var restoreMessage: String = ""
    @State private var errorMessage: String? = nil

    private let storeKit = StoreKitManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                MateTheme.pureBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: storeKit.isPro ? "checkmark.seal.fill" : "sparkles")
                                .font(.system(size: 46))
                                .foregroundStyle(storeKit.isPro ? Color.green : MateTheme.opticWhite)

                            Text(storeKit.isPro ? "Mate Pro Unlocked" : "Unlock Mate Pro")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(MateTheme.opticWhite)

                            Text(storeKit.isWhitelisted ? "This device is verified with complete access to intelligent scheduling, natural language capture, and zero-telemetry calendar automation." : "Empower your daily productivity with intelligent time-blocking and automated calendar orchestration.")
                                .font(.subheadline)
                                .foregroundStyle(MateTheme.silverMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 16)

                        // Value Features Card
                        VStack(alignment: .leading, spacing: 14) {
                            FeatureRow(icon: "brain.head.profile", title: "Smart Scheduling Engine", description: "Auto-slots tasks into open calendar gaps without overlaps.")
                            FeatureRow(icon: "text.bubble", title: "Universal Natural Language Capture", description: "Captures multi-task thoughts instantly in English & Vietnamese.")
                            FeatureRow(icon: "rectangle.3.group", title: "Interactive Widgets & Siri", description: "Glance at next commitments right from Lock Screen & Home Screen.")
                            FeatureRow(icon: "lock.shield", title: "Zero Telemetry & 100% On-Device", description: "Your calendar and personal data never leave your physical iPhone.")
                        }
                        .padding(18)
                        .background(MateTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MateTheme.microBorder, lineWidth: 1))
                        .padding(.horizontal)

                        // Plan Selector
                        if products.isEmpty {
                            ProgressView()
                                .tint(MateTheme.opticWhite)
                                .padding()
                        } else {
                            HStack(spacing: 12) {
                                ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                    PlanCard(
                                        title: product.isAnnual ? "Annual" : "Monthly",
                                        price: product.displayPrice,
                                        badge: product.isAnnual ? "SAVE 58% + 7D FREE" : nil,
                                        isSelected: selectedIndex == index
                                    ) {
                                        selectedIndex = index
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color.red)
                                .padding(.horizontal)
                        }

                        // Subscribe CTA
                        VStack(spacing: 12) {
                            Button {
                                executePurchase()
                            } label: {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .tint(MateTheme.pureBlack)
                                    } else {
                                        Text(currentIsAnnual ? "Start 7-Day Free Trial" : "Subscribe Now")
                                            .font(.headline.bold())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(MateTheme.opticWhite)
                                .foregroundStyle(MateTheme.pureBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isProcessing || products.isEmpty)

                            HStack(spacing: 16) {
                                Button("Restore Purchases") {
                                    restorePurchases()
                                }
                                .font(.caption)
                                .foregroundStyle(MateTheme.silverMuted)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(MateTheme.slateDim)

                                Link("Terms of Service", destination: URL(string: "https://mateapp.local/terms")!)
                                    .font(.caption)
                                    .foregroundStyle(MateTheme.silverMuted)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(MateTheme.slateDim)

                                Link("Privacy Policy", destination: URL(string: "https://mateapp.local/privacy")!)
                                    .font(.caption)
                                    .foregroundStyle(MateTheme.silverMuted)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MateTheme.pureBlack, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(MateTheme.silverMuted)
                }
            }
            .task {
                products = await storeKit.fetchAvailableProducts()
            }
            .alert("Purchases Restored", isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage)
            }
        }
    }

    private var currentIsAnnual: Bool {
        guard selectedIndex < products.count else { return true }
        return products[selectedIndex].isAnnual
    }

    private func executePurchase() {
        guard selectedIndex < products.count else { return }
        let selectedProduct = products[selectedIndex]
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let success = try await storeKit.purchase(productInfo: selectedProduct)
                await MainActor.run {
                    isProcessing = false
                    if success {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Purchase could not be completed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func restorePurchases() {
        isProcessing = true
        Task {
            do {
                let unlocked = try await storeKit.restorePurchases()
                await MainActor.run {
                    isProcessing = false
                    restoreMessage = unlocked ? "Welcome back! Your Mate Pro subscription is active." : "No prior subscriptions were found for this Apple ID."
                    showingRestoreAlert = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    restoreMessage = "Restore failed: \(error.localizedDescription)"
                    showingRestoreAlert = true
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(MateTheme.opticWhite)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(MateTheme.opticWhite)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(MateTheme.silverMuted)
            }
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(MateTheme.opticWhite)
                        .foregroundStyle(MateTheme.pureBlack)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 18)
                }
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(MateTheme.opticWhite)
                Text(price)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? MateTheme.opticWhite : MateTheme.silverMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(isSelected ? MateTheme.cardBackground : MateTheme.elevatedCard)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? MateTheme.opticWhite : MateTheme.microBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

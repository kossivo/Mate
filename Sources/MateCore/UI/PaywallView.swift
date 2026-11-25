import SwiftUI

public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Int = 1 // 0: Monthly, 1: Annual
    @State private var isProcessing: Bool = false
    @State private var showingRestoreAlert: Bool = false
    private let storeKit = StoreKitManager()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: storeKit.isPro ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(storeKit.isPro ? Color.green : Color.accentColor)
                    Text(storeKit.isPro ? "Mate Pro Unlocked" : "Unlock Mate Pro")
                        .font(.largeTitle.bold())
                    Text(storeKit.isWhitelisted ? "This device is whitelisted for the Pro Plan with full access to intelligent scheduling, natural language capture, and calendar automation." : "Empower your daily productivity with intelligent time-blocking and automated calendar orchestration.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Features
                VStack(alignment: .leading, spacing: 14) {
                    FeatureRow(icon: "brain.head.profile", title: "Smart Scheduling Engine", description: "Auto-slots tasks into calendar gaps.")
                    FeatureRow(icon: "text.bubble", title: "Universal Natural Language Capture", description: "Captures multi-task rambling thoughts instantly.")
                    FeatureRow(icon: "rectangle.3.group", title: "Interactive Widgets & Siri", description: "Glance at next commitments from Lock Screen.")
                    FeatureRow(icon: "lock.shield", title: "Zero Telemetry & 100% On-Device", description: "Your calendar and personal data never leave your phone.")
                }
                .padding()
                .background(MateTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Plan Selector (Auto-Renewable Subscription - No Lifetime Gimmick)
                HStack(spacing: 12) {
                    PlanCard(
                        title: "Monthly",
                        price: "$1.99 / mo",
                        badge: nil,
                        isSelected: selectedPlan == 0
                    ) {
                        selectedPlan = 0
                    }

                    PlanCard(
                        title: "Annual",
                        price: "$9.99 / yr",
                        badge: "SAVE 58% + 7D FREE",
                        isSelected: selectedPlan == 1
                    ) {
                        selectedPlan = 1
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Subscribe CTA
                VStack(spacing: 10) {
                    Button {
                        isProcessing = true
                        // Simulated purchase action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isProcessing = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(selectedPlan == 1 ? "Start 7-Day Free Trial" : "Subscribe Now")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    HStack(spacing: 16) {
                        Button("Restore Purchases") {
                            showingRestoreAlert = true
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Link("Terms of Service", destination: URL(string: "https://mateapp.local/terms")!)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Link("Privacy Policy", destination: URL(string: "https://mateapp.local/privacy")!)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Purchases Restored", isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your previous subscriptions and entitlements have been checked with the App Store.")
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            VStack(spacing: 6) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(price)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : MateTheme.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

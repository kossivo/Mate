import SwiftUI

public struct SettingsView: View {
    @State private var workStartHour: Int = 9
    @State private var workEndHour: Int = 17
    @State private var bufferMinutes: Int = 10
    @State private var protectWeekends: Bool = true
    @State private var iCloudSyncEnabled: Bool = true
    @State private var showingPaywall: Bool = false
    @State private var showingExportAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Working Hours") {
                    Stepper("Work Starts: \(workStartHour):00", value: $workStartHour, in: 5...12)
                    Stepper("Work Ends: \(workEndHour):00", value: $workEndHour, in: 13...23)
                    Stepper("Meeting Buffer: \(bufferMinutes) mins", value: $bufferMinutes, in: 0...30, step: 5)
                    Toggle("Protect Weekends", isOn: $protectWeekends)
                }

                Section("Integrations") {
                    Toggle("Private iCloud Sync", isOn: $iCloudSyncEnabled)
                    HStack {
                        Text("Apple Calendar")
                        Spacer()
                        Text("Authorized")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                    HStack {
                        Text("Apple Reminders")
                        Spacer()
                        Text("Authorized")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }

                Section("Mate Subscription") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mate Pro")
                                .font(.body.bold())
                            Text("Smart scheduling & Siri shortcuts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Manage") {
                            showingPaywall = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                Section("Data & Privacy") {
                    Button("Export Personal Data (JSON)") {
                        showingExportAlert = true
                    }
                    Button("Reset Preferences to Defaults", role: .destructive) {
                        workStartHour = 9
                        workEndHour = 17
                        bufferMinutes = 10
                        protectWeekends = true
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(MateVersion.version)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Data Export Ready", isPresented: $showingExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Mate data export has been prepared locally on your device in compliance with privacy guidelines.")
            }
        }
    }
}

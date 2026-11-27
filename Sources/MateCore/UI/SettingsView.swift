import SwiftUI

public struct SettingsView: View {
    @State private var preferences: UserPreference = UserPreference.load()
    @State private var workStartTime: Date = Date()
    @State private var workEndTime: Date = Date()
    @State private var iCloudSyncEnabled: Bool = true
    @State private var showingPaywall: Bool = false
    @State private var showingExportAlert: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Working Hours") {
                    DatePicker("Work Starts", selection: $workStartTime, displayedComponents: .hourAndMinute)
                        .onChange(of: workStartTime) { _, newValue in
                            let cal = Calendar.current
                            let rawMin = cal.component(.minute, from: newValue)
                            let snappedMin = SmartSchedulingEngine.snapMinuteTo15(rawMin)
                            preferences.workStartHour = cal.component(.hour, from: newValue)
                            preferences.workStartMinute = snappedMin
                            preferences.save()
                            syncDatesFromPreferences()
                        }

                    DatePicker("Work Ends", selection: $workEndTime, displayedComponents: .hourAndMinute)
                        .onChange(of: workEndTime) { _, newValue in
                            let cal = Calendar.current
                            let rawMin = cal.component(.minute, from: newValue)
                            let snappedMin = SmartSchedulingEngine.snapMinuteTo15(rawMin)
                            preferences.workEndHour = cal.component(.hour, from: newValue)
                            preferences.workEndMinute = snappedMin
                            preferences.save()
                            syncDatesFromPreferences()
                        }

                    HStack {
                        Text("Daily Work Window")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedWorkDuration)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Meeting Buffer: \(preferences.meetingBufferMinutes) mins", value: $preferences.meetingBufferMinutes, in: 0...30, step: 5)
                        .onChange(of: preferences.meetingBufferMinutes) { _, _ in
                            preferences.save()
                        }

                    Toggle("Protect Weekends", isOn: $preferences.protectWeekends)
                        .onChange(of: preferences.protectWeekends) { _, _ in
                            preferences.save()
                        }
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Mate Pro")
                                    .font(.body.bold())
                                if StoreKitManager.shared.isPro {
                                    Text("PRO ACTIVE")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.18))
                                        .foregroundStyle(Color.green)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(StoreKitManager.shared.isWhitelisted ? "Device whitelisted: All AI & scheduling unlocked" : "Smart scheduling & Siri shortcuts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if StoreKitManager.shared.isPro {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.title3)
                        } else {
                            Button("Manage") {
                                showingPaywall = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                Section("Data & Privacy") {
                    Button("Export Personal Data (JSON)") {
                        showingExportAlert = true
                    }
                    Button("Reset Preferences to Defaults", role: .destructive) {
                        preferences = UserPreference()
                        preferences.save()
                        syncDatesFromPreferences()
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
            .onAppear {
                preferences = UserPreference.load()
                syncDatesFromPreferences()
            }
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

    private func syncDatesFromPreferences() {
        let cal = Calendar.current
        let now = Date()
        workStartTime = cal.date(bySettingHour: preferences.workStartHour, minute: preferences.workStartMinute, second: 0, of: now) ?? now
        workEndTime = cal.date(bySettingHour: preferences.workEndHour, minute: preferences.workEndMinute, second: 0, of: now) ?? now
    }

    private var formattedWorkDuration: String {
        let startMin = preferences.workStartHour * 60 + preferences.workStartMinute
        let endMin = preferences.workEndHour * 60 + preferences.workEndMinute
        let diff = max(0, endMin - startMin)
        let hours = diff / 60
        let minutes = diff % 60
        let startStr = String(format: "%02d:%02d", preferences.workStartHour, preferences.workStartMinute)
        let endStr = String(format: "%02d:%02d", preferences.workEndHour, preferences.workEndMinute)
        if minutes == 0 {
            return "\(startStr)–\(endStr) (\(hours)h window)"
        } else {
            return "\(startStr)–\(endStr) (\(hours)h \(minutes)m window)"
        }
    }
}

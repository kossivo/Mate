import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(0)

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
    }
}

public struct InboxView: View {
    @State private var inboxTasks: [TaskItem] = [
        TaskItem(title: "Confirm dentist appointment", estimatedDuration: 900, priority: .medium, status: .inbox),
        TaskItem(title: "Research flights to Tokyo", estimatedDuration: 1800, priority: .low, status: .inbox)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Unscheduled & Ambiguous Items") {
                    ForEach(inboxTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.body.bold())
                            HStack {
                                Label("\(Int(task.estimatedDuration / 60)) mins", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Needs review")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Inbox")
        }
    }
}

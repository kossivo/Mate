import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sparkles")
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
        .tint(MateTheme.opticWhite)
    }
}

public struct InboxView: View {
    @State private var inboxTasks: [TaskItem] = []

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                MateTheme.pureBlack.ignoresSafeArea()

                Group {
                    if inboxTasks.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "tray")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(MateTheme.slateDim)
                            Text("Inbox Zero")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(MateTheme.opticWhite)
                            Text("Tasks that require further review or lack a clear deadline will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(MateTheme.silverMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            Section {
                                ForEach(inboxTasks) { task in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.body.bold())
                                            .foregroundStyle(MateTheme.opticWhite)
                                        HStack {
                                            Label("\(Int(task.estimatedDuration / 60)) mins", systemImage: "clock")
                                                .font(.caption)
                                                .foregroundStyle(MateTheme.slateDim)
                                            Spacer()
                                            Text("Needs review")
                                                .font(.caption2.bold())
                                                .foregroundStyle(Color.orange)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(MateTheme.cardBackground)
                                }
                            } header: {
                                Text("Unscheduled Items")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(MateTheme.silverMuted)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Inbox")
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
        }
    }
}

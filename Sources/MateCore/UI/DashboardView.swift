import SwiftUI

public enum DashboardScope: String, CaseIterable, Identifiable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case week = "This Week"

    public var id: String { rawValue }
}

public struct DashboardView: View {
    @ObservedObject private var store = DataManager.shared
    @State private var selectedScope: DashboardScope = .today
    @State private var showingCaptureSheet: Bool = false
    @State private var showingScannerSheet: Bool = false
    @State private var showingNotesSheet: Bool = false
    @State private var showingSuggestFreeTimeSheet: Bool = false
    @State private var showingPlanSheet: Bool = false
    @State private var toastBanner: String? = nil

    private let calendar = Calendar.current
    private let availabilityEngine = AvailabilityEngine()

    private var tasks: [TaskItem] {
        get { store.tasks }
        nonmutating set { store.tasks = newValue }
    }
    private var scheduledBlocks: [TimeBlock] {
        get { store.scheduledBlocks }
        nonmutating set { store.scheduledBlocks = newValue }
    }

    public init(
        initialTasks: [TaskItem] = [],
        initialBlocks: [TimeBlock] = []
    ) {
        if !initialTasks.isEmpty {
            DataManager.shared.tasks = initialTasks
        }
        if !initialBlocks.isEmpty {
            DataManager.shared.scheduledBlocks = initialBlocks
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Scope Segmented Control
                        scopeSegmentedPicker
                            .padding(.horizontal)
                            .padding(.top, 4)

                        // Metric Summary Strip
                        summaryMetricsCard
                            .padding(.horizontal)

                        // Smart Action Bar
                        smartActionBar
                            .padding(.horizontal)

                        // Schedule Timeline Section with Free Windows
                        scheduleSection
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 80)
                }

                // Bottom Trailing Capture Orb & Toast
                VStack(alignment: .trailing, spacing: 12) {
                    if let toast = toastBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(toast)
                                .font(.caption.bold())
                                .foregroundStyle(MateTheme.opticWhite)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(MateTheme.elevatedCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    captureOrb
                }
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Schedule")
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingNotesSheet = true
                        } label: {
                            Label("Quick Notes & Scratchpad", systemImage: "note.text")
                        }
                        Button {
                            showingPlanSheet = true
                        } label: {
                            Label("Optimize Schedule", systemImage: "sparkles")
                        }
                        Button {
                            showingSuggestFreeTimeSheet = true
                        } label: {
                            Label("Suggest Free Time", systemImage: "clock.badge.checkmark")
                        }
                        Button {
                            showingScannerSheet = true
                        } label: {
                            Label("Scan Document / Card", systemImage: "doc.viewfinder")
                        }
                    } label: {
                        Image(systemName: "note.text")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(MateTheme.opticWhite)
                    } primaryAction: {
                        showingNotesSheet = true
                    }
                    .accessibilityLabel("Schedule Assistant Menu")
                }
            }
            .sheet(isPresented: $showingNotesSheet) {
                NotesView(
                    onAddTask: { newTask in
                        store.addTask(newTask)
                    },
                    onAddEvent: { newBlock in
                        store.addBlock(newBlock)
                    }
                )
            }
            .sheet(isPresented: $showingCaptureSheet) {
                UniversalCaptureView(
                    onSaveTask: { newTask in
                        store.addTask(newTask)
                    },
                    onSaveEvent: { newEvent in
                        store.addBlock(newEvent)
                    }
                )
            }
            .sheet(isPresented: $showingPlanSheet) {
                PlanView(tasks: tasks, existingBlocks: scheduledBlocks) { proposal in
                    store.applyProposal(proposal, targetDate: targetDateForScope)
                    withAnimation {
                        toastBanner = "✓ Schedule optimized (\(proposal.scheduledBlocks.count) tasks planned)"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { toastBanner = nil }
                    }
                }
            }
            .sheet(isPresented: $showingScannerSheet) {
                DocumentScannerView(
                    onAddContactOrTask: { scannedTask in
                        store.addTask(scannedTask)
                    },
                    onAddEvent: { scannedEvent in
                        store.addBlock(scannedEvent)
                    }
                )
            }
            .sheet(isPresented: $showingSuggestFreeTimeSheet) {
                SuggestFreeTimeSheet(
                    tasks: $store.tasks,
                    scheduledBlocks: $store.scheduledBlocks,
                    targetDate: targetDateForScope,
                    onScheduleMeeting: { newBlock in
                        store.addBlock(newBlock)
                    }
                )
            }
            .task {
                await syncData(promptIfNeeded: false)
            }
            .refreshable {
                await syncData(promptIfNeeded: true)
            }
        }
    }

    // MARK: - Components

    private var captureOrb: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            showingCaptureSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MateTheme.pureBlack)
                .frame(width: 52, height: 52)
                .background(MateTheme.opticWhite)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick Capture")
    }

    private var scopeSegmentedPicker: some View {
        HStack(spacing: 6) {
            ForEach(DashboardScope.allCases) { scope in
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.rawValue)
                        .font(.system(size: 13, weight: selectedScope == scope ? .bold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedScope == scope ? MateTheme.elevatedCard : Color.clear)
                        .foregroundStyle(selectedScope == scope ? MateTheme.opticWhite : MateTheme.slateDim)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedScope == scope ? MateTheme.microBorder : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
        )
    }

    private var summaryMetricsCard: some View {
        let events = eventsForSelectedScope
        let calendarEvents = events.filter { $0.isLocked && !$0.isAllDay }.count
        let plannedSessions = events.filter { !$0.isLocked && !$0.isAllDay }.count
        let remainingTasks = tasksForSelectedScope.filter { $0.status != .completed }.count

        return HStack(spacing: 12) {
            metricItem(title: "Commitments", value: "\(calendarEvents)", icon: "calendar", color: .indigo)
            Divider().frame(height: 28).background(MateTheme.hairlineDivider)
            metricItem(title: "Planned Focus", value: "\(plannedSessions)", icon: "sparkles", color: .blue)
            Divider().frame(height: 28).background(MateTheme.hairlineDivider)
            metricItem(title: "Pending Tasks", value: "\(remainingTasks)", icon: "checklist", color: .orange)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MateTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MateTheme.cornerRadius)
                .stroke(MateTheme.microBorder, lineWidth: 1)
        )
    }

    private var smartActionBar: some View {
        HStack(spacing: 10) {
            Button {
                showingSuggestFreeTimeSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(Color.yellow)
                    Text("Free Windows")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(MateTheme.cardBackground)
                .foregroundStyle(MateTheme.opticWhite)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                showingPlanSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(MateTheme.assistantPulse)
                    Text("Optimize Day")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(MateTheme.cardBackground)
                .foregroundStyle(MateTheme.opticWhite)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var targetDateForScope: Date {
        switch selectedScope {
        case .today:
            return Date()
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case .week:
            return Date()
        }
    }

    private func metricItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.opticWhite)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MateTheme.silverMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        let filteredEvents = eventsForSelectedScope
        let allDayEvents = filteredEvents.filter { $0.isAllDay }
        let timedEvents = filteredEvents.filter { !$0.isAllDay }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedScope == .week ? "WEEKLY TIMELINE" : "DAILY TIMELINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                Text("\(filteredEvents.count) items")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }

            // All-Day events banner if any
            if !allDayEvents.isEmpty {
                VStack(spacing: 6) {
                    ForEach(allDayEvents) { event in
                        HStack(spacing: 8) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.orange)
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MateTheme.opticWhite)
                            Spacer()
                            Text("All Day")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.orange)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                    }
                }
            }

            if timedEvents.isEmpty && allDayEvents.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(MateTheme.slateDim)
                    Text("No scheduled commitments for this period.")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else if !timedEvents.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(timedEvents.enumerated()), id: \.element.id) { index, block in
                        if index > 0 {
                            Divider()
                                .background(MateTheme.hairlineDivider)
                                .padding(.leading, 70)
                        }
                        eventRow(block)
                    }
                }
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                )
            }
        }
    }

    private func eventRow(_ block: TimeBlock) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 1) {
                if selectedScope == .week {
                    Text(block.startTime.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "en_US"))))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(MateTheme.silverMuted)
                }
                Text(block.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.opticWhite)
                Text(block.endTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }
            .frame(width: selectedScope == .week ? 64 : 55, alignment: .trailing)

            Rectangle()
                .fill(block.isLocked ? MateTheme.opticWhite : MateTheme.assistantPulse)
                .frame(width: 2.5, height: 26)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(Int(block.duration / 60))m")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MateTheme.slateDim)

                    if let cat = block.category {
                        Text(cat)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(MateTheme.silverMuted)
                    }
                }
            }
            Spacer()
            if block.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(MateTheme.slateDim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Filtering Data by Scope

    private var tasksForSelectedScope: [TaskItem] {
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
            return tasks
        }

        switch selectedScope {
        case .today:
            return tasks.filter { task in
                guard let d = task.deadline else { return true }
                return d >= startOfToday && d < startOfTomorrow
            }
        case .tomorrow:
            return tasks.filter { task in
                guard let d = task.deadline else { return false }
                return d >= startOfTomorrow && d < startOfDayAfter
            }
        case .week:
            return tasks.filter { task in
                guard let d = task.deadline else { return true }
                return d >= startOfToday && d < endOfWeek
            }
        }
    }

    private var eventsForSelectedScope: [TimeBlock] {
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
            return scheduledBlocks
        }

        switch selectedScope {
        case .today:
            return scheduledBlocks
                .filter { $0.startTime >= startOfToday && $0.startTime < startOfTomorrow }
                .sorted { $0.startTime < $1.startTime }
        case .tomorrow:
            return scheduledBlocks
                .filter { $0.startTime >= startOfTomorrow && $0.startTime < startOfDayAfter }
                .sorted { $0.startTime < $1.startTime }
        case .week:
            return scheduledBlocks
                .filter { $0.startTime >= startOfToday && $0.startTime < endOfWeek }
                .sorted { $0.startTime < $1.startTime }
        }
    }

    @MainActor
    private func syncData(promptIfNeeded: Bool = false) async {
        await store.syncWithEventKit(promptIfNeeded: promptIfNeeded)
    }
}

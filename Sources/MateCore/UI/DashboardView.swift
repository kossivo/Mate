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
    @State private var toastBanner: String? = nil

    private let calendar = Calendar.current

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
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Scope Picker
                        scopeSegmentedPicker
                            .padding(.horizontal)
                            .padding(.top, 4)

                        // Metric summary card
                        summaryMetricsCard
                            .padding(.horizontal)

                        // Tasks to be done section
                        tasksSection
                            .padding(.horizontal)

                        // Scheduled commitments section
                        scheduleSection
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 90)
                }

                // Bottom Quick Add Button & Toast
                VStack(spacing: 8) {
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

                    quickAddBar
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Dashboard")
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
                            showingScannerSheet = true
                        } label: {
                            Label("Scan Business Card / Doc", systemImage: "doc.viewfinder")
                        }
                        Button {
                            showingSuggestFreeTimeSheet = true
                        } label: {
                            Label("Suggest Free Time", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "note.text")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(MateTheme.opticWhite)
                    } primaryAction: {
                        showingNotesSheet = true
                    }
                    .accessibilityLabel("Notes and Scanner")
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
                        .padding(.vertical, 9)
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
        let filteredTasks = tasksForSelectedScope
        let remainingTasks = filteredTasks.filter { $0.status != .completed }.count
        let completedTasks = filteredTasks.filter { $0.status == .completed }.count
        let eventsCount = eventsForSelectedScope.count

        return HStack(spacing: 12) {
            metricItem(title: "To Do", value: "\(remainingTasks)", icon: "checklist", color: .orange)
            Divider().frame(height: 32).background(MateTheme.microBorder)
            metricItem(title: "Events", value: "\(eventsCount)", icon: "calendar", color: .indigo)
            Divider().frame(height: 32).background(MateTheme.microBorder)
            metricItem(title: "Done", value: "\(completedTasks)", icon: "checkmark.circle.fill", color: .green)
        }
        .padding(.vertical, 16)
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
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.yellow)
                    Text("Suggest Free Time")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(MateTheme.elevatedCard)
                .foregroundStyle(MateTheme.opticWhite)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                reallocateByPriority()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down.square.fill")
                        .foregroundStyle(Color.blue)
                    Text("Sort by Priority")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(MateTheme.elevatedCard)
                .foregroundStyle(MateTheme.opticWhite)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func reallocateByPriority() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        let engine = SmartSchedulingEngine()
        let result = engine.reallocateTasksByPriority(
            tasks: tasks,
            existingCommitments: scheduledBlocks,
            preferences: UserPreference.load(),
            targetDate: targetDateForScope
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.tasks = result.reallocatedTasks
            store.applyProposal(result.proposal)
            toastBanner = "✓ Schedule prioritized (Urgent → High → Med → Low)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                toastBanner = nil
            }
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
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.opticWhite)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MateTheme.silverMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        let filteredTasks = tasksForSelectedScope
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                if !filteredTasks.isEmpty {
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.sortTasksByPriority()
                            toastBanner = "✓ Sorted by priority (Urgent → Low)"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { toastBanner = nil }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("Sort")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(MateTheme.silverMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(MateTheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Text("\(filteredTasks.filter { $0.status != .completed }.count) pending")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }
            if filteredTasks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(MateTheme.slateDim)
                    Text("No pending tasks. You are in total control.")
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
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                        if index > 0 {
                            Divider()
                                .background(MateTheme.microBorder.opacity(0.6))
                                .padding(.leading, 42)
                        }
                        taskRow(task)
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

    private func taskRow(_ task: TaskItem) -> some View {
        let isDone = task.status == .completed
        return HStack(spacing: 12) {
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.toggleTaskCompletion(task)
                }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isDone ? MateTheme.opticWhite : MateTheme.slateDim)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? MateTheme.slateDim : MateTheme.opticWhite)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let d = task.deadline {
                        Label(d.formatted(date: selectedScope == .week ? .abbreviated : .omitted, time: .shortened), systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(isDone ? MateTheme.slateDim : Color.red.opacity(0.85))
                    }

                    if let cat = task.category {
                        Text(cat)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.silverMuted)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.updateTaskPriority(taskId: task.id, priority: p)
                        }
                    } label: {
                        Label(p.title, systemImage: p.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(MateTheme.priorityColor(task.priority))
                        .frame(width: 6, height: 6)
                    Text(task.priority.title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(MateTheme.priorityColor(task.priority))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(MateTheme.elevatedCard)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        let filteredEvents = eventsForSelectedScope
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SCHEDULE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                Text("\(filteredEvents.count) items")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }

            if filteredEvents.isEmpty {
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
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, block in
                        if index > 0 {
                            Divider()
                                .background(MateTheme.microBorder.opacity(0.6))
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
                if block.isAllDay {
                    Text("All Day")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(block.category == "Holiday" ? Color.orange : MateTheme.opticWhite)
                } else {
                    Text(block.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(MateTheme.opticWhite)
                    Text(block.endTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MateTheme.slateDim)
                }
            }
            .frame(width: selectedScope == .week ? 64 : 55, alignment: .trailing)

            Rectangle()
                .fill(block.isAllDay ? (block.category == "Holiday" ? Color.orange : MateTheme.silverMuted) : (block.isLocked ? MateTheme.opticWhite : MateTheme.slateDim))
                .frame(width: 2.5, height: 26)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !block.isAllDay {
                        Text("\(Int(block.duration / 60))m")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(MateTheme.slateDim)
                    }

                    if let cat = block.category {
                        Text(cat)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(cat == "Holiday" ? Color.orange : MateTheme.silverMuted)
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

    // MARK: - Quick Add Floating Island

    private var quickAddBar: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            showingCaptureSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Capture")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MateTheme.silverMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MateTheme.elevatedCard.opacity(0.95))
            .foregroundStyle(MateTheme.opticWhite)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(MateTheme.microBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
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

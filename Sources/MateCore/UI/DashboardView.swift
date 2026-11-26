import SwiftUI

public enum DashboardScope: String, CaseIterable, Identifiable {
    case today = "Today"
    case tomorrow = "Tomorrow"
    case week = "This Week"

    public var id: String { rawValue }
}

public struct DashboardView: View {
    @State private var selectedScope: DashboardScope = .today
    @State private var tasks: [TaskItem] = []
    @State private var scheduledBlocks: [TimeBlock] = []
    @State private var showingCaptureSheet: Bool = false
    @State private var showingScannerSheet: Bool = false
    @State private var showingNotesSheet: Bool = false
    @State private var showingSuggestFreeTimeSheet: Bool = false
    @State private var toastBanner: String? = nil

    private let calendar = Calendar.current

    public init(
        initialTasks: [TaskItem] = [],
        initialBlocks: [TimeBlock] = []
    ) {
        _tasks = State(initialValue: initialTasks)
        _scheduledBlocks = State(initialValue: initialBlocks)
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

                        // Smart Assistant Quick Actions
                        smartActionBar
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
                        tasks.append(newTask)
                        NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                    },
                    onAddEvent: { newBlock in
                        scheduledBlocks.append(newBlock)
                        scheduledBlocks.sort { $0.startTime < $1.startTime }
                    }
                )
            }
            .sheet(isPresented: $showingCaptureSheet) {
                UniversalCaptureView(
                    onSaveTask: { newTask in
                        tasks.append(newTask)
                        NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                    },
                    onSaveEvent: { newEvent in
                        scheduledBlocks.append(newEvent)
                    }
                )
            }
            .sheet(isPresented: $showingScannerSheet) {
                DocumentScannerView(
                    onAddContactOrTask: { scannedTask in
                        tasks.append(scannedTask)
                    },
                    onAddEvent: { scannedEvent in
                        scheduledBlocks.append(scannedEvent)
                    }
                )
            }
            .sheet(isPresented: $showingSuggestFreeTimeSheet) {
                SuggestFreeTimeSheet(
                    tasks: $tasks,
                    scheduledBlocks: $scheduledBlocks,
                    targetDate: targetDateForScope,
                    onScheduleMeeting: { newBlock in
                        scheduledBlocks.append(newBlock)
                        scheduledBlocks.sort { $0.startTime < $1.startTime }
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
            preferences: UserPreference(),
            targetDate: targetDateForScope
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            tasks = result.reallocatedTasks
            for block in result.proposal.scheduledBlocks {
                if !scheduledBlocks.contains(where: { $0.title == block.title }) {
                    scheduledBlocks.append(block)
                }
            }
            scheduledBlocks.sort { $0.startTime < $1.startTime }
            toastBanner = "✓ Schedule optimized by priority"
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TASKS TO DO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                Text("\(tasksForSelectedScope.filter { $0.status != .completed }.count) tasks")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }

            let filteredTasks = tasksForSelectedScope
            if filteredTasks.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(MateTheme.silverMuted)
                    Text("No pending tasks. You are in total control of your time!")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredTasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        let isDone = task.status == .completed
        return HStack(spacing: 14) {
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[idx].status = isDone ? .planned : .completed
                    NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isDone ? MateTheme.opticWhite : MateTheme.slateDim)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.bold())
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? MateTheme.slateDim : MateTheme.opticWhite)

                HStack(spacing: 8) {
                    if let d = task.deadline {
                        Label(d.formatted(date: selectedScope == .week ? .abbreviated : .omitted, time: .shortened), systemImage: "clock")
                            .font(.caption2.bold())
                            .foregroundStyle(isDone ? MateTheme.slateDim : MateTheme.silverMuted)
                    }

                    if let cat = task.category {
                        Text(cat)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.silverMuted)
                            .clipShape(Capsule())
                    }

                    if task.priority == .urgent || task.priority == .high {
                        Text(task.priority == .urgent ? "Urgent" : "High")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
        )
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SCHEDULE & MEETINGS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                Text("\(eventsForSelectedScope.count) items")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }

            let filteredEvents = eventsForSelectedScope
            if filteredEvents.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(MateTheme.silverMuted)
                    Text("No scheduled commitments for this period.")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredEvents) { block in
                        eventRow(block)
                    }
                }
            }
        }
    }

    private func eventRow(_ block: TimeBlock) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                if selectedScope == .week {
                    Text(block.startTime.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "en_US"))))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(MateTheme.silverMuted)
                }
                if block.isAllDay {
                    Text("All Day")
                        .font(.caption.bold())
                        .foregroundStyle(block.category == "Holiday" ? Color.orange : MateTheme.opticWhite)
                } else {
                    Text(block.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption.bold())
                        .foregroundStyle(MateTheme.opticWhite)
                    Text(block.endTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(MateTheme.slateDim)
                }
            }
            .frame(width: selectedScope == .week ? 66 : 56, alignment: .trailing)

            Rectangle()
                .fill(block.isAllDay ? (block.category == "Holiday" ? Color.orange : MateTheme.silverMuted) : (block.isLocked ? MateTheme.opticWhite : MateTheme.slateDim))
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(MateTheme.opticWhite)

                HStack(spacing: 6) {
                    if !block.isAllDay {
                        Text("\(Int(block.duration / 60)) mins")
                            .font(.caption2)
                            .foregroundStyle(MateTheme.slateDim)
                    }

                    if let cat = block.category {
                        Text(cat)
                            .font(.caption2)
                            .foregroundStyle(cat == "Holiday" ? Color.orange : MateTheme.silverMuted)
                    }

                    if block.isLocked && !block.isAllDay {
                        Label("Calendar", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(MateTheme.slateDim)
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
        )
    }

    // MARK: - Quick Add Floating Island

    private var quickAddBar: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            showingCaptureSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("Quick Add Task or Event")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MateTheme.silverMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(MateTheme.elevatedCard.opacity(0.95))
            .foregroundStyle(MateTheme.opticWhite)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(MateTheme.microBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 16, x: 0, y: 8)
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
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) else { return }

        let isCalAuthorized = EventKitManager.shared.isCalendarAuthorized
        if isCalAuthorized || promptIfNeeded {
            if let granted = try? await EventKitManager.shared.requestCalendarAccess(), granted {
                if let events = try? await EventKitManager.shared.fetchEvents(from: startOfToday, to: endOfWeek) {
                    let existingTitles = Set(scheduledBlocks.map { $0.title })
                    let newEvents = events.filter { !existingTitles.contains($0.title) }
                    scheduledBlocks.append(contentsOf: newEvents)
                }
            }
        }

        let isRemAuthorized = EventKitManager.shared.isRemindersAuthorized
        if isRemAuthorized || promptIfNeeded {
            if let grantedReminders = try? await EventKitManager.shared.requestRemindersAccess(), grantedReminders {
                if let reminders = try? await EventKitManager.shared.fetchReminders() {
                    let taskTitles = Set(tasks.map { $0.title })
                    let newTasks = reminders.filter { !taskTitles.contains($0.title) }
                    tasks.append(contentsOf: newTasks)
                    NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                }
            }
        }
    }
}

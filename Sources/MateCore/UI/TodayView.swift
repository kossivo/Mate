import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct TodayView: View {
    @ObservedObject private var store = DataManager.shared
    @State private var showingCaptureSheet: Bool = false
    @State private var showingPlanSheet: Bool = false
    @State private var showingSuggestFreeTimeSheet: Bool = false
    @State private var showingShareAvailabilitySheet: Bool = false
    @State private var showingScannerSheet: Bool = false
    @State private var showingNotesSheet: Bool = false
    @State private var showingCompletedTasks: Bool = false
    @State private var availabilityMessage: String = ""
    @State private var toastBanner: String? = nil

    private let availabilityEngine = AvailabilityEngine()
    private let schedulingEngine = SmartSchedulingEngine()

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
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        heroCommitmentCard.padding(.horizontal)
                        prioritiesSection.padding(.horizontal)
                        timelineSection.padding(.horizontal)
                    }
                    .padding(.bottom, 80)
                }

                // Floating Bottom Trailing Capture Orb
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    toolbarMenu
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
                    store.applyProposal(proposal)
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
                    targetDate: Date(),
                    onScheduleMeeting: { newBlock in
                        store.addBlock(newBlock)
                    }
                )
            }
            .sheet(isPresented: $showingShareAvailabilitySheet) {
                ShareAvailabilitySheet(message: availabilityMessage)
            }
            .task {
                await syncWithCalendarAndReminders(promptIfNeeded: false)
            }
            .refreshable {
                await syncWithCalendarAndReminders(promptIfNeeded: true)
            }
        }
    }

    // MARK: - Subviews

    private var toolbarMenu: some View {
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
                Label("Scan Card / Document", systemImage: "doc.viewfinder")
            }
            Button {
                generateAvailability()
                showingShareAvailabilitySheet = true
            } label: {
                Label("Share Free Time", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "note.text")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MateTheme.opticWhite)
        } primaryAction: {
            showingNotesSheet = true
        }
        .accessibilityLabel("Assistant Menu")
    }

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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day().locale(Locale(identifier: "en_US"))).uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(MateTheme.silverMuted)

            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(MateTheme.opticWhite)
                Spacer()
                if !tasks.isEmpty {
                    let completed = tasks.filter { $0.status == .completed }.count
                    Text("\(completed) of \(tasks.count) done")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(MateTheme.silverMuted)
                }
            }

            HStack(spacing: 8) {
                Text(briefingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(MateTheme.silverMuted)

                if let holiday = allDayBlocks.first {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(holiday.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(Color.orange)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var timedCommitments: [TimeBlock] {
        scheduledBlocks.filter { !$0.isAllDay }
    }

    private var allDayBlocks: [TimeBlock] {
        scheduledBlocks.filter { $0.isAllDay }
    }

    @ViewBuilder
    private var heroCommitmentCard: some View {
        let now = Date()
        let activeBlock = timedCommitments.first(where: { $0.startTime <= now && $0.endTime > now })
        let nextBlock = timedCommitments.first(where: { $0.startTime > now })

        if let hero = activeBlock ?? nextBlock {
            let isCurrent = activeBlock != nil
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isCurrent ? Color.green : MateTheme.assistantPulse)
                            .frame(width: 7, height: 7)
                        Text(isCurrent ? "HAPPENING NOW" : "NEXT UP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(isCurrent ? Color.green : MateTheme.assistantPulse)
                    }
                    Spacer()
                    Text(hero.startTime.formatted(date: .omitted, time: .shortened) + " – " + hero.endTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MateTheme.opticWhite)
                }

                Text(hero.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let cat = hero.category {
                        Text(cat)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.silverMuted)
                            .clipShape(Capsule())
                    }
                    if hero.isLocked {
                        Label("Calendar Event", systemImage: "lock.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(MateTheme.slateDim)
                    } else {
                        Label("Focus Session", systemImage: "sparkles")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(MateTheme.assistantPulse)
                    }
                }
            }
            .padding(16)
            .background(MateTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: MateTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: MateTheme.cornerRadius)
                    .stroke(MateTheme.microBorder, lineWidth: 1)
            )
        } else {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.green.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Schedule Clear")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MateTheme.opticWhite)
                    Text("No upcoming meetings today. Prime time for deep work.")
                        .font(.system(size: 12))
                        .foregroundStyle(MateTheme.silverMuted)
                }
                Spacer()
            }
            .padding(14)
            .background(MateTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MateTheme.microBorder, lineWidth: 1)
            )
        }
    }

    private var pendingTasks: [TaskItem] {
        tasks.filter { $0.status != .completed }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.status == .completed }
    }

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TOP PRIORITIES")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                if !tasks.isEmpty {
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
            }

            if tasks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(MateTheme.slateDim)
                    Text("No pending tasks. You are in total flow.")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    if pendingTasks.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("All tasks completed for today!")
                                .font(.subheadline.bold())
                                .foregroundStyle(MateTheme.opticWhite)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(pendingTasks.enumerated()), id: \.element.id) { index, task in
                            if index > 0 {
                                Divider()
                                    .background(MateTheme.hairlineDivider)
                                    .padding(.leading, 46)
                            }
                            taskRow(task: task)
                        }
                    }

                    // Collapsible completed tasks section
                    if !completedTasks.isEmpty {
                        Divider().background(MateTheme.hairlineDivider)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingCompletedTasks.toggle()
                            }
                        } label: {
                            HStack {
                                Text("\(completedTasks.count) completed today")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(MateTheme.slateDim)
                                Spacer()
                                Image(systemName: showingCompletedTasks ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(MateTheme.slateDim)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if showingCompletedTasks {
                            ForEach(completedTasks) { task in
                                Divider().background(MateTheme.hairlineDivider).padding(.leading, 46)
                                completedTaskRow(task: task)
                            }
                        }
                    }
                }
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MateTheme.microBorder, lineWidth: 1)
                )
            }
        }
    }

    private func taskRow(task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.toggleTaskCompletion(task)
                    NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(MateTheme.slateDim)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let deadline = task.deadline {
                        Text("Due " + deadline.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }
                    Text("\(Int(task.estimatedDuration / 60))m")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MateTheme.slateDim)
                }
            }

            Spacer()

            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.updateTaskPriority(taskId: task.id, priority: p)
                        }
                    } label: {
                        Label(p.title, systemImage: p.iconName)
                    }
                }
            } label: {
                jewelPriorityBadge(for: task.priority)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func completedTaskRow(task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.toggleTaskCompletion(task)
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MateTheme.opticWhite.opacity(0.6))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 13))
                .strikethrough()
                .foregroundStyle(MateTheme.slateDim)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func jewelPriorityBadge(for priority: TaskPriority) -> some View {
        switch priority {
        case .urgent:
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                Text("URGENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(MateTheme.priorityColor(.urgent))
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(MateTheme.elevatedCard)
            .clipShape(Capsule())

        case .high:
            HStack(spacing: 4) {
                Circle()
                    .fill(MateTheme.priorityColor(.high))
                    .frame(width: 6, height: 6)
                Text("HIGH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(MateTheme.priorityColor(.high))
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(MateTheme.elevatedCard)
            .clipShape(Capsule())

        case .medium:
            HStack(spacing: 4) {
                Circle()
                    .fill(MateTheme.opticWhite)
                    .frame(width: 5, height: 5)
                Text("MED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(MateTheme.silverMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(MateTheme.elevatedCard)
            .clipShape(Capsule())

        case .low:
            HStack(spacing: 4) {
                Circle()
                    .stroke(MateTheme.slateDim, lineWidth: 1)
                    .frame(width: 5, height: 5)
                Text("LOW")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(MateTheme.slateDim)
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(MateTheme.elevatedCard)
            .clipShape(Capsule())
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S SCHEDULE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                Button {
                    showingPlanSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.yellow)
                        Text("Optimize")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MateTheme.opticWhite)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(MateTheme.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if timedCommitments.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(MateTheme.slateDim)
                    Text("No scheduled meetings. Open focus time available.")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(timedCommitments.enumerated()), id: \.element.id) { index, block in
                        if index > 0 {
                            Divider()
                                .background(MateTheme.hairlineDivider)
                                .padding(.leading, 70)
                        }
                        timelineRow(block: block)
                    }
                }
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MateTheme.microBorder, lineWidth: 1)
                )
            }
        }
    }

    private func timelineRow(block: TimeBlock) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(block.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.opticWhite)
                Text(block.endTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }
            .frame(width: 55, alignment: .trailing)

            Rectangle()
                .fill(block.isLocked ? MateTheme.opticWhite : MateTheme.assistantPulse)
                .frame(width: 2.5, height: 26)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(1)
                Text("\(Int(block.duration / 60))m")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
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

    @MainActor
    private func syncWithCalendarAndReminders(promptIfNeeded: Bool = false) async {
        await store.syncWithEventKit(promptIfNeeded: promptIfNeeded)
    }

    private var isEvening: Bool {
        Calendar.current.component(.hour, from: Date()) >= 17
    }

    private var briefingStatusText: String {
        let meetings = scheduledBlocks.filter { $0.isLocked && !$0.isAllDay }.count
        let remaining = tasks.filter { $0.status != .completed }.count
        if isEvening {
            let completed = tasks.filter { $0.status == .completed }.count
            return "\(completed) completed · \(remaining) pending"
        } else {
            let meetingWord = meetings == 1 ? "commitment" : "commitments"
            let taskWord = remaining == 1 ? "task" : "tasks"
            if meetings == 0 && remaining == 0 {
                return "Clear schedule · All tasks done"
            } else if meetings == 0 {
                return "\(remaining) \(taskWord) pending"
            } else {
                return "\(meetings) \(meetingWord) · \(remaining) \(taskWord) pending"
            }
        }
    }

    private func generateAvailability() {
        let slots = availabilityEngine.findAvailableSlots(
            durationMinutes: 45,
            existingCommitments: scheduledBlocks,
            preferences: UserPreference.load(),
            targetDate: Date(),
            maxSlots: 3
        )
        availabilityMessage = availabilityEngine.formatInvitationMessage(slots: slots, guestName: nil, locale: "en")
    }
}


public struct SuggestFreeTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding public var tasks: [TaskItem]
    @Binding public var scheduledBlocks: [TimeBlock]
    public let targetDate: Date
    public let onScheduleMeeting: (TimeBlock) -> Void

    @State private var selectedTab: Int = 0 // 0: Free Windows, 1: Smart Suggestions
    @State private var toastBanner: String? = nil

    private let availabilityEngine = AvailabilityEngine()
    private let schedulingEngine = SmartSchedulingEngine()

    public init(
        tasks: Binding<[TaskItem]>,
        scheduledBlocks: Binding<[TimeBlock]>,
        targetDate: Date = Date(),
        onScheduleMeeting: @escaping (TimeBlock) -> Void = { _ in }
    ) {
        self._tasks = tasks
        self._scheduledBlocks = scheduledBlocks
        self.targetDate = targetDate
        self.onScheduleMeeting = onScheduleMeeting
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.yellow)
                    Text("Smart Schedule Assistant")
                        .font(.title2.bold())
                        .foregroundStyle(MateTheme.opticWhite)
                    Text("Intelligently analyzes your schedule to recommend prime focus windows, resolve conflicts, and reallocate tasks by priority.")
                        .font(.caption)
                        .foregroundStyle(MateTheme.silverMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                // Segmented Tab Picker
                pickerSection

                // Content
                ScrollView {
                    VStack(spacing: 14) {
                        if selectedTab == 0 {
                            freeSlotsSection
                        } else {
                            smartSuggestionsSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }

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
                    .padding(.bottom, 8)
                }
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Schedule Assistant")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(MateTheme.opticWhite)
                }
            }
        }
    }

    private var pickerSection: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { selectedTab = 0 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                    Text("Free Windows")
                }
                .font(.system(size: 13, weight: selectedTab == 0 ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 0 ? MateTheme.elevatedCard : Color.clear)
                .foregroundStyle(selectedTab == 0 ? MateTheme.opticWhite : MateTheme.slateDim)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTab == 0 ? MateTheme.microBorder : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { selectedTab = 1 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                    Text("Smart Suggestions")
                }
                .font(.system(size: 13, weight: selectedTab == 1 ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 1 ? MateTheme.elevatedCard : Color.clear)
                .foregroundStyle(selectedTab == 1 ? MateTheme.opticWhite : MateTheme.slateDim)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTab == 1 ? MateTheme.microBorder : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var freeSlotsSection: some View {
        let suggestions = availabilityEngine.suggestOptimalSlots(
            existingCommitments: scheduledBlocks,
            preferences: UserPreference.load(),
            targetDate: targetDate,
            maxSlots: 4
        )

        return Group {
            if suggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 38))
                        .foregroundStyle(MateTheme.silverMuted)
                    Text("Today's schedule is fully booked")
                        .font(.subheadline.bold())
                        .foregroundStyle(MateTheme.opticWhite)
                    Text("No open slots longer than 30 minutes during work hours. Maximize your focus on existing commitments.")
                        .font(.caption)
                        .foregroundStyle(MateTheme.slateDim)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1))
            } else {
                ForEach(suggestions) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(item.type.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badgeColor(for: item.type).opacity(0.2))
                                .foregroundStyle(badgeColor(for: item.type))
                                .clipShape(Capsule())

                            Spacer()

                            Text("\(Int(item.slot.duration / 60)) mins")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(MateTheme.silverMuted)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.slot.startTime.formatted(date: .omitted, time: .shortened)) – \(item.slot.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.title3.bold())
                                .foregroundStyle(MateTheme.opticWhite)

                            Text(item.subtitle)
                                .font(.caption)
                                .lineSpacing(2)
                                .foregroundStyle(MateTheme.silverMuted)
                        }

                        Divider().background(MateTheme.microBorder)

                        HStack(spacing: 10) {
                            Button {
                                scheduleMeetingInSlot(item.slot)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("Schedule Meeting")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(MateTheme.opticWhite)
                                .foregroundStyle(MateTheme.pureBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            Button {
                                assignPriorityTaskToSlot(item.slot)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checklist")
                                    Text("Assign Focus Task")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(MateTheme.elevatedCard)
                                .foregroundStyle(MateTheme.opticWhite)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MateTheme.microBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(MateTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1))
                }
            }
        }
    }

    private var smartSuggestionsSection: some View {
        let smartSuggestions = availabilityEngine.generateSmartSuggestions(
            tasks: tasks,
            existingCommitments: scheduledBlocks,
            preferences: UserPreference.load(),
            targetDate: targetDate
        )

        return Group {
            if smartSuggestions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.green)
                    Text("Schedule is optimally organized")
                        .font(.subheadline.bold())
                        .foregroundStyle(MateTheme.opticWhite)
                    Text("No conflicts detected. Urgent tasks are scheduled or assigned reminders.")
                        .font(.caption)
                        .foregroundStyle(MateTheme.slateDim)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1))
            } else {
                ForEach(smartSuggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: suggestion.iconName)
                                .font(.system(size: 18))
                                .foregroundStyle(suggestionColor(for: suggestion.kind))
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(MateTheme.opticWhite)
                                Text(suggestion.detail)
                                    .font(.caption)
                                    .lineSpacing(2)
                                    .foregroundStyle(MateTheme.silverMuted)
                            }
                        }

                        Button {
                            applySmartSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 6) {
                                Text(suggestion.actionTitle)
                                    .font(.caption.bold())
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.opticWhite)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MateTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MateTheme.microBorder, lineWidth: 1))
                }
            }
        }
    }

    private func badgeColor(for type: FreeSlotType) -> Color {
        switch type {
        case .focusDeepWork: return .orange
        case .meetingWindow: return .blue
        case .quickCatchup: return .purple
        case .buffer: return .green
        }
    }

    private func suggestionColor(for kind: SuggestionKind) -> Color {
        switch kind {
        case .freeTime: return .yellow
        case .scheduleMeeting: return .blue
        case .reschedule: return .orange
        case .reminder: return .red
        case .reallocatePriority: return .purple
        }
    }

    private func scheduleMeetingInSlot(_ slot: FreeSlot) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        let newBlock = TimeBlock(
            title: "New Meeting",
            startTime: slot.startTime,
            endTime: slot.endTime,
            isLocked: true,
            category: "Meeting"
        )
        onScheduleMeeting(newBlock)
        withAnimation {
            toastBanner = "✓ Scheduled meeting at \(slot.startTime.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func assignPriorityTaskToSlot(_ slot: FreeSlot) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        let topTask = tasks.first { $0.status != .completed }
        let title = topTask?.title ?? "Deep Focus Session"
        let newBlock = TimeBlock(
            taskId: topTask?.id,
            title: title,
            startTime: slot.startTime,
            endTime: slot.endTime,
            isLocked: false,
            category: topTask?.category ?? "Deep Work"
        )
        onScheduleMeeting(newBlock)
        withAnimation {
            toastBanner = "✓ Scheduled '\(title)' at \(slot.startTime.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func applySmartSuggestion(_ suggestion: SmartSuggestion) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        switch suggestion.kind {
        case .scheduleMeeting:
            if let start = suggestion.suggestedStartTime, let end = suggestion.suggestedEndTime {
                let task = tasks.first { $0.id == suggestion.targetTaskId }
                let newBlock = TimeBlock(
                    taskId: task?.id,
                    title: task?.title ?? "Meeting",
                    startTime: start,
                    endTime: end,
                    isLocked: true,
                    category: "Meeting"
                )
                onScheduleMeeting(newBlock)
                withAnimation { toastBanner = "✓ Scheduled: \(newBlock.title)" }
            }

        case .reschedule:
            if let blockId = suggestion.targetBlockId, let newStart = suggestion.suggestedStartTime, let newEnd = suggestion.suggestedEndTime {
                if let idx = scheduledBlocks.firstIndex(where: { $0.id == blockId }) {
                    scheduledBlocks[idx].startTime = newStart
                    scheduledBlocks[idx].endTime = newEnd
                    scheduledBlocks.sort { $0.startTime < $1.startTime }
                    withAnimation { toastBanner = "✓ Rescheduled to \(newStart.formatted(date: .omitted, time: .shortened))" }
                }
            } else if let newStart = suggestion.suggestedStartTime {
                for i in 0..<tasks.count where tasks[i].status != .completed {
                    tasks[i].deadline = newStart
                }
                withAnimation { toastBanner = "✓ Deferred pending tasks to tomorrow morning" }
            }

        case .reminder:
            if let taskId = suggestion.targetTaskId, let task = tasks.first(where: { $0.id == taskId }) {
                let reminderDate = suggestion.suggestedStartTime ?? Date().addingTimeInterval(15 * 60)
                NotificationManager.shared.scheduleTaskReminder(title: task.title, reminderDate: reminderDate, id: taskId)
                withAnimation { toastBanner = "✓ Reminder set: \(task.title)" }
            }

        case .reallocatePriority:
            let result = schedulingEngine.reallocateTasksByPriority(
                tasks: tasks,
                existingCommitments: scheduledBlocks,
                preferences: UserPreference.load(),
                targetDate: targetDate
            )
            tasks = result.reallocatedTasks
            let existingLocked = scheduledBlocks.filter { $0.isLocked || $0.isAllDay }
            let newPlanned = result.proposal.scheduledBlocks.filter { block in
                !existingLocked.contains { $0.title == block.title && $0.startTime == block.startTime }
            }
            scheduledBlocks = (existingLocked + newPlanned).sorted { $0.startTime < $1.startTime }
            withAnimation { toastBanner = "✓ Schedule prioritized (Urgent → High → Med → Low)" }

        case .freeTime:
            if let start = suggestion.suggestedStartTime, let end = suggestion.suggestedEndTime {
                scheduleMeetingInSlot(FreeSlot(startTime: start, endTime: end))
            }
        }
    }
}

public struct ShareAvailabilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    public let message: String
    @State private var copied: Bool = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                    Text("Your Available Times")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Calculated from open gaps in your calendar. Ready to send via Zalo, iMessage, or Email.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text(message)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MateTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(MateTheme.microBorder, lineWidth: 1)
                    )
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    ShareLink(item: message) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share via Messages / Apps")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MateTheme.opticWhite)
                        .foregroundStyle(MateTheme.pureBlack)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = message
                        #elseif canImport(AppKit)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message, forType: .string)
                        #endif
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied to Clipboard!" : "Copy Availability Message")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : MateTheme.elevatedCard)
                        .foregroundStyle(copied ? Color.white : MateTheme.silverMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Share Free Time")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

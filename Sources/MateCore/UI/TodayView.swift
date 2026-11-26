import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct TodayView: View {
    @State private var tasks: [TaskItem]
    @State private var scheduledBlocks: [TimeBlock]
    @State private var showingCaptureSheet: Bool = false
    @State private var showingPlanSheet: Bool = false
    @State private var showingSuggestFreeTimeSheet: Bool = false
    @State private var showingShareAvailabilitySheet: Bool = false
    @State private var showingScannerSheet: Bool = false
    @State private var showingNotesSheet: Bool = false
    @State private var availabilityMessage: String = ""
    @State private var toastBanner: String? = nil

    private let availabilityEngine = AvailabilityEngine()
    private let schedulingEngine = SmartSchedulingEngine()

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
                    VStack(alignment: .leading, spacing: 22) {
                        headerSection
                        dayArcTimeline.padding(.horizontal)
                        briefingCard.padding(.horizontal)
                        nextCommitmentCard.padding(.horizontal)
                        prioritiesSection.padding(.horizontal)
                        timelineSection.padding(.horizontal)
                    }
                    .padding(.bottom, 110)
                }

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

                    floatingActionIsland
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
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
            .sheet(isPresented: $showingPlanSheet) {
                PlanView(tasks: tasks, existingBlocks: scheduledBlocks) { proposal in
                    scheduledBlocks = proposal.scheduledBlocks
                }
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
                    targetDate: Date(),
                    onScheduleMeeting: { newBlock in
                        scheduledBlocks.append(newBlock)
                        scheduledBlocks.sort { $0.startTime < $1.startTime }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day().locale(Locale(identifier: "en_US"))).uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(MateTheme.silverMuted)
            Text("Today's Overview")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(MateTheme.opticWhite)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var dayArcTimeline: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DAY CADENCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
                Spacer()
                Text("08:00 — 20:00")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }
            GeometryReader { geo in
                let currentHour = Calendar.current.component(.hour, from: Date())
                let clampedHour = min(max(currentHour, 8), 20)
                let progress = CGFloat(clampedHour - 8) / 12.0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MateTheme.elevatedCard)
                        .frame(height: 6)

                    Capsule()
                        .fill(MateTheme.opticWhite)
                        .frame(width: max(geo.size.width * progress, 8), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(greetingText, systemImage: isEvening ? "moon.stars.fill" : "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(isEvening ? Color.indigo : Color.white)
                Spacer()
                Text("\(tasks.filter { $0.status == .completed }.count) / \(tasks.count) Done")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MateTheme.elevatedCard)
                    .foregroundStyle(MateTheme.opticWhite)
                    .clipShape(Capsule())
            }

            Text(briefingSummary)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(MateTheme.opticWhite.opacity(0.9))

            HStack(spacing: 8) {
                Button {
                    showingSuggestFreeTimeSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.yellow)
                        Text("Suggest Free Time")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MateTheme.elevatedCard)
                    .foregroundStyle(MateTheme.opticWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    reallocateTasksByPriority()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.arrow.down.square.fill")
                            .foregroundStyle(Color.blue)
                        Text("Sort by Priority")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MateTheme.elevatedCard)
                    .foregroundStyle(MateTheme.opticWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MateTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MateTheme.cornerRadius)
                .stroke(MateTheme.microBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var nextCommitmentCard: some View {
        if let next = scheduledBlocks.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Next Up", systemImage: "clock.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(MateTheme.silverMuted)
                    Spacer()
                    Text(next.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MateTheme.opticWhite)
                }
                Text(next.title)
                    .font(.title3.bold())
                    .foregroundStyle(MateTheme.opticWhite)
                HStack {
                    Text(next.category ?? "General")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MateTheme.elevatedCard)
                        .foregroundStyle(MateTheme.silverMuted)
                        .clipShape(Capsule())
                    if next.isLocked {
                        Label("Calendar Event", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(MateTheme.slateDim)
                    }
                }
            }
            .padding(18)
            .background(MateTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: MateTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: MateTheme.cornerRadius)
                    .stroke(MateTheme.microBorder, lineWidth: 1)
            )
        }
    }

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP PRIORITIES")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(MateTheme.silverMuted)

            if tasks.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(MateTheme.silverMuted)
                    Text("No pending tasks. You are in total flow.")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else {
                ForEach($tasks) { $task in
                    HStack(spacing: 14) {
                        Button {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                task.status = (task.status == .completed) ? .planned : .completed
                                NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                            }
                        } label: {
                            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(task.status == .completed ? MateTheme.opticWhite : MateTheme.slateDim)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .strikethrough(task.status == .completed)
                                .foregroundStyle(task.status == .completed ? MateTheme.slateDim : MateTheme.opticWhite)
                            if let deadline = task.deadline {
                                Text("Due " + deadline.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(Color.red.opacity(0.85))
                            }
                        }
                        Spacer()
                        Circle()
                            .fill(MateTheme.priorityColor(task.priority))
                            .frame(width: 8, height: 8)
                    }
                    .padding(16)
                    .background(MateTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MateTheme.microBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SCHEDULED TIMELINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                if !scheduledBlocks.isEmpty {
                    Button("Optimize Day") {
                        showingPlanSheet = true
                    }
                    .font(.caption.bold())
                    .foregroundStyle(MateTheme.opticWhite)
                }
            }

            if scheduledBlocks.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(MateTheme.silverMuted)
                    Text("Calendar clear. Open focus time available.")
                        .font(.subheadline)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MateTheme.microBorder, lineWidth: 1)
                )
            } else {
                ForEach(scheduledBlocks) { block in
                    HStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(block.startTime.formatted(date: .omitted, time: .shortened))
                                .font(.caption.bold())
                                .foregroundStyle(MateTheme.opticWhite)
                            Text(block.endTime.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(MateTheme.slateDim)
                        }
                        .frame(width: 60, alignment: .trailing)

                        Rectangle()
                            .fill(block.isLocked ? MateTheme.opticWhite : MateTheme.slateDim)
                            .frame(width: 3)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(MateTheme.opticWhite)
                            Text("\(Int(block.duration / 60)) mins")
                                .font(.caption2)
                                .foregroundStyle(MateTheme.slateDim)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var floatingActionIsland: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            showingCaptureSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Quick Capture or Voice Note")
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

    @MainActor
    private func syncWithCalendarAndReminders(promptIfNeeded: Bool = false) async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let isCalAuthorized = EventKitManager.shared.isCalendarAuthorized
        if isCalAuthorized || promptIfNeeded {
            if let granted = try? await EventKitManager.shared.requestCalendarAccess(), granted {
                if let events = try? await EventKitManager.shared.fetchEvents(from: startOfDay, to: endOfDay) {
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

    private var isEvening: Bool {
        Calendar.current.component(.hour, from: Date()) >= 17
    }

    private var greetingText: String {
        isEvening ? "Evening Debrief" : "Morning Briefing"
    }

    private var briefingSummary: String {
        let meetings = scheduledBlocks.filter { $0.isLocked }.count
        let remaining = tasks.filter { $0.status != .completed }.count
        if isEvening {
            return "You accomplished \(tasks.filter { $0.status == .completed }.count) tasks today. \(remaining) pending items can be auto-scheduled for tomorrow."
        } else {
            return "You have \(meetings) calendar commitments today and \(remaining) priority tasks waiting."
        }
    }

    private func generateAvailability() {
        let slots = availabilityEngine.findAvailableSlots(
            durationMinutes: 45,
            existingCommitments: scheduledBlocks,
            preferences: UserPreference(),
            targetDate: Date(),
            maxSlots: 3
        )
        availabilityMessage = availabilityEngine.formatInvitationMessage(slots: slots, guestName: nil, locale: "en")
    }

    private func reallocateTasksByPriority() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        let result = schedulingEngine.reallocateTasksByPriority(
            tasks: tasks,
            existingCommitments: scheduledBlocks,
            preferences: UserPreference(),
            targetDate: Date()
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
            preferences: UserPreference(),
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
            preferences: UserPreference(),
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
                preferences: UserPreference(),
                targetDate: targetDate
            )
            tasks = result.reallocatedTasks
            for block in result.proposal.scheduledBlocks {
                if !scheduledBlocks.contains(where: { $0.title == block.title }) {
                    scheduledBlocks.append(block)
                }
            }
            scheduledBlocks.sort { $0.startTime < $1.startTime }
            withAnimation { toastBanner = "✓ Schedule optimized by priority" }

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

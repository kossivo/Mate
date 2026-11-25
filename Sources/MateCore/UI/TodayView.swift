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
    @State private var showingShareAvailabilitySheet: Bool = false
    @State private var showingScannerSheet: Bool = false
    @State private var availabilityMessage: String = ""

    private let availabilityEngine = AvailabilityEngine()

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

                floatingActionIsland
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .sheet(isPresented: $showingCaptureSheet) {
                UniversalCaptureView { newTask in
                    tasks.append(newTask)
                    NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                }
            }
            .sheet(isPresented: $showingPlanSheet) {
                PlanView(tasks: tasks, existingBlocks: scheduledBlocks) { proposal in
                    scheduledBlocks = proposal.scheduledBlocks
                }
            }
            .sheet(isPresented: $showingScannerSheet) {
                DocumentScannerView { scannedTask in
                    tasks.append(scannedTask)
                }
            }
            .sheet(isPresented: $showingShareAvailabilitySheet) {
                ShareAvailabilitySheet(message: availabilityMessage)
            }
            .task {
                await syncWithCalendarAndReminders()
            }
            .refreshable {
                await syncWithCalendarAndReminders()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()).uppercased())
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

            HStack(spacing: 10) {
                Button {
                    generateAvailability()
                    showingShareAvailabilitySheet = true
                } label: {
                    Label("Share Free Time", systemImage: "clock.arrow.2.circlepath")
                        .font(.caption2.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(MateTheme.elevatedCard)
                        .foregroundStyle(MateTheme.opticWhite)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }

                Button {
                    showingScannerSheet = true
                } label: {
                    Label("Scan Schedule", systemImage: "text.viewfinder")
                        .font(.caption2.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(MateTheme.elevatedCard)
                        .foregroundStyle(MateTheme.opticWhite)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }
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
    private func syncWithCalendarAndReminders() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        if let granted = try? await EventKitManager.shared.requestCalendarAccess(), granted {
            if let events = try? await EventKitManager.shared.fetchEvents(from: startOfDay, to: endOfDay) {
                let existingTitles = Set(scheduledBlocks.map { $0.title })
                let newEvents = events.filter { !existingTitles.contains($0.title) }
                scheduledBlocks.append(contentsOf: newEvents)
            }
        }

        if let grantedReminders = try? await EventKitManager.shared.requestRemindersAccess(), grantedReminders {
            if let reminders = try? await EventKitManager.shared.fetchReminders() {
                let taskTitles = Set(tasks.map { $0.title })
                let newTasks = reminders.filter { !taskTitles.contains($0.title) }
                tasks.append(contentsOf: newTasks)
                NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
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
        availabilityMessage = availabilityEngine.formatInvitationMessage(slots: slots, guestName: nil, locale: "vi")
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
                    Label(copied ? "Copied to Clipboard!" : "Copy Invitation Message", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.white)
                        .foregroundStyle(copied ? Color.white : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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

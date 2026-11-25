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
        _tasks = State(initialValue: initialTasks.isEmpty ? TodayView.defaultStarterTasks : initialTasks)
        _scheduledBlocks = State(initialValue: initialBlocks.isEmpty ? TodayView.defaultStarterBlocks : initialBlocks)
    }

    private static var defaultStarterTasks: [TaskItem] {
        let now = Date()
        let cal = Calendar.current
        let today18 = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now)
        let tmr10 = cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now)
        let friday = cal.date(byAdding: .day, value: 3, to: cal.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now)

        return [
            TaskItem(
                title: "Hoàn thành slide báo cáo",
                category: "Work",
                deadline: today18,
                estimatedDuration: 60 * 60,
                priority: .high,
                status: .planned
            ),
            TaskItem(
                title: "Gọi cho mẹ tối nay",
                category: "Personal",
                deadline: cal.date(bySettingHour: 20, minute: 0, second: 0, of: now),
                estimatedDuration: 15 * 60,
                priority: .medium,
                status: .planned
            ),
            TaskItem(
                title: "Gặp thảo luận hợp đồng với Nam",
                category: "Meeting",
                deadline: tmr10,
                estimatedDuration: 45 * 60,
                priority: .urgent,
                status: .planned
            ),
            TaskItem(
                title: "Tập thể dục 3 lần tuần này",
                category: "Health & Routine",
                deadline: friday,
                estimatedDuration: 45 * 60,
                priority: .medium,
                status: .planned,
                recurrenceRule: "3x_weekly"
            )
        ]
    }

    private static var defaultStarterBlocks: [TimeBlock] {
        let now = Date()
        let cal = Calendar.current
        let today10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        let today11 = cal.date(bySettingHour: 11, minute: 0, second: 0, of: now) ?? now
        let today14 = cal.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now
        let today15 = cal.date(bySettingHour: 15, minute: 0, second: 0, of: now) ?? now
        let tmr9 = cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 9, minute: 30, second: 0, of: now) ?? now) ?? now
        let tmr10 = cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 10, minute: 30, second: 0, of: now) ?? now) ?? now

        return [
            TimeBlock(title: "Họp giao ban sáng", startTime: today10, endTime: today11, isLocked: true, category: "Work"),
            TimeBlock(title: "Đồng bộ tiến độ dự án", startTime: today14, endTime: today15, isLocked: true, category: "Engineering"),
            TimeBlock(title: "Hẹn cà phê trao đổi đối tác", startTime: tmr9, endTime: tmr10, isLocked: true, category: "Networking")
        ]
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScannerSheet = true
                    } label: {
                        Image(systemName: "doc.viewfinder.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MateTheme.opticWhite)
                    }
                    .accessibilityLabel("Quét lịch trình hoặc ghi chú")
                }
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

            Button {
                generateAvailability()
                showingShareAvailabilitySheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.2.circlepath")
                    Text("Share Free Time")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MateTheme.elevatedCard)
                .foregroundStyle(MateTheme.opticWhite)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
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

                VStack(spacing: 12) {
                    ShareLink(item: message) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Chia sẻ qua Tin nhắn / Ứng dụng")
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
                            Text(copied ? "Đã sao chép vào Clipboard!" : "Sao chép tin nhắn hẹn")
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

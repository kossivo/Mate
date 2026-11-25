import SwiftUI

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
        let defaultTasks = initialTasks.isEmpty ? [
            TaskItem(title: "Finish presentation", deadline: Date().addingTimeInterval(14400), priority: .high, status: .planned),
            TaskItem(title: "Call Mum", deadline: Date().addingTimeInterval(28800), estimatedDuration: 900, priority: .medium, status: .planned),
            TaskItem(title: "Gym session", estimatedDuration: 2700, priority: .low, status: .planned)
        ] : initialTasks

        let defaultBlocks = initialBlocks.isEmpty ? [
            TimeBlock(title: "Client Standup", startTime: Date(), endTime: Date().addingTimeInterval(1800), isLocked: true, category: "Calendar"),
            TimeBlock(title: "Focus: Finish presentation", startTime: Date().addingTimeInterval(3600), endTime: Date().addingTimeInterval(7200), category: "Work")
        ] : initialBlocks

        _tasks = State(initialValue: defaultTasks)
        _scheduledBlocks = State(initialValue: defaultBlocks)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header & Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Today's Overview")
                            .font(.largeTitle.bold())
                    }
                    .padding(.horizontal)

                    // Feature 4: Daily Briefing Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(greetingText, systemImage: isEvening ? "moon.stars.fill" : "sun.max.fill")
                                .font(.caption.bold())
                                .foregroundStyle(isEvening ? .indigo : .orange)
                            Spacer()
                            Text("\(tasks.filter { $0.status == .completed }.count) of \(tasks.count) done")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }

                        Text(briefingSummary)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        // Action pill buttons
                        HStack(spacing: 10) {
                            Button {
                                generateAvailability()
                                showingShareAvailabilitySheet = true
                            } label: {
                                Label("Share Free Time", systemImage: "clock.arrow.2.circlepath")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }

                            Button {
                                showingScannerSheet = true
                            } label: {
                                Label("Scan Note/Card", systemImage: "text.viewfinder")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.12))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MateTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Next Commitment Banner
                    if let next = scheduledBlocks.first {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Next Up", systemImage: "clock.badge.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tint)
                                Spacer()
                                Text(next.startTime.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(next.title)
                                .font(.title3.bold())
                            HStack {
                                Text(next.category ?? "General")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                                if next.isLocked {
                                    Label("Locked Calendar Event", systemImage: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(MateTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Top Priorities Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Top Priorities")
                                .font(.headline)
                            Spacer()
                        }

                        ForEach($tasks) { $task in
                            HStack(spacing: 12) {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        task.status = (task.status == .completed) ? .planned : .completed
                                        NotificationManager.shared.updateBadgeCount(tasks.filter { $0.status != .completed }.count)
                                    }
                                } label: {
                                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(task.status == .completed ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.body)
                                        .strikethrough(task.status == .completed)
                                        .foregroundStyle(task.status == .completed ? .secondary : .primary)
                                    if let deadline = task.deadline {
                                        Text("Due " + deadline.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                Spacer()
                                Circle()
                                    .fill(MateTheme.priorityColor(task.priority))
                                    .frame(width: 8, height: 8)
                            }
                            .padding()
                            .background(MateTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    // Daily Schedule
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Scheduled Timeline")
                                .font(.headline)
                            Spacer()
                            Button("Plan My Day") {
                                showingPlanSheet = true
                            }
                            .font(.caption.bold())
                        }

                        ForEach(scheduledBlocks) { block in
                            HStack(spacing: 16) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(block.startTime.formatted(date: .omitted, time: .shortened))
                                        .font(.caption.bold())
                                    Text(block.endTime.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 60, alignment: .trailing)

                                Rectangle()
                                    .fill(block.isLocked ? Color.purple : Color.blue)
                                    .frame(width: 3)
                                    .clipShape(Capsule())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(block.title)
                                        .font(.subheadline.bold())
                                    Text("\(Int(block.duration / 60)) mins")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 80)
            }
            .navigationTitle("Mate")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCaptureSheet = true
                    } label: {
                        Label("Quick Capture", systemImage: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
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
        }
    }

    private var isEvening: Bool {
        Calendar.current.component(.hour, from: Date()) >= 17
    }

    private var greetingText: String {
        isEvening ? "Evening Wrap-Up" : "Morning Briefing"
    }

    private var briefingSummary: String {
        let meetings = scheduledBlocks.filter { $0.isLocked }.count
        let remaining = tasks.filter { $0.status != .completed }.count
        if isEvening {
            return "You wrapped up \(tasks.filter { $0.status == .completed }.count) tasks today. \(remaining) pending items can be auto-moved to tomorrow."
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
                        .foregroundStyle(.blue)
                    Text("Your Available Times")
                        .font(.title2.bold())
                    Text("Calculated from open gaps in your calendar. Ready to send via Zalo, iMessage, or Email.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text(message)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MateTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        .background(copied ? Color.green : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Share Free Time")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

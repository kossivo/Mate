import SwiftUI

public struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    public let tasks: [TaskItem]
    public let existingBlocks: [TimeBlock]
    public let onConfirm: (SchedulingProposal) -> Void

    @State private var candidateTasks: [TaskItem] = []
    @State private var proposal: SchedulingProposal = SchedulingProposal()
    @State private var isAnalyzing: Bool = true
    private let engine = SmartSchedulingEngine()

    public init(
        tasks: [TaskItem],
        existingBlocks: [TimeBlock],
        onConfirm: @escaping (SchedulingProposal) -> Void
    ) {
        self.tasks = tasks
        self.existingBlocks = existingBlocks
        self.onConfirm = onConfirm
    }

    private var unifiedTimeline: [TimeBlock] {
        let existingTimed = existingBlocks.filter { !$0.isAllDay }
        let existingIds = Set(existingTimed.map { $0.id })
        let newBlocks = proposal.scheduledBlocks.filter { !existingIds.contains($0.id) }
        return (existingTimed + newBlocks).sorted { $0.startTime < $1.startTime }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                MateTheme.pureBlack.ignoresSafeArea()

                if isAnalyzing {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(MateTheme.opticWhite)
                        Text("Optimizing your schedule...")
                            .font(.subheadline)
                            .foregroundStyle(MateTheme.silverMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                // Optimization Summary Card
                                summaryCard

                                // Interactive Task Priority & Ranking Section
                                if !candidateTasks.isEmpty {
                                    taskRankingSection
                                }

                                // Unscheduled Warning if any
                                if !proposal.unscheduledTasks.isEmpty {
                                    unscheduledWarningCard
                                }

                                // Proposed Schedule Timeline
                                timelineSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        }

                        // Bottom Action Button
                        VStack(spacing: 0) {
                            Divider().background(MateTheme.microBorder)
                            Button {
                                #if canImport(UIKit)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                #endif
                                // Save any adjusted priorities back to DataManager
                                for task in candidateTasks {
                                    DataManager.shared.updateTaskPriority(taskId: task.id, priority: task.priority)
                                }
                                onConfirm(proposal)
                                dismiss()
                            } label: {
                                Text(proposal.scheduledBlocks.isEmpty ? "Keep Schedule Intact" : "Apply & Lock Schedule (\(proposal.scheduledBlocks.count) blocks)")
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MateTheme.opticWhite)
                                    .foregroundStyle(MateTheme.pureBlack)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(MateTheme.pureBlack)
                        }
                    }
                }
            }
            .navigationTitle("Optimize Day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(MateTheme.opticWhite)
                }
            }
            .task {
                candidateTasks = tasks
                    .filter { $0.status != .completed && $0.status != .cancelled }
                    .sorted { (lhs, rhs) -> Bool in
                        if lhs.priority != rhs.priority {
                            return lhs.priority < rhs.priority
                        }
                        return lhs.estimatedDuration < rhs.estimatedDuration
                    }
                recalculateSchedule()
            }
        }
    }

    // MARK: - Recalculate Scheduling Proposal

    private func recalculateSchedule(preserveOrder: Bool = false) {
        let prefs = UserPreference.load()
        let now = Date()
        proposal = engine.schedule(
            tasks: candidateTasks,
            existingCommitments: existingBlocks,
            preferences: prefs,
            targetDate: now,
            referenceDate: now,
            preserveOrder: preserveOrder
        )
        isAnalyzing = false
    }

    // MARK: - Task Ranking Controls

    private func moveTaskUp(at index: Int) {
        guard index > 0 else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            candidateTasks.swapAt(index, index - 1)
            recalculateSchedule(preserveOrder: true)
        }
    }

    private func moveTaskDown(at index: Int) {
        guard index < candidateTasks.count - 1 else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            candidateTasks.swapAt(index, index + 1)
            recalculateSchedule(preserveOrder: true)
        }
    }

    private func updatePriority(at index: Int, to newPriority: TaskPriority) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            candidateTasks[index].priority = newPriority
            recalculateSchedule(preserveOrder: true)
        }
    }

    // MARK: - Subviews

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("OPTIMIZATION SUMMARY", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
            }

            if proposal.scheduledBlocks.isEmpty && candidateTasks.isEmpty {
                Text("All tasks are already completed. Your existing calendar commitments will stay completely intact.")
                    .font(.subheadline)
                    .foregroundStyle(MateTheme.opticWhite)
            } else if proposal.scheduledBlocks.isEmpty {
                Text("No open time slots fit pending tasks. Your existing calendar commitments remain preserved.")
                    .font(.subheadline)
                    .foregroundStyle(MateTheme.silverMuted)
            } else {
                Text("Scheduled \(proposal.scheduledBlocks.count) priority task sessions around your \(existingBlocks.filter { !$0.isAllDay }.count) calendar commitments.")
                    .font(.subheadline.bold())
                    .foregroundStyle(MateTheme.opticWhite)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1))
    }

    private var taskRankingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PRIORITY & EXECUTION ORDER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MateTheme.silverMuted)
                    Text("Tap priority or use ↑ ↓ to adjust order")
                        .font(.caption2)
                        .foregroundStyle(MateTheme.slateDim)
                }
                Spacer()
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        candidateTasks.sort { (lhs, rhs) -> Bool in
                            if lhs.priority != rhs.priority {
                                return lhs.priority < rhs.priority
                            }
                            return lhs.estimatedDuration < rhs.estimatedDuration
                        }
                        recalculateSchedule(preserveOrder: false)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("Reset Sort")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(MateTheme.cardBackground)
                    .foregroundStyle(MateTheme.silverMuted)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(candidateTasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 {
                        Divider()
                            .background(MateTheme.hairlineDivider)
                            .padding(.leading, 36)
                    }
                    taskRankingRow(task: task, index: index)
                }
            }
            .background(MateTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1))
        }
    }

    private func taskRankingRow(task: TaskItem, index: Int) -> some View {
        let isScheduled = proposal.scheduledBlocks.contains(where: { $0.title == task.title })

        return HStack(spacing: 10) {
            // Rank Number Badge
            Text("#\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isScheduled ? MateTheme.opticWhite : MateTheme.slateDim)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(Int(task.estimatedDuration / 60))m")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MateTheme.slateDim)

                    if let d = task.deadline {
                        Text("Due " + d.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }

                    if isScheduled {
                        Text("Planned")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.18))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    } else {
                        Text("No Slot")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Priority Menu Pill
            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    Button {
                        updatePriority(at: index, to: p)
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
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(MateTheme.elevatedCard)
                .clipShape(Capsule())
            }

            // Up / Down Rank Reorder Buttons
            HStack(spacing: 2) {
                Button {
                    moveTaskUp(at: index)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(index == 0 ? MateTheme.slateDim.opacity(0.3) : MateTheme.opticWhite)
                        .frame(width: 24, height: 24)
                        .background(MateTheme.elevatedCard)
                        .clipShape(Circle())
                }
                .disabled(index == 0)
                .buttonStyle(.plain)

                Button {
                    moveTaskDown(at: index)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(index == candidateTasks.count - 1 ? MateTheme.slateDim.opacity(0.3) : MateTheme.opticWhite)
                        .frame(width: 24, height: 24)
                        .background(MateTheme.elevatedCard)
                        .clipShape(Circle())
                }
                .disabled(index == candidateTasks.count - 1)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var unscheduledWarningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tasks Needing Attention (\(proposal.unscheduledTasks.count))", systemImage: "clock.badge.exclamationmark.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.orange)

            ForEach(proposal.unscheduledTasks, id: \.taskId) { unscheduled in
                VStack(alignment: .leading, spacing: 2) {
                    Text(unscheduled.taskTitle)
                        .font(.caption.bold())
                        .foregroundStyle(MateTheme.opticWhite)
                    Text(unscheduled.reason)
                        .font(.caption2)
                        .foregroundStyle(MateTheme.silverMuted)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROPOSED DAY SCHEDULE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(MateTheme.silverMuted)

            if unifiedTimeline.isEmpty {
                Text("No events or tasks scheduled.")
                    .font(.caption)
                    .foregroundStyle(MateTheme.slateDim)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(unifiedTimeline.enumerated()), id: \.element.id) { index, block in
                        if index > 0 {
                            Divider()
                                .background(MateTheme.hairlineDivider)
                                .padding(.leading, 70)
                        }
                        timelineBlockRow(block)
                    }
                }
                .background(MateTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1))
            }
        }
    }

    private func timelineBlockRow(_ block: TimeBlock) -> some View {
        let isExisting = existingBlocks.contains(where: { $0.id == block.id })

        return HStack(spacing: 12) {
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
                .fill(isExisting ? MateTheme.opticWhite : Color.green)
                .frame(width: 2.5, height: 26)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(Int(block.duration / 60))m session")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MateTheme.slateDim)

                    if isExisting {
                        Text("Calendar Event")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.silverMuted)
                            .clipShape(Capsule())
                    } else {
                        Text("New Task Block")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.green.opacity(0.18))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

}

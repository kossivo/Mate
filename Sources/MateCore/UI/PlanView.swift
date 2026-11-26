import SwiftUI

public struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    public let tasks: [TaskItem]
    public let existingBlocks: [TimeBlock]
    public let onConfirm: (SchedulingProposal) -> Void

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
                            VStack(alignment: .leading, spacing: 20) {
                                // Planning Summary Card
                                summaryCard

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
                                onConfirm(proposal)
                                dismiss()
                            } label: {
                                Text(proposal.scheduledBlocks.isEmpty ? "Keep Schedule Intact" : "Apply & Sync Schedule")
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
                let prefs = UserPreference.load()
                proposal = engine.schedule(
                    tasks: tasks,
                    existingCommitments: existingBlocks,
                    preferences: prefs,
                    targetDate: Date()
                )
                isAnalyzing = false
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("OPTIMIZATION SUMMARY", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
            }

            if proposal.scheduledBlocks.isEmpty && tasks.filter({ $0.status != .completed }).isEmpty {
                Text("All tasks are already completed. Your existing calendar commitments will stay completely intact.")
                    .font(.subheadline)
                    .foregroundStyle(MateTheme.opticWhite)
            } else if proposal.scheduledBlocks.isEmpty {
                Text("No available time slots found to fit pending tasks. Your existing calendar commitments remain preserved.")
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

    private var unscheduledWarningCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tasks Needing Rescheduling (\(proposal.unscheduledTasks.count))", systemImage: "clock.badge.exclamationmark.fill")
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
        VStack(alignment: .leading, spacing: 12) {
            Text("UNIFIED DAY TIMELINE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(MateTheme.silverMuted)

            if unifiedTimeline.isEmpty {
                Text("No events or tasks scheduled.")
                    .font(.caption)
                    .foregroundStyle(MateTheme.slateDim)
                    .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(unifiedTimeline) { block in
                        timelineBlockRow(block)
                    }
                }
            }
        }
    }

    private func timelineBlockRow(_ block: TimeBlock) -> some View {
        let isExisting = existingBlocks.contains(where: { $0.id == block.id })

        return HStack(spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(block.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption.bold())
                    .foregroundStyle(MateTheme.opticWhite)
                Text(block.endTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(MateTheme.slateDim)
            }
            .frame(width: 56, alignment: .trailing)

            Rectangle()
                .fill(isExisting ? MateTheme.opticWhite : Color.green)
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(MateTheme.opticWhite)

                HStack(spacing: 6) {
                    Text("\(Int(block.duration / 60)) min session")
                        .font(.caption2)
                        .foregroundStyle(MateTheme.slateDim)

                    if isExisting {
                        Text("Calendar Event · Stays")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MateTheme.elevatedCard)
                            .foregroundStyle(MateTheme.silverMuted)
                            .clipShape(Capsule())
                    } else {
                        Text("New Task Block")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.18))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MateTheme.microBorder, lineWidth: 1))
    }
}

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

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Optimizing your schedule...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Summary Card
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Planning Summary")
                                    .font(.headline)
                                Text("Scheduled \(proposal.scheduledBlocks.count) task sessions around \(existingBlocks.count) calendar events.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MateTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            // Unscheduled Warning if any
                            if !proposal.unscheduledTasks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Could Not Fit Today", systemImage: "clock.badge.exclamationmark.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.orange)

                                    ForEach(proposal.unscheduledTasks, id: \.taskId) { unscheduled in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(unscheduled.taskTitle)
                                                .font(.caption.bold())
                                            Text(unscheduled.reason)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }

                            // Proposed Schedule
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Proposed Timeline")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(proposal.scheduledBlocks) { block in
                                    HStack(spacing: 12) {
                                        Text(block.startTime.formatted(date: .omitted, time: .shortened))
                                            .font(.caption.bold())
                                            .frame(width: 60, alignment: .trailing)

                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(block.title)
                                                .font(.body.bold())
                                            Text("\(Int(block.duration / 60)) min session")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    Spacer()

                    Button {
                        onConfirm(proposal)
                        dismiss()
                    } label: {
                        Text("Apply & Sync Schedule")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Plan My Day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                proposal = engine.schedule(
                    tasks: tasks,
                    existingCommitments: existingBlocks,
                    preferences: UserPreference(),
                    targetDate: Date()
                )
                isAnalyzing = false
            }
        }
    }
}

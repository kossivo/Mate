import SwiftUI

public struct TodayView: View {
    @State private var tasks: [TaskItem]
    @State private var scheduledBlocks: [TimeBlock]
    @State private var showingCaptureSheet: Bool = false
    @State private var showingPlanSheet: Bool = false

    public init(
        initialTasks: [TaskItem] = [],
        initialBlocks: [TimeBlock] = []
    ) {
        let tasks = initialTasks.isEmpty ? [
            TaskItem(title: "Finish presentation", deadline: Date().addingTimeInterval(14400), priority: .high, status: .planned),
            TaskItem(title: "Call Mum", deadline: Date().addingTimeInterval(28800), estimatedDuration: 900, priority: .medium, status: .planned),
            TaskItem(title: "Gym session", estimatedDuration: 2700, priority: .low, status: .planned)
        ] : initialTasks

        let blocks = initialBlocks.isEmpty ? [
            TimeBlock(title: "Client Standup", startTime: Date(), endTime: Date().addingTimeInterval(1800), isLocked: true, category: "Calendar"),
            TimeBlock(title: "Focus: Finish presentation", startTime: Date().addingTimeInterval(3600), endTime: Date().addingTimeInterval(7200), category: "Work")
        ] : initialBlocks

        _tasks = State(initialValue: tasks)
        _scheduledBlocks = State(initialValue: blocks)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date & Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Today's Overview")
                            .font(.largeTitle.bold())
                    }
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
                            Text("\(tasks.filter { $0.status == .completed }.count)/\(tasks.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }

                        ForEach($tasks) { $task in
                            HStack(spacing: 12) {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        task.status = (task.status == .completed) ? .planned : .completed
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
                }
            }
            .sheet(isPresented: $showingPlanSheet) {
                PlanView(tasks: tasks, existingBlocks: scheduledBlocks) { proposal in
                    scheduledBlocks = proposal.scheduledBlocks
                }
            }
        }
    }
}

import SwiftUI

public struct UniversalCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var parsedItems: [ParsedCaptureItem] = []
    @StateObject private var voiceManager = VoiceDictationManager.shared
    @State private var existingEvents: [TimeBlock] = []
    private let parser = DeterministicCaptureParser()
    private let onSaveTask: (TaskItem) -> Void
    private let onSaveEvent: (TimeBlock) -> Void

    public init(
        onSaveTask: @escaping (TaskItem) -> Void,
        onSaveEvent: @escaping (TimeBlock) -> Void = { _ in }
    ) {
        self.onSaveTask = onSaveTask
        self.onSaveEvent = onSaveEvent
    }

    public init(onSave: @escaping (TaskItem) -> Void) {
        self.onSaveTask = onSave
        self.onSaveEvent = { _ in }
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                headerAndDictation
                textInputField
                if voiceManager.isRecording {
                    recordingStatusView
                }
                if !parsedItems.isEmpty {
                    itemsScrollView
                }
                Spacer()
                actionSaveButton
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Quick Capture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        voiceManager.stopRecording()
                        dismiss()
                    }
                    .foregroundStyle(MateTheme.opticWhite)
                }
            }
            .task {
                let start = Date()
                let end = start.addingTimeInterval(7 * 86400)
                if let events = try? await EventKitManager.shared.fetchEvents(from: start, to: end) {
                    existingEvents = events
                    if !inputText.isEmpty {
                        updateParsedItems(for: inputText)
                    }
                }
            }
            .onDisappear {
                voiceManager.stopRecording()
            }
        }
    }

    // MARK: - Subviews

    private var headerAndDictation: some View {
        HStack {
            Text("Quick Capture or Voice")
                .font(.headline.bold())
                .foregroundStyle(MateTheme.opticWhite)
            Spacer()
            Button {
                voiceManager.toggleRecording { transcribed in
                    inputText = transcribed
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: voiceManager.isRecording ? "waveform.circle.fill" : "mic.fill")
                        .font(.body.bold())
                        .foregroundStyle(voiceManager.isRecording ? .red : MateTheme.opticWhite)
                    Text(voiceManager.isRecording ? "Listening..." : "Speak")
                        .font(.caption.bold())
                        .foregroundStyle(voiceManager.isRecording ? .red : MateTheme.opticWhite)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(voiceManager.isRecording ? Color.red.opacity(0.2) : MateTheme.elevatedCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal)
    }

    private var textInputField: some View {
        TextField("e.g., Tomorrow meeting at 8:30 with Alex, reminder to submit report at 5pm...", text: $inputText, axis: .vertical)
            .lineLimit(3...5)
            .padding()
            .background(MateTheme.cardBackground)
            .foregroundStyle(MateTheme.opticWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
            )
            .padding(.horizontal)
            .onChange(of: inputText) { _, newValue in
                updateParsedItems(for: newValue)
            }
    }

    private var recordingStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text("Listening for speech... Tap Speak to stop.")
                .font(.caption)
                .foregroundStyle(MateTheme.silverMuted)
        }
        .padding(.horizontal)
    }

    private var itemsScrollView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECOGNIZED ITEMS (\(parsedItems.count))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(MateTheme.silverMuted)
                Spacer()
                Text("Tap icon to switch Event ↔ Task")
                    .font(.caption2)
                    .foregroundStyle(MateTheme.slateDim)
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(parsedItems.indices, id: \.self) { index in
                        singleItemCard(index: index)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func singleItemCard(index: Int) -> some View {
        let item = parsedItems[index]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    parsedItems[index].itemType = (item.itemType == .event ? .task : .event)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.itemType == .event ? "calendar.badge.clock" : "bell.fill")
                        Text(item.itemType == .event ? "EVENT" : "TASK")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.itemType == .event ? Color.indigo.opacity(0.25) : Color.orange.opacity(0.2))
                    .foregroundStyle(item.itemType == .event ? Color.indigo : Color.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if let cat = item.category {
                    Text(cat)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(MateTheme.elevatedCard)
                        .foregroundStyle(MateTheme.silverMuted)
                        .clipShape(Capsule())
                }
            }

            Text(item.title)
                .font(.body.bold())
                .foregroundStyle(MateTheme.opticWhite)

            HStack(spacing: 12) {
                if let deadline = item.deadline {
                    if item.itemType == .event {
                        let end = deadline.addingTimeInterval(item.estimatedDuration)
                        Label("\(deadline.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))", systemImage: "clock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(MateTheme.opticWhite)
                    } else {
                        Label("Due: \(deadline.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell.badge.fill")
                            .font(.caption.bold())
                            .foregroundStyle(MateTheme.opticWhite)
                    }
                }

                if item.itemType == .event {
                    Text("(\(Int(item.estimatedDuration / 60)) mins)")
                        .font(.caption2)
                        .foregroundStyle(MateTheme.slateDim)
                }

                if let rec = item.recurrence {
                    Label(rec, systemImage: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            if item.deadline != nil {
                if let conflict = item.calendarConflict {
                    Label("Conflict with: \(conflict)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                } else {
                    Label("Open calendar slot", systemImage: "checkmark.seal.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MateTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(MateTheme.microBorder, lineWidth: 1)
        )
    }

    private var actionSaveButton: some View {
        Button {
            voiceManager.stopRecording()
            for item in parsedItems {
                if item.itemType == .event {
                    let start = item.deadline ?? Date()
                    let end = start.addingTimeInterval(item.estimatedDuration)
                    let block = TimeBlock(
                        title: item.title,
                        startTime: start,
                        endTime: end,
                        isLocked: true,
                        category: item.category ?? "Meeting"
                    )
                    onSaveEvent(block)
                } else {
                    let task = TaskItem(
                        title: item.title,
                        category: item.category,
                        deadline: item.deadline,
                        estimatedDuration: item.estimatedDuration,
                        priority: item.priority,
                        status: item.isAmbiguous ? .inbox : .planned,
                        recurrenceRule: item.recurrence
                    )
                    onSaveTask(task)
                    if let deadline = item.deadline {
                        NotificationManager.shared.scheduleTaskReminder(title: item.title, reminderDate: deadline, id: task.id)
                    }
                }
            }
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text("Save \(max(1, parsedItems.count)) items to Schedule & Tasks")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(inputText.isEmpty ? MateTheme.elevatedCard : MateTheme.opticWhite)
            .foregroundStyle(inputText.isEmpty ? MateTheme.slateDim : MateTheme.pureBlack)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(inputText.isEmpty)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func updateParsedItems(for text: String) {
        var items = parser.parse(text: text)
        for i in 0..<items.count {
            if let deadline = items[i].deadline {
                let end = deadline.addingTimeInterval(items[i].estimatedDuration)
                if let conflictingEvent = existingEvents.first(where: { block in
                    !(block.endTime <= deadline || block.startTime >= end)
                }) {
                    items[i].calendarConflict = conflictingEvent.title
                }
            }
        }
        parsedItems = items
    }
}

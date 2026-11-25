import SwiftUI

public struct UniversalCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var parsedItems: [ParsedCaptureItem] = []
    @StateObject private var voiceManager = VoiceDictationManager.shared
    @State private var existingEvents: [TimeBlock] = []
    private let parser = DeterministicCaptureParser()
    private let onSave: (TaskItem) -> Void

    public init(onSave: @escaping (TaskItem) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("What's on your mind?")
                        .font(.headline)
                    Spacer()
                    // Dictation Toggle Button
                    Button {
                        voiceManager.toggleRecording { transcribed in
                            inputText = transcribed
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: voiceManager.isRecording ? "waveform.circle.fill" : "mic.fill")
                                .font(.body.bold())
                                .foregroundStyle(voiceManager.isRecording ? .red : .blue)
                            Text(voiceManager.isRecording ? "Listening..." : "Dictate")
                                .font(.caption.bold())
                                .foregroundStyle(voiceManager.isRecording ? .red : .blue)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(voiceManager.isRecording ? Color.red.opacity(0.12) : Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                TextField("e.g. Mai hẹn lúc 8.30, hoàn thành slide trước thứ 6...", text: $inputText, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(MateTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .onChange(of: inputText) { _, newValue in
                        updateParsedItems(for: newValue)
                    }

                if voiceManager.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Speaking in Vietnamese or English... Tap Dictate to finish.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                if !parsedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recognized Tasks (\(parsedItems.count))")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(Array(parsedItems.enumerated()), id: \.offset) { _, item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.body.bold())

                                        HStack(spacing: 8) {
                                            if let deadline = item.deadline {
                                                Label(deadline.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.primary)
                                            }

                                            Label("\(Int(item.estimatedDuration / 60)) min", systemImage: "clock")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)

                                            if let cat = item.category {
                                                Text(cat)
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundStyle(.blue)
                                                    .clipShape(Capsule())
                                            }

                                            if let rec = item.recurrence {
                                                Label(rec, systemImage: "repeat")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                            }
                                        }

                                        // Calendar conflict or availability badge
                                        if let deadline = item.deadline {
                                            if let conflict = item.calendarConflict {
                                                Label("Trùng lịch: \(conflict)", systemImage: "exclamationmark.triangle.fill")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.red)
                                            } else {
                                                Label("Lịch trống lúc \(deadline.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.seal.fill")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.green)
                                            }
                                        }

                                        if item.isAmbiguous {
                                            Label("Ambiguous details — placed in Inbox for review", systemImage: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(MateTheme.secondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()

                Button {
                    voiceManager.stopRecording()
                    for item in parsedItems {
                        let task = TaskItem(
                            title: item.title,
                            category: item.category,
                            deadline: item.deadline,
                            estimatedDuration: item.estimatedDuration,
                            priority: item.priority,
                            status: item.isAmbiguous ? .inbox : .planned,
                            recurrenceRule: item.recurrence
                        )
                        onSave(task)
                    }
                    dismiss()
                } label: {
                    Text("Add \(max(1, parsedItems.count)) Task\(parsedItems.count > 1 ? "s" : "")")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inputText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(inputText.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Quick Capture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        voiceManager.stopRecording()
                        dismiss()
                    }
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

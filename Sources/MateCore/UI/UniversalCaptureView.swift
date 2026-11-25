import SwiftUI

public struct UniversalCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var parsedItems: [ParsedCaptureItem] = []
    private let parser = DeterministicCaptureParser()
    private let onSave: (TaskItem) -> Void

    public init(onSave: @escaping (TaskItem) -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What's on your mind?")
                    .font(.headline)
                    .padding(.horizontal)

                TextField("e.g. Finish slides by Friday, call Mum tonight...", text: $inputText, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(MateTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .onChange(of: inputText) { _, newValue in
                        parsedItems = parser.parse(text: newValue)
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
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
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
                        dismiss()
                    }
                }
            }
        }
    }
}

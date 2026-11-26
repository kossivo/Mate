import SwiftUI

public struct NotesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [NoteItem] = []
    @State private var activeNoteId: UUID? = nil
    @State private var noteText: String = ""
    @State private var showingScannerSheet: Bool = false
    @StateObject private var voiceManager = VoiceDictationManager.shared
    @State private var toastBanner: String? = nil
    @State private var isShowingNoteList: Bool = false

    private let parser = DeterministicCaptureParser()
    public let onAddTask: (TaskItem) -> Void
    public let onAddEvent: (TimeBlock) -> Void

    public init(
        onAddTask: @escaping (TaskItem) -> Void = { _ in },
        onAddEvent: @escaping (TimeBlock) -> Void = { _ in }
    ) {
        self.onAddTask = onAddTask
        self.onAddEvent = onAddEvent
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Header Sub-bar with Note Count & Actions
                    notesHeaderBar

                    // Note Editor
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: $noteText)
                            .scrollContentBackground(.hidden)
                            .background(MateTheme.pureBlack)
                            .foregroundStyle(MateTheme.opticWhite)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .overlay(alignment: .topLeading) {
                                if noteText.isEmpty {
                                    Text("Jot down quick thoughts, meeting notes, action items, or scan business cards...")
                                        .font(.body)
                                        .foregroundStyle(MateTheme.slateDim)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    // Bottom Action Toolbar attached to keyboard / bottom
                    notesActionToolbar
                }

                // Toast Banner
                if let toast = toastBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(toast)
                            .font(.caption.bold())
                            .foregroundStyle(MateTheme.opticWhite)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(MateTheme.elevatedCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Quick Notes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        saveCurrentNoteIfNeeded()
                        voiceManager.stopRecording()
                        dismiss()
                    }
                    .foregroundStyle(MateTheme.opticWhite)
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            saveCurrentNoteIfNeeded()
                            startNewNote()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MateTheme.opticWhite)
                        }
                        .accessibilityLabel("New Note")

                        Button {
                            saveCurrentNoteIfNeeded()
                            isShowingNoteList = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                if !notes.isEmpty {
                                    Text("\(notes.count)")
                                        .font(.caption2.bold())
                                }
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MateTheme.opticWhite)
                        }
                        .accessibilityLabel("All Notes")
                    }
                }
            }
            .sheet(isPresented: $showingScannerSheet) {
                DocumentScannerView(
                    onAddContactOrTask: { task in
                        onAddTask(task)
                    },
                    onAddEvent: { event in
                        onAddEvent(event)
                    },
                    onScannedText: { scannedText in
                        appendScannedContent(scannedText)
                    }
                )
            }
            .sheet(isPresented: $isShowingNoteList) {
                savedNotesListView
            }
            .onAppear {
                loadNotes()
                if let first = notes.first, noteText.isEmpty {
                    activeNoteId = first.id
                    noteText = first.content
                }
            }
            .onDisappear {
                saveCurrentNoteIfNeeded()
                voiceManager.stopRecording()
            }
        }
    }

    // MARK: - Subviews

    private var notesHeaderBar: some View {
        HStack {
            let title = noteText.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "New Note"
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(MateTheme.opticWhite)
                    .lineLimit(1)
                Text(Date().formatted(.dateTime.month().day().year().hour().minute().locale(Locale(identifier: "en_US"))))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MateTheme.slateDim)
            }

            Spacer()

            if !noteText.isEmpty {
                Button {
                    extractTasksAndEventsFromNote()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.yellow)
                        Text("Extract to Schedule")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MateTheme.elevatedCard)
                    .foregroundStyle(MateTheme.opticWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MateTheme.cardBackground)
        .overlay(Divider().background(MateTheme.microBorder), alignment: .bottom)
    }

    private var notesActionToolbar: some View {
        HStack(spacing: 12) {
            // 1. Scan Business Card / Document (Integrated directly as part of note!)
            Button {
                showingScannerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.subheadline)
                    Text("Scan Card / Doc")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(MateTheme.elevatedCard)
                .foregroundStyle(MateTheme.opticWhite)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // 2. Voice Note Recording
            Button {
                voiceManager.toggleRecording { transcribed in
                    noteText = transcribed
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: voiceManager.isRecording ? "waveform.circle.fill" : "mic.fill")
                        .font(.subheadline)
                        .foregroundStyle(voiceManager.isRecording ? Color.red : MateTheme.opticWhite)
                    Text(voiceManager.isRecording ? "Listening..." : "Voice")
                        .font(.caption.bold())
                        .foregroundStyle(voiceManager.isRecording ? Color.red : MateTheme.opticWhite)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(voiceManager.isRecording ? Color.red.opacity(0.2) : MateTheme.elevatedCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MateTheme.microBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // 3. Save Note Checkmark
            Button {
                saveCurrentNoteIfNeeded()
                withAnimation {
                    toastBanner = "✓ Note saved"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { toastBanner = nil }
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MateTheme.pureBlack)
                    .frame(width: 34, height: 34)
                    .background(noteText.isEmpty ? MateTheme.slateDim : MateTheme.opticWhite)
                    .clipShape(Circle())
            }
            .disabled(noteText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(MateTheme.cardBackground)
        .overlay(Divider().background(MateTheme.microBorder), alignment: .top)
    }

    private var savedNotesListView: some View {
        NavigationStack {
            List {
                if notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40))
                            .foregroundStyle(MateTheme.slateDim)
                        Text("No saved notes")
                            .font(.headline)
                            .foregroundStyle(MateTheme.opticWhite)
                        Text("Notes you jot down or cards you scan will appear here.")
                            .font(.caption)
                            .foregroundStyle(MateTheme.silverMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(notes) { note in
                        Button {
                            saveCurrentNoteIfNeeded()
                            activeNoteId = note.id
                            noteText = note.content
                            isShowingNoteList = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(MateTheme.opticWhite)
                                Text(note.content)
                                    .font(.caption)
                                    .foregroundStyle(MateTheme.silverMuted)
                                    .lineLimit(2)
                                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(MateTheme.slateDim)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(MateTheme.cardBackground)
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MateTheme.pureBlack.ignoresSafeArea())
            .navigationTitle("Saved Notes (\(notes.count))")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isShowingNoteList = false }
                        .foregroundStyle(MateTheme.opticWhite)
                }
            }
        }
    }

    // MARK: - Logic

    private func startNewNote() {
        activeNoteId = UUID()
        noteText = ""
        withAnimation {
            toastBanner = "✓ Ready for new note"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { toastBanner = nil }
        }
    }

    private func appendScannedContent(_ scannedText: String) {
        guard !scannedText.isEmpty else { return }
        if noteText.isEmpty {
            noteText = scannedText
        } else {
            noteText += "\n\n--- Scanned Card / Note ---\n" + scannedText
        }
        saveCurrentNoteIfNeeded()
        withAnimation {
            toastBanner = "✓ Scanned card inserted into note"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastBanner = nil }
        }
    }

    private func extractTasksAndEventsFromNote() {
        let items = parser.parse(text: noteText)
        guard !items.isEmpty else {
            withAnimation {
                toastBanner = "No specific tasks or meetings found in note"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { toastBanner = nil }
            }
            return
        }

        var extractedTasks = 0
        var extractedEvents = 0

        for item in items {
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
                onAddEvent(block)
                extractedEvents += 1
            } else {
                let task = TaskItem(
                    title: item.title,
                    notes: "From Note",
                    category: item.category ?? "Work",
                    deadline: item.deadline,
                    estimatedDuration: item.estimatedDuration,
                    priority: item.priority,
                    status: .planned
                )
                onAddTask(task)
                if let deadline = item.deadline {
                    NotificationManager.shared.scheduleTaskReminder(title: item.title, reminderDate: deadline, id: task.id)
                }
                extractedTasks += 1
            }
        }

        withAnimation {
            toastBanner = "✓ Added \(extractedTasks) tasks and \(extractedEvents) events to schedule"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { toastBanner = nil }
        }
    }

    private func saveCurrentNoteIfNeeded() {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let title = noteText.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "New Note"

        if let id = activeNoteId, let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].title = title
            notes[idx].content = noteText
            notes[idx].updatedAt = Date()
        } else {
            let newNote = NoteItem(
                id: activeNoteId ?? UUID(),
                title: title,
                content: noteText,
                createdAt: Date(),
                updatedAt: Date()
            )
            activeNoteId = newNote.id
            notes.insert(newNote, at: 0)
        }
        persistNotes()
    }

    private func deleteNotes(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        persistNotes()
        if let current = activeNoteId, !notes.contains(where: { $0.id == current }) {
            activeNoteId = nil
            noteText = ""
        }
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: "mate_saved_notes"),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            notes = decoded
        }
    }

    private func persistNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: "mate_saved_notes")
        }
    }
}
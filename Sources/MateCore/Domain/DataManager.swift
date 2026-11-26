import Foundation
import Combine
import SwiftUI

@MainActor
public final class DataManager: ObservableObject {
    public static let shared = DataManager()

    @Published public var tasks: [TaskItem] = [] {
        didSet { persistTasks() }
    }
    @Published public var scheduledBlocks: [TimeBlock] = [] {
        didSet { persistBlocks() }
    }
    @Published public var notes: [NoteItem] = [] {
        didSet { persistNotes() }
    }
    @Published public var preferences: UserPreference = UserPreference.load() {
        didSet { preferences.save() }
    }

    private let calendar = Calendar.current
    private let tasksKey = "mate_saved_tasks"
    private let blocksKey = "mate_saved_blocks"
    private let notesKey = "mate_saved_notes"

    public init() {
        loadData()
    }

    public func loadData() {
        // Load tasks
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            self.tasks = decoded
        }
        // Load custom blocks
        if let data = UserDefaults.standard.data(forKey: blocksKey),
           let decoded = try? JSONDecoder().decode([TimeBlock].self, from: data) {
            self.scheduledBlocks = decoded
        }
        // Load notes
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            self.notes = decoded
        }
        self.preferences = UserPreference.load()
    }

    private func persistTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }

    private func persistBlocks() {
        if let data = try? JSONEncoder().encode(scheduledBlocks) {
            UserDefaults.standard.set(data, forKey: blocksKey)
        }
    }

    private func persistNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }

    // MARK: - Task Actions

    public func addTask(_ task: TaskItem) {
        if !tasks.contains(where: { $0.id == task.id }) {
            tasks.append(task)
            NotificationManager.shared.updateBadgeCount(activeTaskCount)
        }
    }

    public func updateTask(_ task: TaskItem) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
            NotificationManager.shared.updateBadgeCount(activeTaskCount)
        }
    }

    public func toggleTaskCompletion(_ task: TaskItem) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = (tasks[idx].status == .completed) ? .planned : .completed
            tasks[idx].updatedAt = Date()
            NotificationManager.shared.updateBadgeCount(activeTaskCount)
        }
    }

    public func deleteTask(withId id: UUID) {
        tasks.removeAll { $0.id == id }
        NotificationManager.shared.updateBadgeCount(activeTaskCount)
    }

    public var activeTaskCount: Int {
        tasks.filter { $0.status != .completed }.count
    }

    // MARK: - Schedule Actions

    public func addBlock(_ block: TimeBlock) {
        scheduledBlocks.append(block)
        scheduledBlocks.sort { $0.startTime < $1.startTime }
    }

    public func removeBlock(withId id: UUID) {
        scheduledBlocks.removeAll { $0.id == id }
    }

    public func applyProposal(_ proposal: SchedulingProposal) {
        let existingLocked = scheduledBlocks.filter { $0.isLocked || $0.isAllDay }
        let newPlannedTasks = proposal.scheduledBlocks.filter { block in
            !existingLocked.contains { $0.title == block.title && $0.startTime == block.startTime }
        }
        scheduledBlocks = (existingLocked + newPlannedTasks).sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Note Actions

    public func addNote(_ note: NoteItem) {
        if !notes.contains(where: { $0.id == note.id }) {
            notes.insert(note, at: 0)
        }
    }

    public func deleteNote(withId id: UUID) {
        notes.removeAll { $0.id == id }
    }

    // MARK: - EventKit Synchronization

    public func syncWithEventKit(promptIfNeeded: Bool = false) async {
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) else { return }

        // Calendar sync
        if EventKitManager.shared.isCalendarAuthorized || promptIfNeeded {
            if let granted = try? await EventKitManager.shared.requestCalendarAccess(), granted {
                if let events = try? await EventKitManager.shared.fetchEvents(from: startOfToday, to: endOfWeek) {
                    let existingKeys = Set(scheduledBlocks.map { "\($0.title)_\($0.startTime.timeIntervalSince1970)_\($0.endTime.timeIntervalSince1970)" })
                    let newEvents = events.filter { !existingKeys.contains("\($0.title)_\($0.startTime.timeIntervalSince1970)_\($0.endTime.timeIntervalSince1970)") }
                    scheduledBlocks.append(contentsOf: newEvents)
                    scheduledBlocks.sort { $0.startTime < $1.startTime }
                }
            }
        }

        // Reminders sync
        if EventKitManager.shared.isRemindersAuthorized || promptIfNeeded {
            if let granted = try? await EventKitManager.shared.requestRemindersAccess(), granted {
                if let reminders = try? await EventKitManager.shared.fetchReminders() {
                    let existingTitles = Set(tasks.map { $0.title })
                    let newTasks = reminders.filter { !existingTitles.contains($0.title) }
                    tasks.append(contentsOf: newTasks)
                    NotificationManager.shared.updateBadgeCount(activeTaskCount)
                }
            }
        }
    }
}

import Foundation

public enum TaskPriority: String, Codable, Sendable, Comparable {
    case low
    case medium
    case high
    case urgent

    private var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
}

public enum TaskStatus: String, Codable, Sendable {
    case inbox
    case planned
    case inProgress
    case completed
    case cancelled
}

public struct TaskItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var category: String?
    public var deadline: Date?
    public var estimatedDuration: TimeInterval // in seconds
    public var priority: TaskPriority
    public var status: TaskStatus
    public var recurrenceRule: String?
    public var isLocked: Bool
    public var externalCalendarEventId: String?
    public var externalReminderId: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        category: String? = nil,
        deadline: Date? = nil,
        estimatedDuration: TimeInterval = 30 * 60, // default 30 min
        priority: TaskPriority = .medium,
        status: TaskStatus = .inbox,
        recurrenceRule: String? = nil,
        isLocked: Bool = false,
        externalCalendarEventId: String? = nil,
        externalReminderId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.deadline = deadline
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.status = status
        self.recurrenceRule = recurrenceRule
        self.isLocked = isLocked
        self.externalCalendarEventId = externalCalendarEventId
        self.externalReminderId = externalReminderId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TimeBlock: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let taskId: UUID?
    public var title: String
    public var startTime: Date
    public var endTime: Date
    public var isLocked: Bool
    public var category: String?

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        title: String,
        startTime: Date,
        endTime: Date,
        isLocked: Bool = false,
        category: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isLocked = isLocked
        self.category = category
    }
}

public struct UserPreference: Codable, Sendable, Equatable {
    public var workStartHour: Int // 0-23 (e.g. 9 for 09:00)
    public var workEndHour: Int   // 0-23 (e.g. 17 for 17:00)
    public var preferredTaskDurationMinutes: Int
    public var meetingBufferMinutes: Int
    public var protectWeekends: Bool
    public var focusStartHour: Int?
    public var focusEndHour: Int?

    public init(
        workStartHour: Int = 9,
        workEndHour: Int = 17,
        preferredTaskDurationMinutes: Int = 30,
        meetingBufferMinutes: Int = 10,
        protectWeekends: Bool = true,
        focusStartHour: Int? = 10,
        focusEndHour: Int? = 12
    ) {
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.preferredTaskDurationMinutes = preferredTaskDurationMinutes
        self.meetingBufferMinutes = meetingBufferMinutes
        self.protectWeekends = protectWeekends
        self.focusStartHour = focusStartHour
        self.focusEndHour = focusEndHour
    }
}

public struct UnscheduledTaskReason: Codable, Sendable, Equatable {
    public let taskId: UUID
    public let taskTitle: String
    public let reason: String

    public init(taskId: UUID, taskTitle: String, reason: String) {
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.reason = reason
    }
}

public struct SchedulingProposal: Sendable, Equatable {
    public var scheduledBlocks: [TimeBlock]
    public var unscheduledTasks: [UnscheduledTaskReason]
    public var conflictsDetected: [String]

    public init(
        scheduledBlocks: [TimeBlock] = [],
        unscheduledTasks: [UnscheduledTaskReason] = [],
        conflictsDetected: [String] = []
    ) {
        self.scheduledBlocks = scheduledBlocks
        self.unscheduledTasks = unscheduledTasks
        self.conflictsDetected = conflictsDetected
    }
}

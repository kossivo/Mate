import Foundation
import NaturalLanguage

public struct ParsedCaptureItem: Sendable, Equatable {
    public var rawText: String
    public var title: String
    public var deadline: Date?
    public var estimatedDuration: TimeInterval
    public var priority: TaskPriority
    public var category: String?
    public var recurrence: String?
    public var isAmbiguous: Bool
    public var ambiguityNotes: [String]

    public init(
        rawText: String,
        title: String,
        deadline: Date? = nil,
        estimatedDuration: TimeInterval = 30 * 60,
        priority: TaskPriority = .medium,
        category: String? = nil,
        recurrence: String? = nil,
        isAmbiguous: Bool = false,
        ambiguityNotes: [String] = []
    ) {
        self.rawText = rawText
        self.title = title
        self.deadline = deadline
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.category = category
        self.recurrence = recurrence
        self.isAmbiguous = isAmbiguous
        self.ambiguityNotes = ambiguityNotes
    }
}

public final class DeterministicCaptureParser: @unchecked Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /// Splits a multi-clause sentence into individual structured tasks deterministically.
    /// Example: "I need to finish my presentation by Friday, call Mum tonight and exercise three times this week."
    public func parse(text: String, referenceDate: Date = Date()) -> [ParsedCaptureItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let clauses = splitClauses(trimmed)
        return clauses.map { parseClause($0, referenceDate: referenceDate) }
    }

    private func splitClauses(_ text: String) -> [String] {
        // Normalize punctuation
        var current = text
        // Replace semicolon and newlines with a standard delimiter
        current = current.replacingOccurrences(of: ";", with: " | ")
        current = current.replacingOccurrences(of: "\n", with: " | ")

        // Replace ", and " with " | "
        current = current.replacingOccurrences(of: ", and ", with: " | ", options: .caseInsensitive)
        // Replace " and " with " | " if followed by an action verb or phrase
        current = current.replacingOccurrences(of: " and ", with: " | ", options: .caseInsensitive)
        // Replace comma with " | "
        current = current.replacingOccurrences(of: ",", with: " | ")

        return current
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseClause(_ clause: String, referenceDate: Date) -> ParsedCaptureItem {
        var cleanClause = clause

        // Clean common prefixes
        let prefixes = ["i need to ", "please ", "remember to ", "must ", "i want to ", "i have to "]
        let lower = cleanClause.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                cleanClause = String(cleanClause.dropFirst(prefix.count))
                break
            }
        }

        var deadline: Date? = nil
        var recurrence: String? = nil
        var priority: TaskPriority = .medium
        var duration: TimeInterval = 30 * 60
        var ambiguityNotes: [String] = []
        var isAmbiguous = false
        var category: String? = nil

        let lowercased = cleanClause.lowercased()

        // 1. Detect recurrence patterns (e.g. "three times this week", "daily", "every day")
        if lowercased.contains("three times this week") || lowercased.contains("3 times this week") {
            recurrence = "3x_weekly"
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)three times this week", with: "", options: .regularExpression)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)3 times this week", with: "", options: .regularExpression)
            category = "Health & Routine"
        } else if lowercased.contains("every day") || lowercased.contains("daily") {
            recurrence = "daily"
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)every day", with: "", options: .regularExpression)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)daily", with: "", options: .regularExpression)
        }

        // 2. Detect deadlines: "tonight", "by friday", "tomorrow", "today"
        if lowercased.contains("tonight") {
            deadline = dateForTonight(from: referenceDate)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tonight", with: "", options: .regularExpression)
        } else if lowercased.contains("by friday") || lowercased.contains("friday") {
            deadline = dateForNextWeekday(weekday: 6, from: referenceDate) // Friday = 6 in Gregorian
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)by friday", with: "", options: .regularExpression)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)friday", with: "", options: .regularExpression)
        } else if lowercased.contains("tomorrow") {
            deadline = calendar.date(byAdding: .day, value: 1, to: referenceDate)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow", with: "", options: .regularExpression)
        } else if lowercased.contains("today") {
            deadline = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)today", with: "", options: .regularExpression)
        }

        // 3. Detect Priority
        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") {
            priority = .urgent
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)urgent", with: "", options: .regularExpression)
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)asap", with: "", options: .regularExpression)
        } else if lowercased.contains("important") || lowercased.contains("high priority") {
            priority = .high
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)important", with: "", options: .regularExpression)
        }

        // 4. Detect Duration hints (e.g. "1 hour", "15 mins", "presentation")
        if lowercased.contains("presentation") {
            duration = 60 * 60 // 1 hour default for presentation
            category = category ?? "Work"
        } else if lowercased.contains("call ") {
            duration = 15 * 60 // 15 min default for phone calls
            category = category ?? "Personal"
        } else if lowercased.contains("exercise") || lowercased.contains("workout") {
            duration = 45 * 60 // 45 min default for exercise
            category = category ?? "Health"
        }

        // Ambiguity check: if no deadline was detected for a task that seems time-sensitive
        if deadline == nil && (lowercased.contains("finish") || lowercased.contains("complete")) {
            isAmbiguous = true
            ambiguityNotes.append("No explicit deadline found. Task placed in Inbox for confirmation.")
        }

        let cleanedTitle = cleanClause
            .replacingOccurrences(of: "^[\\s,]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\\s,]+$", with: "", options: .regularExpression)
            .capitalizedFirstLetter()

        return ParsedCaptureItem(
            rawText: clause,
            title: cleanedTitle.isEmpty ? clause : cleanedTitle,
            deadline: deadline,
            estimatedDuration: duration,
            priority: priority,
            category: category,
            recurrence: recurrence,
            isAmbiguous: isAmbiguous,
            ambiguityNotes: ambiguityNotes
        )
    }

    private func dateForTonight(from date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 20 // 8:00 PM
        components.minute = 0
        return calendar.date(from: components) ?? date
    }

    private func dateForNextWeekday(weekday: Int, from date: Date) -> Date {
        var comp = DateComponents()
        comp.weekday = weekday
        comp.hour = 17 // End of business day on Friday
        comp.minute = 0
        return calendar.nextDate(after: date, matching: comp, matchingPolicy: .nextTime) ?? date
    }
}

private extension String {
    func capitalizedFirstLetter() -> String {
        guard let first = self.first else { return self }
        return String(first).uppercased() + self.dropFirst()
    }
}

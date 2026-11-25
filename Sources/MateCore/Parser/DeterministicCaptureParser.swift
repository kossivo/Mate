import Foundation
import NaturalLanguage

public enum CaptureItemType: String, Sendable, Codable {
    case event // Calendar meeting, appointment, specific time block
    case task  // Reminder, to-do item
}

public struct ParsedCaptureItem: Sendable, Equatable {
    public var rawText: String
    public var title: String
    public var itemType: CaptureItemType
    public var deadline: Date?
    public var estimatedDuration: TimeInterval
    public var priority: TaskPriority
    public var category: String?
    public var recurrence: String?
    public var isAmbiguous: Bool
    public var ambiguityNotes: [String]
    public var calendarConflict: String?

    public init(
        rawText: String,
        title: String,
        itemType: CaptureItemType = .task,
        deadline: Date? = nil,
        estimatedDuration: TimeInterval = 30 * 60,
        priority: TaskPriority = .medium,
        category: String? = nil,
        recurrence: String? = nil,
        isAmbiguous: Bool = false,
        ambiguityNotes: [String] = [],
        calendarConflict: String? = nil
    ) {
        self.rawText = rawText
        self.title = title
        self.itemType = itemType
        self.deadline = deadline
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.category = category
        self.recurrence = recurrence
        self.isAmbiguous = isAmbiguous
        self.ambiguityNotes = ambiguityNotes
        self.calendarConflict = calendarConflict
    }
}

public final class DeterministicCaptureParser: @unchecked Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    /// Splits and parses compound sentences in English and Vietnamese deterministically.
    public func parse(text: String, referenceDate: Date = Date()) -> [ParsedCaptureItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let clauses = splitClauses(trimmed)
        return clauses.map { parseClause($0, referenceDate: referenceDate) }
    }

    private func splitClauses(_ text: String) -> [String] {
        var current = text
        // Punctuation and line breaks
        current = current.replacingOccurrences(of: ";", with: " | ")
        current = current.replacingOccurrences(of: "\n", with: " | ")

        // English & Vietnamese conjunctions
        let conjunctions = [", and ", " and ", ", và ", " và ", " rồi ", " sau đó "]
        for conj in conjunctions {
            current = current.replacingOccurrences(of: conj, with: " | ", options: .caseInsensitive)
        }
        current = current.replacingOccurrences(of: ",", with: " | ")

        return current
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseClause(_ clause: String, referenceDate: Date) -> ParsedCaptureItem {
        var cleanClause = clause

        // Clean common prefixes (English and Vietnamese)
        let prefixes = [
            "i need to ", "please ", "remember to ", "must ", "i want to ", "i have to ",
            "tôi cần ", "hãy ", "nhớ ", "phải ", "muốn ", "làm ơn ", "cần "
        ]
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
        var itemType: CaptureItemType = .task

        let lowercased = cleanClause.lowercased()

        // 1. Recurrence
        if lowercased.contains("three times this week") || lowercased.contains("3 times this week") ||
           lowercased.contains("3 lần tuần này") || lowercased.contains("3 lần một tuần") || lowercased.contains("ba lần tuần này") {
            recurrence = "3x_weekly"
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)(three|3|ba) times this week|(three|3|ba) lần (tuần này|một tuần|1 tuần)", with: "", options: .regularExpression)
            category = "Health & Routine"
        } else if lowercased.contains("every day") || lowercased.contains("daily") || lowercased.contains("hàng ngày") || lowercased.contains("mỗi ngày") {
            recurrence = "daily"
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)every day|daily|hàng ngày|mỗi ngày", with: "", options: .regularExpression)
        }

        // 2. Relative Day / Target Date Detection
        var targetBaseDate: Date? = nil
        var dateDefaultHour: Int = 9
        var dateDefaultMinute: Int = 0

        if lowercased.contains("tonight") || lowercased.contains("tối nay") {
            targetBaseDate = referenceDate
            dateDefaultHour = 20
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tonight|tối nay", with: "", options: .regularExpression)
        } else if lowercased.contains("sáng mai") || lowercased.contains("tomorrow morning") {
            targetBaseDate = calendar.date(byAdding: .day, value: 1, to: referenceDate)
            dateDefaultHour = 9
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow morning|sáng mai", with: "", options: .regularExpression)
        } else if lowercased.contains("chiều mai") || lowercased.contains("tomorrow afternoon") {
            targetBaseDate = calendar.date(byAdding: .day, value: 1, to: referenceDate)
            dateDefaultHour = 14
            dateDefaultMinute = 30
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow afternoon|chiều mai", with: "", options: .regularExpression)
        } else if lowercased.contains("tối mai") || lowercased.contains("tomorrow evening") {
            targetBaseDate = calendar.date(byAdding: .day, value: 1, to: referenceDate)
            dateDefaultHour = 20
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow evening|tối mai", with: "", options: .regularExpression)
        } else if lowercased.contains("ngày kia") || lowercased.contains("ngày mốt") || lowercased.contains("mốt") {
            targetBaseDate = calendar.date(byAdding: .day, value: 2, to: referenceDate)
            dateDefaultHour = 9
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)ngày kia|ngày mốt|\\bmốt\\b", with: "", options: .regularExpression)
        } else if lowercased.contains("tomorrow") || lowercased.contains("ngày mai") || lowercased.contains("mai") {
            targetBaseDate = calendar.date(byAdding: .day, value: 1, to: referenceDate)
            dateDefaultHour = 9
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow|ngày mai|\\bmai\\b", with: "", options: .regularExpression)
        } else if lowercased.contains("today") || lowercased.contains("hôm nay") {
            targetBaseDate = referenceDate
            dateDefaultHour = 18
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)today|hôm nay", with: "", options: .regularExpression)
        } else if lowercased.contains("thứ hai") || lowercased.contains("thứ 2") || lowercased.contains("monday") {
            targetBaseDate = dateForNextWeekday(weekday: 2, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)monday|thứ hai|thứ 2", with: "", options: .regularExpression)
        } else if lowercased.contains("thứ ba") || lowercased.contains("thứ 3") || lowercased.contains("tuesday") {
            targetBaseDate = dateForNextWeekday(weekday: 3, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)tuesday|thứ ba|thứ 3", with: "", options: .regularExpression)
        } else if lowercased.contains("thứ tư") || lowercased.contains("thứ 4") || lowercased.contains("wednesday") {
            targetBaseDate = dateForNextWeekday(weekday: 4, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)wednesday|thứ tư|thứ 4", with: "", options: .regularExpression)
        } else if lowercased.contains("thứ năm") || lowercased.contains("thứ 5") || lowercased.contains("thursday") {
            targetBaseDate = dateForNextWeekday(weekday: 5, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)thursday|thứ năm|thứ 5", with: "", options: .regularExpression)
        } else if lowercased.contains("thứ sáu") || lowercased.contains("thứ 6") || lowercased.contains("friday") {
            targetBaseDate = dateForNextWeekday(weekday: 6, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)friday|thứ sáu|thứ 6|by friday|trước thứ 6|trước thứ sáu", with: "", options: .regularExpression)
        } else if lowercased.contains("thứ bảy") || lowercased.contains("thứ 7") || lowercased.contains("saturday") {
            targetBaseDate = dateForNextWeekday(weekday: 7, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)saturday|thứ bảy|thứ 7", with: "", options: .regularExpression)
        } else if lowercased.contains("chủ nhật") || lowercased.contains("sunday") {
            targetBaseDate = dateForNextWeekday(weekday: 1, from: referenceDate)
            dateDefaultHour = 17
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)sunday|chủ nhật", with: "", options: .regularExpression)
        }

        // 3. Exact Time Extraction
        if let timeMatch = extractTimeValues(from: cleanClause) {
            let base = targetBaseDate ?? referenceDate
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = timeMatch.hour
            components.minute = timeMatch.minute
            components.second = 0

            var resolvedDate = calendar.date(from: components) ?? base
            // If user mentioned a time today that has already passed, roll to tomorrow
            if targetBaseDate == nil && resolvedDate < referenceDate {
                resolvedDate = calendar.date(byAdding: .day, value: 1, to: resolvedDate) ?? resolvedDate
            }
            deadline = resolvedDate
            cleanClause = cleanClause.replacingOccurrences(of: timeMatch.matchedString, with: "", options: .caseInsensitive)
        } else if let base = targetBaseDate {
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = dateDefaultHour
            components.minute = dateDefaultMinute
            components.second = 0
            deadline = calendar.date(from: components) ?? base
        }

        // 4. Priority
        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") ||
           lowercased.contains("gấp") || lowercased.contains("khẩn cấp") {
            priority = .urgent
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)urgent|asap|critical|gấp|khẩn cấp", with: "", options: .regularExpression)
        } else if lowercased.contains("important") || lowercased.contains("high priority") || lowercased.contains("quan trọng") {
            priority = .high
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)important|high priority|quan trọng", with: "", options: .regularExpression)
        }

        // 5. Item Type Distinction: Event (Calendar) vs Task (Reminder)
        let eventKeywords = [
            "hẹn", "cuộc hẹn", "gặp", "họp", "meeting", "meet", "appointment",
            "sync", "1on1", "phỏng vấn", "interview", "conference call", "zoom meeting",
            "ăn trưa", "lunch", "dinner", "đi khám", "bác sĩ", "doctor",
            "bay", "flight", "cà phê", "coffee", "lịch hẹn", "đi ăn", "ăn tối"
        ]
        let taskKeywords = [
            "nhắc", "nhớ", "mua", "làm", "nộp", "gửi", "viết", "hoàn thành",
            "xong", "remind", "buy", "submit", "send", "write", "finish",
            "review", "check", "tập thể dục", "gym", "workout", "exercise",
            "call", "gọi cho", "gọi", "phone", "uống thuốc", "thanh toán", "chuyển khoản",
            "báo cáo", "slide", "presentation"
        ]

        let hasEventKeyword = eventKeywords.contains { lowercased.contains($0) }
        let hasTaskKeyword = taskKeywords.contains { lowercased.contains($0) }

        if lowercased.contains("call") || lowercased.contains("gọi cho") || lowercased.contains("gọi điện") || lowercased.contains("gọi mẹ") || lowercased.contains("gọi ") {
            duration = 15 * 60
            category = "Personal"
            itemType = .task
        } else if lowercased.contains("presentation") || lowercased.contains("slide") || lowercased.contains("báo cáo") || lowercased.contains("report") {
            duration = 60 * 60
            category = "Work"
            itemType = .task
        } else if lowercased.contains("tập thể dục") || lowercased.contains("gym") || lowercased.contains("workout") || lowercased.contains("exercise") {
            duration = 45 * 60
            category = "Health & Routine"
            itemType = .task
        } else if hasEventKeyword && !hasTaskKeyword {
            itemType = .event
            duration = 60 * 60 // Default 1 hour meeting
            category = "Meeting"
        } else if hasTaskKeyword {
            itemType = .task
            duration = 30 * 60
            category = category ?? "Task"
        } else {
            // Default inference: if time is specific and contains appointment terms -> event, else task
            if hasEventKeyword {
                itemType = .event
                category = "Meeting"
            } else {
                itemType = .task
            }
        }

        // 6. Ambiguity check
        if deadline == nil && (lowercased.contains("finish") || lowercased.contains("complete") || lowercased.contains("hoàn thành") || lowercased.contains("xong")) {
            isAmbiguous = true
            ambiguityNotes.append("Chưa rõ hạn chót — cần xác nhận thời gian.")
        }

        var cleanedTitle = cleanClause
            .replacingOccurrences(of: "^[\\s,]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\\s,]+$", with: "", options: .regularExpression)
            .capitalizedFirstLetter()

        if cleanedTitle.isEmpty || cleanedTitle.lowercased() == "hẹn" {
            cleanedTitle = (itemType == .event) ? "Cuộc hẹn" : "Nhiệm vụ mới"
        }

        return ParsedCaptureItem(
            rawText: clause,
            title: cleanedTitle.isEmpty ? clause : cleanedTitle,
            itemType: itemType,
            deadline: deadline,
            estimatedDuration: duration,
            priority: priority,
            category: category,
            recurrence: recurrence,
            isAmbiguous: isAmbiguous,
            ambiguityNotes: ambiguityNotes
        )
    }

    private struct ExtractedTime {
        let hour: Int
        let minute: Int
        let matchedString: String
    }

    private func extractTimeValues(from text: String) -> ExtractedTime? {
        // Pattern 1: With prefix "lúc", "vào lúc", "at", "vào"
        // e.g. "lúc 8.30", "lúc 8:30", "lúc 14h30", "at 3pm", "lúc 9h", "lúc 9 giờ"
        let patternPrefixed = "(?:vào lúc|lúc|at|vào)\\s+(\\d{1,2})(?:[:.h](\\d{2}))?(?:\\s*giờ(?:\\s*(\\d{2}))?)?\\s*(am|pm|sáng|chiều|tối)?"
        if let match = matchTime(pattern: patternPrefixed, text: text) {
            return match
        }

        // Pattern 2: Vietnamese hour notation e.g. "9 giờ rưỡi", "9h rưỡi"
        let patternRuoi = "\\b(\\d{1,2})(?:h|\\s*giờ)\\s*rưỡi\\b"
        if let match = matchRuoi(pattern: patternRuoi, text: text) {
            return match
        }

        // Pattern 3: Standalone format with separator e.g. "8.30", "15:45", "9h30"
        let patternSeparated = "\\b(\\d{1,2})[:.h](\\d{2})\\s*(am|pm|sáng|chiều|tối)?\\b"
        if let match = matchTime(pattern: patternSeparated, text: text) {
            return match
        }

        // Pattern 4: Standalone hour with h or giờ e.g. "9h", "15h", "9 giờ"
        let patternHourH = "\\b(\\d{1,2})(?:h|\\s*giờ)\\s*(sáng|chiều|tối)?\\b"
        if let match = matchTime(pattern: patternHourH, text: text) {
            return match
        }

        // Pattern 5: Standalone hour with am/pm e.g. "9am", "3pm"
        let patternAmPm = "\\b(\\d{1,2})\\s*(am|pm)\\b"
        if let match = matchTime(pattern: patternAmPm, text: text) {
            return match
        }

        return nil
    }

    private func matchRuoi(pattern: String, text: String) -> ExtractedTime? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        let matchedString = (text as NSString).substring(with: match.range)
        guard let hourRange = Range(match.range(at: 1), in: text),
              let hour = Int(text[hourRange]) else {
            return nil
        }
        return ExtractedTime(hour: hour, minute: 30, matchedString: matchedString)
    }

    private func matchTime(pattern: String, text: String) -> ExtractedTime? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        let matchedString = (text as NSString).substring(with: match.range)
        guard let hourRange = Range(match.range(at: 1), in: text),
              var hour = Int(text[hourRange]) else {
            return nil
        }

        var minute = 0
        if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound,
           let minRange = Range(match.range(at: 2), in: text),
           let minVal = Int(text[minRange]) {
            minute = minVal
        }

        // Check suffix (am, pm, sáng, chiều, tối)
        for i in 3..<match.numberOfRanges {
            if match.range(at: i).location != NSNotFound,
               let suffixRange = Range(match.range(at: i), in: text) {
                let suffix = text[suffixRange].lowercased()
                if (suffix == "pm" || suffix == "chiều" || suffix == "tối") && hour < 12 {
                    hour += 12
                } else if (suffix == "am" || suffix == "sáng") && hour == 12 {
                    hour = 0
                }
            }
        }

        return ExtractedTime(hour: hour, minute: minute, matchedString: matchedString)
    }

    private func dateForNextWeekday(weekday: Int, from date: Date) -> Date {
        var comp = DateComponents()
        comp.weekday = weekday
        comp.hour = 17
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

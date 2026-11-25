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

        // 2. Deadlines (Exact time or day)
        // Check for specific hour regex: "lúc 14h30", "lúc 15:00", "at 3pm", "lúc 9h"
        if let timeMatch = extractTimeComponents(from: lowercased, referenceDate: referenceDate) {
            deadline = timeMatch.date
            cleanClause = cleanClause.replacingOccurrences(of: timeMatch.matchedString, with: "", options: .caseInsensitive)
        }

        // Relative days in English & Vietnamese
        if deadline == nil {
            if lowercased.contains("tonight") || lowercased.contains("tối nay") {
                deadline = dateForTonight(from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)tonight|tối nay", with: "", options: .regularExpression)
            } else if lowercased.contains("sáng mai") || lowercased.contains("tomorrow morning") {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
                deadline = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow morning|sáng mai", with: "", options: .regularExpression)
            } else if lowercased.contains("chiều mai") || lowercased.contains("tomorrow afternoon") {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
                deadline = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: tomorrow)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow afternoon|chiều mai", with: "", options: .regularExpression)
            } else if lowercased.contains("tối mai") || lowercased.contains("tomorrow evening") {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
                deadline = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: tomorrow)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow evening|tối mai", with: "", options: .regularExpression)
            } else if lowercased.contains("tomorrow") || lowercased.contains("ngày mai") || lowercased.contains("mai") {
                deadline = calendar.date(byAdding: .day, value: 1, to: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)tomorrow|ngày mai|\\bmai\\b", with: "", options: .regularExpression)
            } else if lowercased.contains("today") || lowercased.contains("hôm nay") {
                deadline = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)today|hôm nay", with: "", options: .regularExpression)
            } else if lowercased.contains("thứ hai") || lowercased.contains("thứ 2") || lowercased.contains("monday") {
                deadline = dateForNextWeekday(weekday: 2, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)monday|thứ hai|thứ 2", with: "", options: .regularExpression)
            } else if lowercased.contains("thứ ba") || lowercased.contains("thứ 3") || lowercased.contains("tuesday") {
                deadline = dateForNextWeekday(weekday: 3, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)tuesday|thứ ba|thứ 3", with: "", options: .regularExpression)
            } else if lowercased.contains("thứ tư") || lowercased.contains("thứ 4") || lowercased.contains("wednesday") {
                deadline = dateForNextWeekday(weekday: 4, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)wednesday|thứ tư|thứ 4", with: "", options: .regularExpression)
            } else if lowercased.contains("thứ năm") || lowercased.contains("thứ 5") || lowercased.contains("thursday") {
                deadline = dateForNextWeekday(weekday: 5, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)thursday|thứ năm|thứ 5", with: "", options: .regularExpression)
            } else if lowercased.contains("thứ sáu") || lowercased.contains("thứ 6") || lowercased.contains("friday") {
                deadline = dateForNextWeekday(weekday: 6, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)friday|thứ sáu|thứ 6|by friday|trước thứ 6|trước thứ sáu", with: "", options: .regularExpression)
            } else if lowercased.contains("thứ bảy") || lowercased.contains("thứ 7") || lowercased.contains("saturday") {
                deadline = dateForNextWeekday(weekday: 7, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)saturday|thứ bảy|thứ 7", with: "", options: .regularExpression)
            } else if lowercased.contains("chủ nhật") || lowercased.contains("sunday") {
                deadline = dateForNextWeekday(weekday: 1, from: referenceDate)
                cleanClause = cleanClause.replacingOccurrences(of: "(?i)sunday|chủ nhật", with: "", options: .regularExpression)
            }
        }

        // 3. Priority
        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") ||
           lowercased.contains("gấp") || lowercased.contains("khẩn cấp") {
            priority = .urgent
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)urgent|asap|critical|gấp|khẩn cấp", with: "", options: .regularExpression)
        } else if lowercased.contains("important") || lowercased.contains("high priority") || lowercased.contains("quan trọng") {
            priority = .high
            cleanClause = cleanClause.replacingOccurrences(of: "(?i)important|high priority|quan trọng", with: "", options: .regularExpression)
        }

        // 4. Duration & Category inferences
        if lowercased.contains("presentation") || lowercased.contains("slide") || lowercased.contains("báo cáo") || lowercased.contains("report") {
            duration = 60 * 60
            category = category ?? "Work"
        } else if lowercased.contains("call ") || lowercased.contains("gọi cho") || lowercased.contains("gọi điện") {
            duration = 15 * 60
            category = category ?? "Personal"
        } else if lowercased.contains("exercise") || lowercased.contains("workout") || lowercased.contains("tập thể dục") || lowercased.contains("gym") || lowercased.contains("chạy bộ") {
            duration = 45 * 60
            category = category ?? "Health"
        } else if lowercased.contains("họp") || lowercased.contains("meeting") || lowercased.contains("sync") {
            duration = 30 * 60
            category = category ?? "Work"
        } else if lowercased.contains("cà phê") || lowercased.contains("coffee") || lowercased.contains("ăn trưa") || lowercased.contains("lunch") {
            duration = 45 * 60
            category = category ?? "Social"
        }

        // Ambiguity check
        if deadline == nil && (lowercased.contains("finish") || lowercased.contains("complete") || lowercased.contains("hoàn thành") || lowercased.contains("xong")) {
            isAmbiguous = true
            ambiguityNotes.append("Chưa rõ hạn chót — chuyển vào Hộp thư để bạn xác nhận.")
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

    private func extractTimeComponents(from text: String, referenceDate: Date) -> (date: Date, matchedString: String)? {
        // Match patterns like: "lúc 15:30", "lúc 15h30", "lúc 9h", "at 14:00", "at 3pm"
        let pattern = "(?:lúc|at)\\s+(\\d{1,2})(?:[:h](\\d{2}))?\\s*(am|pm)?"
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
        if match.range(at: 2).location != NSNotFound,
           let minRange = Range(match.range(at: 2), in: text),
           let minVal = Int(text[minRange]) {
            minute = minVal
        }

        if match.range(at: 3).location != NSNotFound,
           let ampmRange = Range(match.range(at: 3), in: text) {
            let ampm = text[ampmRange].lowercased()
            if ampm == "pm" && hour < 12 {
                hour += 12
            } else if ampm == "am" && hour == 12 {
                hour = 0
            }
        }

        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let date = calendar.date(from: components) ?? referenceDate
        return (date, matchedString)
    }

    private func dateForTonight(from date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 20
        components.minute = 0
        return calendar.date(from: components) ?? date
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

import Foundation
import UserNotifications

public final class NotificationManager: @unchecked Sendable {
    public static let shared = NotificationManager()

    public init() {}

    public func requestNotificationPermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted
    }

    /// Schedules a follow-up action trigger 5 minutes after a meeting finishes.
    public func schedulePostMeetingFollowUp(meetingTitle: String, meetingEndTime: Date, locale: String = "vi") {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        if locale == "vi" {
            content.title = "Cuộc họp vừa kết thúc"
            content.body = "Bạn vừa hoàn thành '\(meetingTitle)'. Chạm để lưu lại việc cần làm tiếp theo!"
        } else {
            content.title = "Meeting Ended"
            content.body = "You wrapped up '\(meetingTitle)'. Tap to capture action items or follow-ups!"
        }
        content.sound = .default

        let triggerDate = meetingEndTime.addingTimeInterval(5 * 60) // 5 mins after
        let comp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)

        let request = UNNotificationRequest(
            identifier: "followup-\(meetingTitle.hashValue)-\(meetingEndTime.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }

    /// Schedules a reminder alert for a task at its specified deadline/time.
    public func scheduleTaskReminder(title: String, reminderDate: Date, id: UUID = UUID()) {
        guard reminderDate > Date() else { return }
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Nhắc nhở: \(title)"
        content.body = "Đã đến giờ hoàn thành: \(title)"
        content.sound = .default

        let comp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)

        let request = UNNotificationRequest(
            identifier: "task-\(id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }

    /// Sets the app badge count showing remaining incomplete tasks for today.
    public func updateBadgeCount(_ count: Int) {
        if #available(iOS 16.0, macOS 13.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        }
    }
}

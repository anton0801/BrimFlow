//
//  NotificationManager.swift
//  BrimFlow
//
//  Wraps UNUserNotificationCenter: authorization plus scheduling of sip
//  reminders, an evening goal check, weekly summaries, and per-task reminders.
//

import Foundation
import UserNotifications
import Combine

final class NotificationManager: ObservableObject {

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let sipPrefix = "brim.sip."
        static let goal = "brim.goal"
        static let weekly = "brim.weekly"
        static let taskPrefix = "brim.task."
    }

    init() { refreshAuthorizationStatus() }

    // MARK: - Authorization

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Requests permission; calls back with the granted flag on the main thread.
    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.refreshAuthorizationStatus()
                completion?(granted)
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - Scheduling

    /// Cancels every Brim Flow notification, then re-creates them from the
    /// current settings and task list. Called whenever relevant state changes.
    func reschedule(settings: AppSettings, tasks: [ReminderTask]) {
        center.removeAllPendingNotificationRequests()

        guard isAuthorized else { return }

        if settings.sipRemindersEnabled {
            scheduleSipReminders(settings: settings)
        }
        if settings.goalReminderEnabled {
            scheduleGoalReminder(settings: settings)
        }
        if settings.weeklySummaryEnabled {
            scheduleWeeklySummary()
        }
        for task in tasks where task.notificationsEnabled {
            scheduleTaskReminder(task)
        }
    }

    private func add(_ content: UNMutableNotificationContent,
                     id: String,
                     trigger: UNNotificationTrigger) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// One reminder at every interval step between wake and sleep hours.
    private func scheduleSipReminders(settings: AppSettings) {
        let interval = max(30, settings.reminderIntervalMinutes)
        let start = settings.wakeHour * 60
        let end = settings.sleepHour * 60
        guard end > start else { return }

        var minute = start
        var index = 0
        // Cap at 30 reminders to stay well under the 64 pending limit.
        while minute <= end && index < 30 {
            let content = UNMutableNotificationContent()
            content.title = "Time for a sip 💧"
            content.body = "Keep the glass rising — take a drink of water."
            content.sound = .default

            var comps = DateComponents()
            comps.hour = minute / 60
            comps.minute = minute % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            add(content, id: ID.sipPrefix + "\(index)", trigger: trigger)

            minute += interval
            index += 1
        }
    }

    /// Evening nudge if the goal might not be reached yet.
    private func scheduleGoalReminder(settings: AppSettings) {
        let content = UNMutableNotificationContent()
        content.title = "Goal check 🎯"
        content.body = "Have you reached your hydration goal today? A glass or two can close the gap."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = max(settings.wakeHour, settings.sleepHour - 2)
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        add(content, id: ID.goal, trigger: trigger)
    }

    /// Monday morning weekly recap.
    private func scheduleWeeklySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Your weekly flow 📊"
        content.body = "Check your hydration report for last week's progress and streak."
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = 2 // Monday
        comps.hour = 9
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        add(content, id: ID.weekly, trigger: trigger)
    }

    private func scheduleTaskReminder(_ task: ReminderTask) {
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = "Reminder from Brim Flow."
        content.sound = .default

        if task.weekdays.isEmpty {
            var comps = DateComponents()
            comps.hour = task.hour
            comps.minute = task.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            add(content, id: ID.taskPrefix + task.id.uuidString, trigger: trigger)
        } else {
            for weekday in task.weekdays {
                var comps = DateComponents()
                comps.weekday = weekday
                comps.hour = task.hour
                comps.minute = task.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                add(content, id: ID.taskPrefix + task.id.uuidString + ".\(weekday)", trigger: trigger)
            }
        }
    }

    /// For verification / debugging — reports how many notifications are pending.
    func pendingCount(_ completion: @escaping (Int) -> Void) {
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async { completion(requests.count) }
        }
    }
}

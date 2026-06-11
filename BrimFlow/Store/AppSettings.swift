//
//  AppSettings.swift
//  BrimFlow
//
//  App-wide preferences (theme, units, reminders) persisted to UserDefaults.
//  Published so a change recolors / re-labels the entire app immediately.
//

import SwiftUI
import Combine

final class AppSettings: ObservableObject {

    private enum Keys {
        static let theme = "settings.theme"
        static let units = "settings.units"
        static let interval = "settings.reminderInterval"
        static let wakeHour = "settings.wakeHour"
        static let sleepHour = "settings.sleepHour"
        static let sipReminders = "settings.notif.sip"
        static let goalReminder = "settings.notif.goal"
        static let weeklySummary = "settings.notif.weekly"
        static let lastWeight = "settings.lastWeight"
        static let lastActivity = "settings.lastActivity"
    }

    private let defaults = UserDefaults.standard

    // MARK: - Theme

    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    // MARK: - Units

    @Published var units: Units {
        didSet { defaults.set(units.rawValue, forKey: Keys.units) }
    }

    // MARK: - Reminders

    /// Minutes between sip reminders.
    @Published var reminderIntervalMinutes: Int {
        didSet { defaults.set(reminderIntervalMinutes, forKey: Keys.interval) }
    }

    /// Hour (0-23) the user typically wakes — reminders start here.
    @Published var wakeHour: Int {
        didSet { defaults.set(wakeHour, forKey: Keys.wakeHour) }
    }

    /// Hour (0-23) the user typically sleeps — reminders stop here.
    @Published var sleepHour: Int {
        didSet { defaults.set(sleepHour, forKey: Keys.sleepHour) }
    }

    @Published var sipRemindersEnabled: Bool {
        didSet { defaults.set(sipRemindersEnabled, forKey: Keys.sipReminders) }
    }

    @Published var goalReminderEnabled: Bool {
        didSet { defaults.set(goalReminderEnabled, forKey: Keys.goalReminder) }
    }

    @Published var weeklySummaryEnabled: Bool {
        didSet { defaults.set(weeklySummaryEnabled, forKey: Keys.weeklySummary) }
    }

    // MARK: - Goal calculator memory

    @Published var lastWeightKg: Double {
        didSet { defaults.set(lastWeightKg, forKey: Keys.lastWeight) }
    }

    @Published var lastActivity: ActivityLevel {
        didSet { defaults.set(lastActivity.rawValue, forKey: Keys.lastActivity) }
    }

    // MARK: - Init

    init() {
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        units = Units(rawValue: defaults.string(forKey: Keys.units) ?? "") ?? .ml
        reminderIntervalMinutes = defaults.object(forKey: Keys.interval) as? Int ?? 120
        wakeHour = defaults.object(forKey: Keys.wakeHour) as? Int ?? 8
        sleepHour = defaults.object(forKey: Keys.sleepHour) as? Int ?? 22
        sipRemindersEnabled = defaults.object(forKey: Keys.sipReminders) as? Bool ?? true
        goalReminderEnabled = defaults.object(forKey: Keys.goalReminder) as? Bool ?? true
        weeklySummaryEnabled = defaults.object(forKey: Keys.weeklySummary) as? Bool ?? false
        lastWeightKg = defaults.object(forKey: Keys.lastWeight) as? Double ?? 70
        lastActivity = ActivityLevel(rawValue: defaults.string(forKey: Keys.lastActivity) ?? "") ?? .moderate
    }

    // MARK: - Helpers

    /// Formats a milliliter amount in the user's chosen unit.
    func formatAmount(_ ml: Double) -> String { units.format(ml) }

    /// Reminder interval label (e.g. "Every 2 h", "Every 90 min").
    var intervalLabel: String {
        if reminderIntervalMinutes % 60 == 0 {
            let h = reminderIntervalMinutes / 60
            return h == 1 ? "Every hour" : "Every \(h) h"
        }
        return "Every \(reminderIntervalMinutes) min"
    }

    static let intervalOptions = [30, 60, 90, 120, 180, 240]
}

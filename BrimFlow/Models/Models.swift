//
//  Models.swift
//  BrimFlow
//
//  Codable domain models and enums. Pure data — no business logic.
//

import SwiftUI

// MARK: - Units

enum Units: String, Codable, CaseIterable, Identifiable {
    case ml
    case oz

    var id: String { rawValue }
    var label: String { self == .ml ? "Milliliters (ml)" : "Ounces (oz)" }
    var short: String { self == .ml ? "ml" : "oz" }

    /// Converts an internal milliliter value into the display unit.
    func fromML(_ value: Double) -> Double {
        self == .ml ? value : value / 29.5735
    }

    /// Converts a value entered in the display unit back into milliliters.
    func toML(_ value: Double) -> Double {
        self == .ml ? value : value * 29.5735
    }

    /// A formatted string for a milliliter amount in the current unit.
    func format(_ ml: Double) -> String {
        let v = fromML(ml)
        if self == .ml {
            return "\(Int(v.rounded())) ml"
        } else {
            return String(format: "%.1f oz", v)
        }
    }
}

// MARK: - Theme

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Drink category

enum DrinkCategory: String, Codable, CaseIterable, Identifiable {
    case water
    case tea
    case coffee
    case juice
    case other

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var defaultIcon: String {
        switch self {
        case .water: return "drop.fill"
        case .tea: return "cup.and.saucer.fill"
        case .coffee: return "mug.fill"
        case .juice: return "takeoutbag.and.cup.and.straw.fill"
        case .other: return "waterbottle.fill"
        }
    }
}

// MARK: - Record category

enum RecordCategory: String, Codable, CaseIterable, Identifiable {
    case drink
    case note

    var id: String { rawValue }
    var label: String { self == .drink ? "Drink" : "Note" }
    var icon: String { self == .drink ? "drop.fill" : "note.text" }
}

// MARK: - Drink preset

struct DrinkPreset: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: DrinkCategory
    var defaultVolumeML: Double
    /// Hydration efficiency 0...1 (e.g. coffee 0.6 means 60% counts toward goal).
    var hydrationFactor: Double
    var colorHex: String
    var iconName: String
    var isArchived: Bool = false

    var color: Color { Color(hex: colorHex) }

    /// Default seed presets created on first launch.
    static var seed: [DrinkPreset] {
        [
            DrinkPreset(name: "Water", category: .water, defaultVolumeML: 250,
                        hydrationFactor: 1.0, colorHex: "#06B6D4", iconName: "drop.fill"),
            DrinkPreset(name: "Sparkling", category: .water, defaultVolumeML: 330,
                        hydrationFactor: 1.0, colorHex: "#22D3EE", iconName: "bubbles.and.sparkles.fill"),
            DrinkPreset(name: "Tea", category: .tea, defaultVolumeML: 200,
                        hydrationFactor: 0.9, colorHex: "#34D399", iconName: "cup.and.saucer.fill"),
            DrinkPreset(name: "Coffee", category: .coffee, defaultVolumeML: 150,
                        hydrationFactor: 0.6, colorHex: "#B45309", iconName: "mug.fill"),
            DrinkPreset(name: "Juice", category: .juice, defaultVolumeML: 200,
                        hydrationFactor: 0.8, colorHex: "#FB923C", iconName: "takeoutbag.and.cup.and.straw.fill")
        ]
    }
}

// MARK: - Water entry

struct WaterEntry: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var date: Date
    /// Raw poured amount in ml (before hydration factor).
    var amountML: Double
    var drinkID: UUID?
    var title: String
    var comment: String
    var category: RecordCategory

    /// Hydration-effective ml given a drink lookup; notes contribute 0.
    func effectiveML(using drinks: [DrinkPreset]) -> Double {
        guard category == .drink else { return 0 }
        let factor = drinks.first(where: { $0.id == drinkID })?.hydrationFactor ?? 1.0
        return amountML * factor
    }
}

// MARK: - Reminder task

enum TaskKind: String, Codable, CaseIterable, Identifiable {
    case sip
    case habit
    case custom

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .sip: return "drop.fill"
        case .habit: return "repeat"
        case .custom: return "bell.fill"
        }
    }
}

struct ReminderTask: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    /// Time of day represented as minutes from midnight.
    var minuteOfDay: Int
    /// 1 = Sunday ... 7 = Saturday (matches Calendar weekday). Empty = every day.
    var weekdays: Set<Int>
    var isDone: Bool = false
    var lastCompleted: Date?
    var kind: TaskKind = .habit
    var notificationsEnabled: Bool = true

    var hour: Int { minuteOfDay / 60 }
    var minute: Int { minuteOfDay % 60 }

    var timeLabel: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    var repeatLabel: String {
        if weekdays.isEmpty || weekdays.count == 7 { return "Every day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().compactMap { idx in
            (idx >= 1 && idx <= symbols.count) ? symbols[idx - 1] : nil
        }.joined(separator: " ")
    }

    /// Whether the task is scheduled for today.
    func isToday(_ calendar: Calendar = .current) -> Bool {
        if weekdays.isEmpty { return true }
        return weekdays.contains(calendar.component(.weekday, from: Date()))
    }

    /// True when the task is overdue today and not yet completed.
    func isMissed(_ now: Date = Date()) -> Bool {
        guard isToday(), !isDoneToday() else { return false }
        let minutesNow = Calendar.current.component(.hour, from: now) * 60
            + Calendar.current.component(.minute, from: now)
        return minutesNow > minuteOfDay
    }

    func isDoneToday(_ calendar: Calendar = .current) -> Bool {
        guard let last = lastCompleted else { return false }
        return calendar.isDateInToday(last)
    }
}

// MARK: - Moment

enum MomentCategory: String, Codable, CaseIterable, Identifiable {
    case fresh
    case thirsty
    case tired
    case active

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .fresh: return "leaf.fill"
        case .thirsty: return "drop.degreesign.fill"
        case .tired: return "zzz"
        case .active: return "figure.run"
        }
    }
    var colorHex: String {
        switch self {
        case .fresh: return "#22C55E"
        case .thirsty: return "#FB7185"
        case .tired: return "#FBBF24"
        case .active: return "#06B6D4"
        }
    }
    var color: Color { Color(hex: colorHex) }
}

struct Moment: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var category: MomentCategory
    var note: String
}

// MARK: - Activity level (used by the goal calculator)

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high

    var id: String { rawValue }
    var label: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
    /// Extra ml per kg added on top of the base requirement.
    var bonusPerKg: Double {
        switch self {
        case .low: return 0
        case .moderate: return 6
        case .high: return 12
        }
    }
    var icon: String {
        switch self {
        case .low: return "figure.seated.side"
        case .moderate: return "figure.walk"
        case .high: return "figure.run"
        }
    }
}

// MARK: - Day status

enum DayStatus: String {
    case met
    case progress
    case behind
    case low
    case empty

    var color: Color {
        switch self {
        case .met: return BFColor.statusMet
        case .progress: return BFColor.statusProgress
        case .behind: return BFColor.statusBehind
        case .low: return BFColor.statusLow
        case .empty: return BFColor.dividerSoft
        }
    }
    var label: String {
        switch self {
        case .met: return "Goal met"
        case .progress: return "In progress"
        case .behind: return "Behind"
        case .low: return "Very low"
        case .empty: return "No log"
        }
    }

    /// Derives a status from a fraction of the daily goal.
    static func from(progress: Double, hasLog: Bool) -> DayStatus {
        if !hasLog { return .empty }
        if progress >= 1.0 { return .met }
        if progress >= 0.6 { return .progress }
        if progress >= 0.3 { return .behind }
        return .low
    }
}

// MARK: - Goal calculator

enum GoalCalculator {
    /// Standard recommendation: ~35 ml per kg of body weight + an activity bonus.
    static func recommended(weightKg: Double, activity: ActivityLevel) -> Double {
        let base = weightKg * 35
        let bonus = weightKg * activity.bonusPerKg
        let total = base + bonus
        // Clamp to a sensible range and round to the nearest 50 ml.
        let clamped = min(max(total, 1200), 5000)
        return (clamped / 50).rounded() * 50
    }
}

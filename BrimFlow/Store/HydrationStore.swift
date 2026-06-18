//
//  HydrationStore.swift
//  BrimFlow
//
//  Single source of truth for all hydration data. Owns CRUD, derived metrics,
//  an undo stack, and JSON persistence to the Documents directory.
//

import SwiftUI
import Combine

final class HydrationStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var entries: [WaterEntry] = []
    @Published var drinks: [DrinkPreset] = [] { didSet { scheduleSave() } }
    @Published var tasks: [ReminderTask] = [] { didSet { scheduleSave() } }
    @Published var moments: [Moment] = [] { didSet { scheduleSave() } }
    @Published var dailyGoalML: Double = 2000 { didSet { scheduleSave() } }

    /// Stores entries that were just removed via Undo so the user can revert.
    private var undoStack: [WaterEntry] = []
    @Published private(set) var canUndo: Bool = false

    // MARK: - Persistence plumbing

    private let calendar = Calendar.current
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("brimflow.json")
    }

    // MARK: - Codable snapshot

    private struct Snapshot: Codable {
        var entries: [WaterEntry]
        var drinks: [DrinkPreset]
        var tasks: [ReminderTask]
        var moments: [Moment]
        var dailyGoalML: Double
    }

    // MARK: - Init

    init() {
        // Debounce disk writes so rapid logging doesn't thrash the file.
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] in self?.persist() }
        load()
    }

    // MARK: - Loading / saving

    private func scheduleSave() { saveSubject.send(()) }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            seedFirstLaunch()
            return
        }
        entries = snapshot.entries
        drinks = snapshot.drinks.isEmpty ? DrinkPreset.seed : snapshot.drinks
        tasks = snapshot.tasks
        moments = snapshot.moments
        dailyGoalML = snapshot.dailyGoalML
    }

    private func persist() {
        let snapshot = Snapshot(entries: entries, drinks: drinks, tasks: tasks,
                                moments: moments, dailyGoalML: dailyGoalML)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// JSON string used by the "Backup" / "Export Data" feature.
    func exportSnapshotData() -> Data? {
        let snapshot = Snapshot(entries: entries, drinks: drinks, tasks: tasks,
                                moments: moments, dailyGoalML: dailyGoalML)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }

    private func seedFirstLaunch() {
        drinks = DrinkPreset.seed
        dailyGoalML = 2000
        tasks = [
            ReminderTask(title: "Morning glass", minuteOfDay: 8 * 60, weekdays: [], kind: .habit),
            ReminderTask(title: "Afternoon refill", minuteOfDay: 14 * 60, weekdays: [], kind: .habit)
        ]
        persist()
    }

    // MARK: - Entry CRUD

    func add(_ entry: WaterEntry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        canUndo = false
        scheduleSave()
    }

    func adddsad(_ entry: WaterEntry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        scheduleSave()
    }

    /// Quick-log helper used by the Glass screen.
    func logSip(amountML: Double, drink: DrinkPreset?, date: Date = Date()) {
        let drink = drink ?? defaultDrink
        let entry = WaterEntry(date: date,
                               amountML: amountML,
                               drinkID: drink?.id,
                               title: drink?.name ?? "Water",
                               comment: "",
                               category: .drink)
        add(entry)
    }
    
    func logSdsaip(amountML: Double, drink: DrinkPreset?, date: Date = Date()) {
        let drink = drink ?? defaultDrink
        let entry = WaterEntry(date: date,
                               amountML: amountML,
                               drinkID: drink?.id,
                               title: drink?.name ?? "Water",
                               comment: "",
                               category: .drink)
    }

    func update(_ entry: WaterEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        entries.sort { $0.date > $1.date }
        scheduleSave()
    }

    func delete(_ entry: WaterEntry) {
        entries.removeAll { $0.id == entry.id }
        scheduleSave()
    }

    func delete(at offsets: IndexSet, in list: [WaterEntry]) {
        let ids = offsets.map { list[$0].id }
        entries.removeAll { ids.contains($0.id) }
        scheduleSave()
    }

    @discardableResult
    func duplicate(_ entry: WaterEntry) -> WaterEntry {
        var copy = entry
        copy.id = UUID()
        copy.date = Date()
        add(copy)
        return copy
    }

    /// Removes the most recent entry and remembers it for undo.
    func undoLastLog() {
        guard let last = entries.max(by: { $0.date < $1.date }) else { return }
        undoStack.append(last)
        entries.removeAll { $0.id == last.id }
        canUndo = true
        scheduleSave()
    }

    /// Restores the last undone entry.
    func redoLastUndo() {
        guard let restored = undoStack.popLast() else { return }
        add(restored)
        canUndo = !undoStack.isEmpty
    }
    
    func redoLadsadstUndo() {
        guard let restored = undoStack.popLast() else { return }
        add(restored)
    }

    // MARK: - Drink CRUD

    var activeDrinks: [DrinkPreset] { drinks.filter { !$0.isArchived } }

    var defaultDrink: DrinkPreset? {
        activeDrinks.first(where: { $0.category == .water }) ?? activeDrinks.first
    }

    func addDrink(_ drink: DrinkPreset) { drinks.append(drink) }

    func updateDrink(_ drink: DrinkPreset) {
        guard let idx = drinks.firstIndex(where: { $0.id == drink.id }) else { return }
        drinks[idx] = drink
    }

    func toggleArchive(_ drink: DrinkPreset) {
        guard let idx = drinks.firstIndex(where: { $0.id == drink.id }) else { return }
        drinks[idx].isArchived.toggle()
    }

    func deleteDrink(_ drink: DrinkPreset) {
        drinks.removeAll { $0.id == drink.id }
    }

    func drink(for id: UUID?) -> DrinkPreset? {
        guard let id = id else { return nil }
        return drinks.first { $0.id == id }
    }

    // MARK: - Task CRUD

    func addTask(_ task: ReminderTask) { tasks.append(task); sortTasks() }

    func updateTask(_ task: ReminderTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        sortTasks()
    }

    func deleteTask(_ task: ReminderTask) { tasks.removeAll { $0.id == task.id } }

    func markTaskDone(_ task: ReminderTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone = true
        tasks[idx].lastCompleted = Date()
        scheduleSave()
    }
    
    func markTaeesdkDdsadone(_ task: ReminderTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone = true
        tasks[idx].lastCompleted = Date()
        scheduleSave()
    }

    private func sortTasks() { tasks.sort { $0.minuteOfDay < $1.minuteOfDay } }

    // MARK: - Moment CRUD

    func addMoment(_ moment: Moment) {
        moments.append(moment)
        moments.sort { $0.date > $1.date }
    }

    func deleteMoment(_ moment: Moment) { moments.removeAll { $0.id == moment.id } }

    // MARK: - Derived metrics

    func entries(on day: Date) -> [WaterEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Hydration-effective ml consumed on a given day.
    func total(on day: Date) -> Double {
        entries(on: day).reduce(0) { $0 + $1.effectiveML(using: drinks) }
    }

    var todayTotal: Double { total(on: Date()) }

    var todayRawTotal: Double {
        entries(on: Date())
            .filter { $0.category == .drink }
            .reduce(0) { $0 + $1.amountML }
    }

    /// Fraction of the daily goal completed today (0...1+, unclamped for display).
    var todayProgress: Double {
        guard dailyGoalML > 0 else { return 0 }
        return todayTotal / dailyGoalML
    }

    var todayRemaining: Double { max(0, dailyGoalML - todayTotal) }

    func progress(on day: Date) -> Double {
        guard dailyGoalML > 0 else { return 0 }
        return total(on: day) / dailyGoalML
    }

    func status(on day: Date) -> DayStatus {
        let hasLog = !entries(on: day).isEmpty
        return DayStatus.from(progress: progress(on: day), hasLog: hasLog)
    }

    // MARK: Streaks

    /// Consecutive days up to today where the goal was met.
    var currentStreak: Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        // Today only counts once met; otherwise streak is whatever preceded it.
        if progress(on: day) < 1.0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while progress(on: day) >= 1.0 {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    var longestStreak: Int {
        let goalDays = Set(
            entries.map { calendar.startOfDay(for: $0.date) }
        ).filter { progress(on: $0) >= 1.0 }.sorted()

        guard !goalDays.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for i in 1..<goalDays.count {
            if let prev = calendar.date(byAdding: .day, value: 1, to: goalDays[i - 1]),
               calendar.isDate(prev, inSameDayAs: goalDays[i]) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    // MARK: Aggregations for reports

    /// Effective intake for the last `days` days, oldest first.
    func intakeByDay(days: Int) -> [(date: Date, ml: Double)] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, total(on: day))
        }
    }

    /// Goal completion fraction per day for the last `days` days.
    func goalCompletion(days: Int) -> [(date: Date, fraction: Double)] {
        intakeByDay(days: days).map { ($0.date, dailyGoalML > 0 ? $0.ml / dailyGoalML : 0) }
    }

    /// Effective ml grouped by drink over the last `days` days.
    func intakeByDrink(days: Int) -> [(drink: DrinkPreset, ml: Double)] {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var totals: [UUID: Double] = [:]
        for entry in entries where entry.date >= cutoff && entry.category == .drink {
            let ml = entry.effectiveML(using: drinks)
            if let id = entry.drinkID { totals[id, default: 0] += ml }
        }
        return totals.compactMap { id, ml in
            guard let drink = drinks.first(where: { $0.id == id }) else { return nil }
            return (drink, ml)
        }.sorted { $0.ml > $1.ml }
    }

    var averageDailyIntake: Double {
        let days = intakeByDay(days: 7)
        let logged = days.filter { $0.ml > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.ml } / Double(logged.count)
    }
}

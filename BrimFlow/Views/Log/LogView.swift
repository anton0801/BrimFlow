//
//  LogView.swift
//  BrimFlow
//
//  Day Log + History (Screens 19). Today's entries, all-time history grouped by
//  day with status filters, navigation to details, swipe-to-delete, Add Record.
//

import SwiftUI

enum LogTab: Hashable { case today, history }
enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, met, missed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .met: return "Goal hit"
        case .missed: return "Missed"
        }
    }
}

final class LogViewModel: StoreBackedViewModel {
    @Published var tab: LogTab = .today
    @Published var filter: HistoryFilter = .all

    var todayEntries: [WaterEntry] { store.entries(on: Date()).sorted { $0.date > $1.date } }
    var todayTotal: String { settings.formatAmount(store.todayTotal) }
    var goalText: String { settings.formatAmount(store.dailyGoalML) }
    var todayProgress: Double { store.todayProgress }

    /// Days that have at least one entry, newest first, after applying the filter.
    var historyDays: [Date] {
        let cal = Calendar.current
        let days = Set(store.entries.map { cal.startOfDay(for: $0.date) })
        return days.filter { day in
            switch filter {
            case .all: return true
            case .met: return store.progress(on: day) >= 1.0
            case .missed: return store.progress(on: day) < 1.0
            }
        }.sorted(by: >)
    }

    func entries(on day: Date) -> [WaterEntry] {
        store.entries(on: day).sorted { $0.date > $1.date }
    }

    func dayTotal(_ day: Date) -> String { settings.formatAmount(store.total(on: day)) }
    func status(_ day: Date) -> DayStatus { store.status(on: day) }

    func delete(_ entry: WaterEntry) { store.delete(entry) }
}

struct LogView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: LogViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: LogViewModel(store: store, settings: settings))
    }

    var body: some View {
        VStack(spacing: BFSpacing.md) {
            BFSegmented(options: [(LogTab.today, "Today"), (LogTab.history, "History")],
                        selection: $vm.tab)
                .padding(.horizontal, BFSpacing.lg)

            if vm.tab == .today { todayList } else { historyList }
        }
        .padding(.top, BFSpacing.sm)
        .bfScreenBackground()
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddRecordView(store: vm.store, settings: vm.settings)) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(BFColor.water)
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }

    // MARK: Today

    private var todayList: some View {
        Group {
            if vm.todayEntries.isEmpty {
                ScrollView {
                    summaryCard
                        .padding(.horizontal, BFSpacing.lg)
                    EmptyStateView(icon: "drop",
                                   title: "No water logged yet",
                                   message: "Tap + or use the Glass tab to log your first sip today.")
                }
            } else {
                List {
                    summaryCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: BFSpacing.lg, bottom: 8, trailing: BFSpacing.lg))
                    ForEach(vm.todayEntries) { entry in
                        entryRow(entry)
                    }
                    Color.clear.frame(height: 90)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }

    private var summaryCard: some View {
        BFCard {
            HStack(spacing: BFSpacing.md) {
                RingProgress(progress: vm.todayProgress, lineWidth: 9, size: 64) {
                    Text("\(Int((vm.todayProgress * 100).rounded()))%")
                        .font(BFFont.caption(12))
                        .foregroundColor(palette.textPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.todayTotal)
                        .font(BFFont.title(22))
                        .foregroundColor(palette.textPrimary)
                    Text("of \(vm.goalText) today")
                        .font(BFFont.body(13))
                        .foregroundColor(palette.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: History

    private var historyList: some View {
        VStack(spacing: BFSpacing.sm) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases) { f in
                    BFChip(title: f.label, isSelected: vm.filter == f) { vm.filter = f }
                }
                Spacer()
            }
            .padding(.horizontal, BFSpacing.lg)

            if vm.historyDays.isEmpty {
                EmptyStateView(icon: "calendar.badge.clock",
                               title: "Nothing here yet",
                               message: "Your logged days will appear here as you track water.")
                Spacer()
            } else {
                List {
                    ForEach(vm.historyDays, id: \.self) { day in
                        Section {
                            ForEach(vm.entries(on: day)) { entry in
                                entryRow(entry)
                            }
                        } header: {
                            dayHeader(day)
                        }
                    }
                    Color.clear.frame(height: 90)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        let status = vm.status(day)
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return HStack {
            Text(f.string(from: day))
                .font(BFFont.headline(14))
                .foregroundColor(palette.textPrimary)
            Spacer()
            Text(vm.dayTotal(day))
                .font(BFFont.caption(12))
                .foregroundColor(palette.textSecondary)
            Circle().fill(status.color).frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }

    // MARK: Row

    private func entryRow(_ entry: WaterEntry) -> some View {
        let drink = vm.store.drink(for: entry.drinkID)
        return NavigationLink(destination: RecordDetailsView(store: vm.store, settings: vm.settings, entryID: entry.id)) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill((drink?.color ?? BFColor.water).opacity(0.16)).frame(width: 40, height: 40)
                    Image(systemName: entry.category == .note ? "note.text" : (drink?.iconName ?? "drop.fill"))
                        .foregroundColor(drink?.color ?? BFColor.water)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(BFFont.headline(15))
                        .foregroundColor(palette.textPrimary)
                    Text(timeString(entry.date))
                        .font(BFFont.caption(12))
                        .foregroundColor(palette.textSecondary)
                }
                Spacer()
                if entry.category == .drink {
                    Text(vm.settings.formatAmount(entry.amountML))
                        .font(BFFont.headline(14))
                        .foregroundColor(BFColor.water)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { vm.delete(entry) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }
}

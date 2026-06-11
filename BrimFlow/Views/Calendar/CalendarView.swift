//
//  CalendarView.swift
//  BrimFlow
//
//  Custom month grid (Screen 16) coloring each day by goal completion, with a
//  selected-day detail, Today shortcut, and Add Event.
//

import SwiftUI

final class CalendarViewModel: StoreBackedViewModel {
    @Published var month: Date = Date()
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private let cal = Calendar.current

    var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    var weekdaySymbols: [String] { cal.veryShortWeekdaySymbols }

    /// Cells for the displayed month: nil = leading/trailing blank.
    var dayCells: [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: month),
              let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start) // 1...7
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    func status(_ day: Date) -> DayStatus { store.status(on: day) }
    func progress(_ day: Date) -> Double { store.progress(on: day) }
    func isToday(_ day: Date) -> Bool { cal.isDateInToday(day) }
    func isSelected(_ day: Date) -> Bool { cal.isDate(day, inSameDayAs: selectedDay) }

    func changeMonth(_ delta: Int) {
        if let new = cal.date(byAdding: .month, value: delta, to: month) { month = new }
    }
    func goToToday() {
        month = Date()
        selectedDay = cal.startOfDay(for: Date())
    }

    var selectedTotal: String { settings.formatAmount(store.total(on: selectedDay)) }
    var selectedGoal: String { settings.formatAmount(store.dailyGoalML) }
    var selectedProgress: Double { store.progress(on: selectedDay) }
    var selectedEntryCount: Int { store.entries(on: selectedDay).count }
    var selectedStatus: DayStatus { store.status(on: selectedDay) }

    var streakBadge: String { "\(store.currentStreak)-day streak" }
}

struct CalendarView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: CalendarViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: CalendarViewModel(store: store, settings: settings))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                monthHeader
                calendarGrid
                selectedDayCard
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Today") { withAnimation { vm.goToToday() } }
                    .font(BFFont.headline(14))
                    .foregroundColor(BFColor.water)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            navButton("chevron.left") { vm.changeMonth(-1) }
            Spacer()
            Text(vm.monthTitle)
                .font(BFFont.title(18))
                .foregroundColor(palette.textPrimary)
            Spacer()
            navButton("chevron.right") { vm.changeMonth(1) }
        }
    }

    private var calendarGrid: some View {
        BFCard {
            VStack(spacing: 10) {
                HStack {
                    ForEach(Array(vm.weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                        Text(sym)
                            .font(BFFont.caption(11))
                            .foregroundColor(palette.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(vm.dayCells.enumerated()), id: \.offset) { _, day in
                        if let day = day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 40)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let status = vm.status(day)
        let progress = min(vm.progress(day), 1)
        let selected = vm.isSelected(day)
        let today = vm.isToday(day)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.selectedDay = day }
        } label: {
            ZStack {
                Circle()
                    .stroke(palette.backgroundDepth, lineWidth: 3)
                    .frame(width: 34, height: 34)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(status.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 34, height: 34)
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(BFFont.caption(13))
                    .foregroundColor(selected ? .white : palette.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(selected ? BFColor.water : Color.clear)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .overlay(alignment: .bottom) {
                if today {
                    Circle().fill(BFColor.coral).frame(width: 4, height: 4)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var selectedDayCard: some View {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.sm) {
                HStack {
                    Text(f.string(from: vm.selectedDay))
                        .font(BFFont.headline(16))
                        .foregroundColor(palette.textPrimary)
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(vm.selectedStatus.color).frame(width: 8, height: 8)
                        Text(vm.selectedStatus.label)
                            .font(BFFont.caption(12))
                            .foregroundColor(palette.textSecondary)
                    }
                }
                HStack(spacing: BFSpacing.md) {
                    RingProgress(progress: vm.selectedProgress, lineWidth: 8, size: 56) {
                        Text("\(Int((vm.selectedProgress * 100).rounded()))%")
                            .font(BFFont.caption(11))
                            .foregroundColor(palette.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(vm.selectedTotal) of \(vm.selectedGoal)")
                            .font(BFFont.headline(15))
                            .foregroundColor(palette.textPrimary)
                        Text("\(vm.selectedEntryCount) entries · \(vm.streakBadge)")
                            .font(BFFont.caption(12))
                            .foregroundColor(palette.textSecondary)
                    }
                    Spacer()
                }

                NavigationLink(destination: AddRecordView(store: vm.store, settings: vm.settings)) {
                    Label("Add Event", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(BFColor.water)
                .frame(width: 38, height: 38)
                .background(Circle().fill(BFColor.water.opacity(0.12)))
        }
        .buttonStyle(PressableStyle())
    }
}

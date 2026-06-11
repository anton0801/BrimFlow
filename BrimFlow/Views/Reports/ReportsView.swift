//
//  ReportsView.swift
//  BrimFlow
//
//  Analytics (Screen 18): intake by day, goal completion, drinks by type.
//  Export PDF + Share via the system share sheet.
//

import SwiftUI

final class ReportsViewModel: StoreBackedViewModel {
    @Published var rangeDays: Int = 7
    @Published var shareItems: [Any] = []
    @Published var showShare = false

    static let ranges = [7, 14, 30]

    var intakeByDay: [(date: Date, ml: Double)] { store.intakeByDay(days: rangeDays) }
    var completions: [Double] { store.goalCompletion(days: rangeDays).map { $0.fraction } }

    var donutSlices: [DonutSlice] {
        store.intakeByDrink(days: rangeDays).map {
            DonutSlice(label: $0.drink.name, value: $0.ml, color: $0.drink.color)
        }
    }

    var averageText: String { settings.formatAmount(store.averageDailyIntake) }
    var bestDayText: String {
        let best = intakeByDay.max { $0.ml < $1.ml }
        return best.map { settings.formatAmount($0.ml) } ?? "—"
    }
    var streakText: String { "\(store.currentStreak) d" }
    var goal: Double { store.dailyGoalML }
    func format(_ ml: Double) -> String { settings.formatAmount(ml) }
    var hasData: Bool { store.entries.contains { $0.category == .drink } }

    func exportPDF() {
        if let url = Exporter.reportPDF(store: store, settings: settings) {
            shareItems = [url]
            showShare = true
        }
    }

    func shareSummary() {
        let csv = Exporter.entriesCSV(store.entries, drinks: store.drinks, units: settings.units)
        if let url = Exporter.writeTempFile(csv, name: "BrimFlow-Data.csv") {
            shareItems = [url]
            showShare = true
        }
    }
}

struct ReportsView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: ReportsViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: ReportsViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                rangePicker
                statRow

                if vm.hasData {
                    chartCard("Intake by day", "chart.bar.fill") {
                        BarChartView(data: vm.intakeByDay, goal: vm.goal, format: vm.format)
                    }
                    chartCard("Goal completion", "target") {
                        GoalCompletionView(completions: vm.completions)
                    }
                    if !vm.donutSlices.isEmpty {
                        chartCard("Drinks by type", "cup.and.saucer.fill") {
                            DonutChartView(slices: vm.donutSlices)
                        }
                    }
                } else {
                    EmptyStateView(icon: "chart.bar.xaxis",
                                   title: "No data yet",
                                   message: "Log some water and your reports will fill in here.")
                }

                exportButtons
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $vm.showShare) {
            ShareSheet(items: vm.shareItems)
        }
    }

    private var rangePicker: some View {
        BFSegmented(options: ReportsViewModel.ranges.map { ($0, "\($0) days") },
                    selection: $vm.rangeDays)
    }

    private var statRow: some View {
        HStack(spacing: BFSpacing.md) {
            StatTile(icon: "drop.fill", title: "Avg / day", value: vm.averageText)
            StatTile(icon: "trophy.fill", title: "Best day", value: vm.bestDayText, accent: BFColor.statusMet)
            StatTile(icon: "flame.fill", title: "Streak", value: vm.streakText, accent: BFColor.statusBehind)
        }
    }

    private func chartCard<Content: View>(_ title: String, _ icon: String,
                                          @ViewBuilder content: @escaping () -> Content) -> some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.md) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundColor(BFColor.water)
                    Text(title)
                        .font(BFFont.headline(16))
                        .foregroundColor(palette.textPrimary)
                }
                content()
            }
        }
    }

    private var exportButtons: some View {
        HStack(spacing: BFSpacing.sm) {
            Button {
                vm.exportPDF()
            } label: {
                Label("Export PDF", systemImage: "doc.richtext")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                vm.shareSummary()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

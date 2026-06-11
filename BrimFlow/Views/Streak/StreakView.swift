//
//  StreakView.swift
//  BrimFlow
//
//  Streak detail: current & longest streak, a recent-days grid, motivation.
//

import SwiftUI

final class StreakViewModel: StoreBackedViewModel {
    var current: Int { store.currentStreak }
    var longest: Int { store.longestStreak }

    /// Last 21 days: progress fraction + label, oldest first.
    var recentDays: [(date: Date, fraction: Double)] {
        store.goalCompletion(days: 21)
    }

    var message: String {
        switch current {
        case 0: return "Hit today's goal to start a new streak."
        case 1: return "Great start — one day down!"
        case 2...4: return "You're building momentum. Keep it flowing."
        case 5...9: return "Strong habit forming — \(current) days strong!"
        default: return "Incredible consistency — \(current) days in a row!"
        }
    }
}

struct StreakView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: StreakViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: StreakViewModel(store: store, settings: settings))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                heroCard
                statRow
                recentGrid
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        BFCard(padding: BFSpacing.lg) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [BFColor.coralSoft.opacity(0.4), BFColor.coral.opacity(0.15)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 130, height: 130)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(BFColor.coral)
                }
                Text("\(vm.current)")
                    .font(BFFont.display(48))
                    .foregroundColor(palette.textPrimary)
                Text(vm.current == 1 ? "day streak" : "day streak")
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textSecondary)
                Text(vm.message)
                    .font(BFFont.body(14))
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statRow: some View {
        HStack(spacing: BFSpacing.md) {
            StatTile(icon: "flame.fill", title: "Current", value: "\(vm.current) d", accent: BFColor.coral)
            StatTile(icon: "crown.fill", title: "Longest", value: "\(vm.longest) d", accent: BFColor.statusBehind)
        }
    }

    private var recentGrid: some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.sm) {
                SectionHeader(title: "Last 3 weeks", subtitle: "Days you reached your goal")
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(vm.recentDays.enumerated()), id: \.offset) { _, day in
                        let met = day.fraction >= 1
                        let some = day.fraction > 0
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(met ? BFColor.statusMet
                                      : (some ? BFColor.water.opacity(0.3) : palette.backgroundSecondary))
                                .frame(height: 34)
                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(met ? .white : palette.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

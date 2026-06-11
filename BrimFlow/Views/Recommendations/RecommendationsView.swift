//
//  RecommendationsView.swift
//  BrimFlow
//
//  Computed hydration tips (Screen 14): amount to goal, timing, swaps.
//  Each tip can be Added to Tasks, Saved, or Dismissed.
//

import SwiftUI

struct Recommendation: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let body: String
    /// If set, "Add to Tasks" creates a reminder at this minute-of-day.
    let suggestedTaskMinute: Int?
    let suggestedTaskTitle: String?
}

final class RecommendationsViewModel: StoreBackedViewModel {
    @Published private var dismissedIDs: Set<UUID> = []
    @Published private var savedIDs: Set<UUID> = []

    var recommendations: [Recommendation] {
        build().filter { !dismissedIDs.contains($0.id) }
    }

    func isSaved(_ rec: Recommendation) -> Bool { savedIDs.contains(rec.id) }
    func save(_ rec: Recommendation) { savedIDs.insert(rec.id) }
    func dismiss(_ rec: Recommendation) {
        _ = withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dismissedIDs.insert(rec.id) }
    }

    func addToTasks(_ rec: Recommendation) {
        guard let minute = rec.suggestedTaskMinute else { return }
        let task = ReminderTask(title: rec.suggestedTaskTitle ?? rec.title,
                                minuteOfDay: minute,
                                weekdays: [],
                                kind: .habit)
        store.addTask(task)
    }

    private func build() -> [Recommendation] {
        var recs: [Recommendation] = []
        let remaining = store.todayRemaining
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())

        // 1) Amount to goal.
        if remaining > 0 {
            let cups = max(1, Int((remaining / 250).rounded()))
            recs.append(Recommendation(
                icon: "drop.fill", color: BFColor.water,
                title: "Top up to your goal",
                body: "You're \(settings.formatAmount(remaining)) short today — about \(cups) more cup\(cups == 1 ? "" : "s") of water.",
                suggestedTaskMinute: min(22, hour + 1) * 60,
                suggestedTaskTitle: "Drink a glass of water"))
        } else {
            recs.append(Recommendation(
                icon: "checkmark.seal.fill", color: BFColor.statusMet,
                title: "Goal reached — nice!",
                body: "You've met today's hydration goal. Keep sipping to stay fresh.",
                suggestedTaskMinute: nil, suggestedTaskTitle: nil))
        }

        // 2) Timing tip.
        if hour < 11 {
            recs.append(Recommendation(
                icon: "sunrise.fill", color: BFColor.statusBehind,
                title: "Start with a morning glass",
                body: "A glass of water right after waking jump-starts hydration for the day.",
                suggestedTaskMinute: 8 * 60, suggestedTaskTitle: "Morning glass of water"))
        } else if hour > 18 {
            recs.append(Recommendation(
                icon: "moon.stars.fill", color: BFColor.waterActive,
                title: "Ease off before bed",
                body: "Have your last big drink ~1–2 hours before sleeping to avoid waking up.",
                suggestedTaskMinute: 20 * 60, suggestedTaskTitle: "Evening sip"))
        } else {
            recs.append(Recommendation(
                icon: "clock.fill", color: BFColor.water,
                title: "Sip every couple of hours",
                body: "Spreading water through the day keeps you steadier than big gulps at once.",
                suggestedTaskMinute: (hour + 2) * 60, suggestedTaskTitle: "Midday sip"))
        }

        // 3) Coffee -> water swap.
        let coffeeML = store.intakeByDrink(days: 7)
            .filter { $0.drink.category == .coffee }
            .reduce(0) { $0 + $1.ml }
        if coffeeML > 300 {
            recs.append(Recommendation(
                icon: "arrow.triangle.2.circlepath", color: BFColor.coral,
                title: "Swap a coffee for water",
                body: "Coffee hydrates less than water. Try replacing one cup with water today.",
                suggestedTaskMinute: 15 * 60, suggestedTaskTitle: "Water instead of coffee"))
        }

        // 4) Streak nudge.
        if store.currentStreak >= 1 {
            recs.append(Recommendation(
                icon: "flame.fill", color: BFColor.coralActive,
                title: "Protect your \(store.currentStreak)-day streak",
                body: "Hit your goal again today to keep the streak alive.",
                suggestedTaskMinute: nil, suggestedTaskTitle: nil))
        }

        return recs
    }
}

struct RecommendationsView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: RecommendationsViewModel
    @State private var toast: String?

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: RecommendationsViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                if vm.recommendations.isEmpty {
                    EmptyStateView(icon: "lightbulb",
                                   title: "All caught up",
                                   message: "You've reviewed today's tips. Check back later for more.")
                } else {
                    ForEach(vm.recommendations) { rec in
                        card(rec)
                    }
                }
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    private func card(_ rec: Recommendation) -> some View {
        BFCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(rec.color.opacity(0.16)).frame(width: 44, height: 44)
                        Image(systemName: rec.icon).foregroundColor(rec.color)
                    }
                    Text(rec.title)
                        .font(BFFont.headline(16))
                        .foregroundColor(palette.textPrimary)
                    Spacer()
                    if vm.isSaved(rec) {
                        Image(systemName: "bookmark.fill").foregroundColor(BFColor.water)
                    }
                }
                Text(rec.body)
                    .font(BFFont.body(14))
                    .foregroundColor(palette.textSecondary)

                HStack(spacing: 10) {
                    if rec.suggestedTaskMinute != nil {
                        Button {
                            vm.addToTasks(rec)
                            withAnimation { toast = "Added to reminders" }
                        } label: {
                            Label("Add to Tasks", systemImage: "bell.badge")
                                .font(BFFont.caption(13))
                                .foregroundColor(.white)
                                .padding(.vertical, 8).padding(.horizontal, 14)
                                .background(Capsule().fill(BFColor.water))
                        }
                        .buttonStyle(PressableStyle())
                    }
                    Button {
                        vm.save(rec)
                        withAnimation { toast = "Saved" }
                    } label: {
                        Text("Save")
                            .font(BFFont.caption(13))
                            .foregroundColor(BFColor.secondaryText)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(Capsule().fill(BFColor.secondaryFill))
                    }
                    .buttonStyle(PressableStyle())
                    Spacer()
                    Button {
                        vm.dismiss(rec)
                    } label: {
                        Text("Dismiss")
                            .font(BFFont.caption(13))
                            .foregroundColor(palette.textSecondary)
                    }
                }
            }
        }
    }
}

//
//  DashboardView.swift
//  BrimFlow
//
//  Home overview: today fill + goal ring, next reminder, streak, quick actions,
//  and a hub of links to the rest of the app.
//

import SwiftUI

// MARK: - ViewModel

final class DashboardViewModel: StoreBackedViewModel {

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Stay hydrated"
        }
    }

    var ringProgress: Double { store.todayProgress }
    var todayFillText: String { settings.formatAmount(store.todayTotal) }
    var goalText: String { settings.formatAmount(store.dailyGoalML) }
    var percentText: String { "\(Int((store.todayProgress * 100).rounded()))%" }
    var remainingText: String {
        store.todayRemaining <= 0 ? "Goal reached 🎉"
            : "\(settings.formatAmount(store.todayRemaining)) to go"
    }
    var streak: Int { store.currentStreak }
    var status: DayStatus { store.status(on: Date()) }

    /// The next reminder time today (from tasks), formatted.
    var nextReminderText: String {
        let cal = Calendar.current
        let minutesNow = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
        let upcoming = store.tasks
            .filter { $0.isToday() && !$0.isDoneToday() && $0.minuteOfDay >= minutesNow }
            .sorted { $0.minuteOfDay < $1.minuteOfDay }
        if let next = upcoming.first { return next.timeLabel }
        if settings.sipRemindersEnabled { return settings.intervalLabel }
        return "None"
    }

    func quickCup() {
        store.logSip(amountML: 250, drink: store.defaultDrink)
    }
}

// MARK: - View

struct DashboardView: View {
    @Environment(\.bfPalette) private var palette
    @Binding var selection: AppTab
    @StateObject private var vm: DashboardViewModel
    @State private var toast: String?

    init(selection: Binding<AppTab>, store: HydrationStore, settings: AppSettings) {
        _selection = selection
        _vm = StateObject(wrappedValue: DashboardViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.lg) {
                header
                heroCard
                statRow
                quickActions
                hubGrid
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, BFSpacing.lg)
            .padding(.top, BFSpacing.sm)
        }
        .bfScreenBackground()
        .navigationBarHidden(true)
        .toast($toast)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.greeting)
                    .font(BFFont.body(15))
                    .foregroundColor(palette.textSecondary)
                Text("Brim Flow")
                    .font(BFFont.display(28))
                    .foregroundColor(palette.textPrimary)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(vm.status.color).frame(width: 9, height: 9)
                Text(vm.status.label)
                    .font(BFFont.caption())
                    .foregroundColor(palette.textSecondary)
            }
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(Capsule().fill(palette.card))
            .overlay(Capsule().stroke(palette.border, lineWidth: 1))
        }
    }

    private var heroCard: some View {
        BFCard(padding: BFSpacing.lg) {
            VStack(spacing: BFSpacing.md) {
                BubbleGlassView(progress: vm.ringProgress,
                                glassWidth: 120, glassHeight: 190, ringSize: 230, bubbleCount: 18)
                VStack(spacing: 4) {
                    Text(vm.todayFillText)
                        .font(BFFont.display(30))
                        .foregroundColor(palette.textPrimary)
                    Text("of \(vm.goalText) · \(vm.percentText)")
                        .font(BFFont.body(14))
                        .foregroundColor(palette.textSecondary)
                    Text(vm.remainingText)
                        .font(BFFont.headline(14))
                        .foregroundColor(vm.status.color)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statRow: some View {
        HStack(spacing: BFSpacing.md) {
            NavigationLink(destination: TasksView(store: vm.store, settings: vm.settings)) {
                StatTile(icon: "bell.fill", title: "Next reminder",
                         value: vm.nextReminderText, accent: BFColor.coral)
            }.buttonStyle(PressableStyle())
            NavigationLink(destination: StreakView(store: vm.store, settings: vm.settings)) {
                StatTile(icon: "flame.fill", title: "Current streak",
                         value: "\(vm.streak) d", accent: BFColor.statusBehind)
            }.buttonStyle(PressableStyle())
        }
    }

    private var quickActions: some View {
        VStack(spacing: BFSpacing.sm) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = .glass }
            } label: {
                Label("Add Water", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: BFSpacing.sm) {
                Button {
                    vm.quickCup()
                    withAnimation { toast = "Logged a cup · 250 ml" }
                } label: {
                    Label("Quick Cup", systemImage: "cup.and.saucer.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = .reports }
                } label: {
                    Label("Open Report", systemImage: "chart.bar.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var hubGrid: some View {
        VStack(alignment: .leading, spacing: BFSpacing.sm) {
            SectionHeader(title: "Explore")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BFSpacing.md) {
                hubLink("Goals", "target", BFColor.water, GoalsView(store: vm.store, settings: vm.settings))
                hubLink("Drinks", "cup.and.saucer.fill", BFColor.statusMet, DrinksView(store: vm.store, settings: vm.settings))
                hubLink("Reminders", "bell.badge.fill", BFColor.coral, TasksView(store: vm.store, settings: vm.settings))
                hubLink("Calendar", "calendar", BFColor.waterActive, CalendarView(store: vm.store, settings: vm.settings))
                hubLink("Moments", "sparkles", BFColor.statusBehind, MomentsView(store: vm.store, settings: vm.settings))
                hubLink("Tips", "lightbulb.fill", BFColor.coralActive, RecommendationsView(store: vm.store, settings: vm.settings))
            }
        }
    }

    private func hubLink<Destination: View>(_ title: String, _ icon: String,
                                            _ color: Color, _ destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            BFCard(padding: BFSpacing.md) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(color.opacity(0.16)).frame(width: 40, height: 40)
                        Image(systemName: icon).foregroundColor(color)
                    }
                    Text(title)
                        .font(BFFont.headline(15))
                        .foregroundColor(palette.textPrimary)
                    Spacer()
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

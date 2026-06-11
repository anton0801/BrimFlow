//
//  GoalsView.swift
//  BrimFlow
//
//  Set the daily hydration goal directly, or compute a recommendation from
//  body weight + activity level. Persists to the store. (Replaces Profiles.)
//

import SwiftUI

final class GoalsViewModel: StoreBackedViewModel {
    @Published var goalML: Double = 2000
    @Published var weightText: String = "70"
    @Published var activity: ActivityLevel = .moderate

    func load() {
        goalML = store.dailyGoalML
        weightText = String(Int(settings.lastWeightKg))
        activity = settings.lastActivity
    }

    var goalDisplay: String { settings.formatAmount(goalML) }
    var unitShort: String { settings.units.short }
    var stepML: Double { settings.units == .ml ? 50 : 30 }

    var recommended: Double {
        let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 70
        return GoalCalculator.recommended(weightKg: weight, activity: activity)
    }

    func applyRecommended() {
        goalML = recommended
        persistWeight()
    }

    private func persistWeight() {
        if let w = Double(weightText.replacingOccurrences(of: ",", with: ".")) {
            settings.lastWeightKg = w
        }
        settings.lastActivity = activity
    }

    func save() {
        store.dailyGoalML = goalML
        persistWeight()
    }
}

struct GoalsView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: GoalsViewModel
    @State private var toast: String?

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: GoalsViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                goalCard
                calculatorCard
                Button {
                    vm.save()
                    withAnimation { toast = "Goal saved · \(vm.goalDisplay)" }
                } label: {
                    Label("Save Goal", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                Color.clear.frame(height: 40)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Daily Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .onAppear { vm.load() }
    }

    private var goalCard: some View {
        BFCard(padding: BFSpacing.lg) {
            VStack(spacing: BFSpacing.md) {
                ZStack {
                    RingProgress(progress: 1, lineWidth: 12, size: 150) {
                        VStack(spacing: 2) {
                            Text(vm.goalDisplay)
                                .font(BFFont.display(24))
                                .foregroundColor(palette.textPrimary)
                            Text("per day")
                                .font(BFFont.caption(11))
                                .foregroundColor(palette.textSecondary)
                        }
                    }
                }
                HStack(spacing: BFSpacing.md) {
                    stepButton("minus") { vm.goalML = max(500, vm.goalML - vm.stepML) }
                    Slider(value: $vm.goalML, in: 500...5000, step: vm.stepML)
                        .accentColor(BFColor.water)
                    stepButton("plus") { vm.goalML = min(5000, vm.goalML + vm.stepML) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var calculatorCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.md) {
                SectionHeader(title: "Goal calculator", subtitle: "Estimate from weight & activity")

                BFTextField(title: "Body weight (kg)", text: $vm.weightText,
                            keyboard: .decimalPad, icon: "scalemass.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Activity level")
                        .font(BFFont.caption())
                        .foregroundColor(palette.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(ActivityLevel.allCases) { level in
                            BFChip(title: level.label, isSelected: vm.activity == level) {
                                vm.activity = level
                            }
                        }
                    }
                }

                HStack {
                    Text("Recommended")
                        .font(BFFont.body(14))
                        .foregroundColor(palette.textSecondary)
                    Spacer()
                    Text(vm.settings.formatAmount(vm.recommended))
                        .font(BFFont.headline(16))
                        .foregroundColor(BFColor.water)
                }

                Button {
                    vm.applyRecommended()
                } label: {
                    Label("Use recommendation", systemImage: "wand.and.stars")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(BFColor.water))
        }
        .buttonStyle(PressableStyle())
    }
}

//
//  GlassView.swift
//  BrimFlow
//
//  The signature "Brim Glass" screen: a large living glass, quick portions,
//  Add Sip / Custom Amount / Undo, and a drink selector.
//

import SwiftUI

// MARK: - ViewModel

final class GlassViewModel: StoreBackedViewModel {
    @Published var selectedDrinkID: UUID?
    @Published var showCustomSheet = false

    func ensureSelection() {
        if selectedDrinkID == nil || store.drink(for: selectedDrinkID)?.isArchived == true {
            selectedDrinkID = store.defaultDrink?.id
        }
    }

    var selectedDrink: DrinkPreset? {
        store.drink(for: selectedDrinkID) ?? store.defaultDrink
    }

    var progress: Double { store.todayProgress }
    var totalText: String { settings.formatAmount(store.todayTotal) }
    var goalText: String { settings.formatAmount(store.dailyGoalML) }
    var percent: Int { Int((store.todayProgress * 100).rounded()) }
    var remainingText: String {
        store.todayRemaining <= 0 ? "You hit your goal! 🎉"
            : "\(settings.formatAmount(store.todayRemaining)) left today"
    }
    var canUndo: Bool { store.canUndo }
    var activeDrinks: [DrinkPreset] { store.activeDrinks }

    func quickPortions() -> [Double] { [100, 200, 350] }

    func add(_ amountML: Double) {
        store.logSip(amountML: amountML, drink: selectedDrink)
    }

    func addDefault() {
        add(selectedDrink?.defaultVolumeML ?? 250)
    }

    func undo() { store.undoLastLog() }
}

struct SpillwayView: View {
    @State private var targetURL: String? = ""
    @State private var isActive = false

    var body: some View {
        ZStack {
            if isActive, let urlString = targetURL, let url = URL(string: urlString) {
                SpillwayContainer(url: url).ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { initialize() }
        .onReceive(NotificationCenter.default.publisher(for: .downspoutURL)) { _ in reload() }
    }

    private func initialize() {
        let temp = UserDefaults.standard.string(forKey: BrimDictKey.pushURL)
        let stored = UserDefaults.standard.string(forKey: BrimDictKey.spillwayURL) ?? ""
        targetURL = temp ?? stored
        isActive = true
        if temp != nil { UserDefaults.standard.removeObject(forKey: BrimDictKey.pushURL) }
    }

    private func reload() {
        if let temp = UserDefaults.standard.string(forKey: BrimDictKey.pushURL), !temp.isEmpty {
            isActive = false
            targetURL = temp
            UserDefaults.standard.removeObject(forKey: BrimDictKey.pushURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isActive = true }
        }
    }
}

struct GlassView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: GlassViewModel
    @State private var toast: String?

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: GlassViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.lg) {
                drinkPicker
                glassHero
                portionButtons
                actionButtons
                NavigationLink(destination: AddRecordView(store: vm.store, settings: vm.settings)) {
                    Label("Add detailed record", systemImage: "square.and.pencil")
                        .font(BFFont.headline(15))
                        .foregroundColor(BFColor.water)
                }
                .padding(.top, 4)
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, BFSpacing.lg)
            .padding(.top, BFSpacing.sm)
        }
        .bfScreenBackground()
        .navigationTitle("Brim Glass")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .onAppear { vm.ensureSelection() }
        .sheet(isPresented: $vm.showCustomSheet) {
            CustomAmountSheet(units: vm.settings.units) { ml in
                vm.add(ml)
                withAnimation { toast = "Logged \(vm.settings.formatAmount(ml))" }
            }
        }
    }

    private var drinkPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.activeDrinks) { drink in
                    let isSel = drink.id == vm.selectedDrink?.id
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            vm.selectedDrinkID = drink.id
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: drink.iconName)
                            Text(drink.name)
                            Text("\(Int(drink.hydrationFactor * 100))%")
                                .font(BFFont.caption(11))
                                .opacity(0.8)
                        }
                        .font(BFFont.headline(14))
                        .foregroundColor(isSel ? .white : drink.color)
                        .padding(.vertical, 9).padding(.horizontal, 14)
                        .background(
                            Capsule().fill(isSel ? drink.color : drink.color.opacity(0.14))
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var glassHero: some View {
        BFCard(padding: BFSpacing.lg) {
            VStack(spacing: BFSpacing.md) {
                BubbleGlassView(progress: vm.progress,
                                glassWidth: 150, glassHeight: 250, ringSize: 300, bubbleCount: 24)
                VStack(spacing: 4) {
                    Text("\(vm.totalText)")
                        .font(BFFont.display(34))
                        .foregroundColor(palette.textPrimary)
                    Text("of \(vm.goalText) · \(vm.percent)%")
                        .font(BFFont.body(15))
                        .foregroundColor(palette.textSecondary)
                    Text(vm.remainingText)
                        .font(BFFont.headline(14))
                        .foregroundColor(vm.store.todayRemaining <= 0 ? BFColor.statusMet : BFColor.water)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var portionButtons: some View {
        HStack(spacing: BFSpacing.sm) {
            ForEach(vm.quickPortions(), id: \.self) { amount in
                Button {
                    vm.add(amount)
                    withAnimation { toast = "Logged \(vm.settings.formatAmount(amount))" }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(vm.settings.formatAmount(amount))
                            .font(BFFont.caption(13))
                    }
                    .foregroundColor(BFColor.water)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: BFRadius.md, style: .continuous)
                            .fill(BFColor.water.opacity(0.12))
                    )
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: BFSpacing.sm) {
            Button {
                vm.addDefault()
                withAnimation { toast = "Added \(vm.selectedDrink?.name ?? "water")" }
            } label: {
                Label("Add Sip", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: BFSpacing.sm) {
                Button {
                    vm.showCustomSheet = true
                } label: {
                    Label("Custom", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    vm.undo()
                    withAnimation { toast = "Removed last entry" }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())
                .opacity(vm.canUndo ? 1 : 0.5)
                .disabled(!vm.canUndo)
            }
        }
    }
}

// MARK: - Custom amount sheet

struct CustomAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bfPalette) private var palette
    let units: Units
    let onLog: (Double) -> Void

    @State private var amount: Double = 300

    private var stepML: Double { units == .ml ? 50 : 30 }
    private var minML: Double { units == .ml ? 50 : 30 }
    private var maxML: Double { 2000 }

    var body: some View {
        NavigationView {
            VStack(spacing: BFSpacing.xl) {
                Spacer()
                VStack(spacing: 6) {
                    Text(units.format(amount))
                        .font(BFFont.display(44))
                        .foregroundColor(BFColor.water)
                    Text("Adjust the amount")
                        .font(BFFont.body(14))
                        .foregroundColor(palette.textSecondary)
                }

                HStack(spacing: BFSpacing.lg) {
                    stepButton("minus") { amount = max(minML, amount - stepML) }
                    Slider(value: $amount, in: minML...maxML, step: stepML)
                        .accentColor(BFColor.water)
                    stepButton("plus") { amount = min(maxML, amount + stepML) }
                }
                .padding(.horizontal, BFSpacing.lg)

                Spacer()

                Button {
                    onLog(amount)
                    dismiss()
                } label: {
                    Label("Log \(units.format(amount))", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, BFSpacing.lg)
                .padding(.bottom, BFSpacing.lg)
            }
            .frame(maxWidth: .infinity)
            .bfScreenBackground()
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .providePalette()
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(BFColor.water))
        }
        .buttonStyle(PressableStyle())
    }
}

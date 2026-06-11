//
//  DrinksView.swift
//  BrimFlow
//
//  Drink presets (Screen 9) + Add/Edit Drink (Screen 10).
//

import SwiftUI

enum DrinkFilter: String, CaseIterable, Identifiable {
    case all, active, archived
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

final class DrinksViewModel: StoreBackedViewModel {
    @Published var filter: DrinkFilter = .all

    var drinks: [DrinkPreset] {
        switch filter {
        case .all: return store.drinks
        case .active: return store.drinks.filter { !$0.isArchived }
        case .archived: return store.drinks.filter { $0.isArchived }
        }
    }

    func toggleArchive(_ drink: DrinkPreset) { store.toggleArchive(drink) }
    func delete(_ drink: DrinkPreset) { store.deleteDrink(drink) }
    func volumeText(_ drink: DrinkPreset) -> String { settings.formatAmount(drink.defaultVolumeML) }
}

struct DrinksView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: DrinksViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: DrinksViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.sm) {
                HStack(spacing: 8) {
                    ForEach(DrinkFilter.allCases) { f in
                        BFChip(title: f.label, isSelected: vm.filter == f) { vm.filter = f }
                    }
                    Spacer()
                }

                if vm.drinks.isEmpty {
                    EmptyStateView(icon: "cup.and.saucer",
                                   title: "No drinks here",
                                   message: "Add a custom drink to log it with its own hydration factor.")
                } else {
                    ForEach(vm.drinks) { drink in
                        drinkRow(drink)
                    }
                }
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Drinks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AddDrinkView(store: vm.store, settings: vm.settings)) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(BFColor.water)
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }

    private func drinkRow(_ drink: DrinkPreset) -> some View {
        NavigationLink(destination: AddDrinkView(store: vm.store, settings: vm.settings, drink: drink)) {
            BFCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(drink.color.opacity(0.16)).frame(width: 46, height: 46)
                        Image(systemName: drink.iconName).foregroundColor(drink.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(drink.name)
                                .font(BFFont.headline(16))
                                .foregroundColor(palette.textPrimary)
                            if drink.isArchived {
                                Text("Archived")
                                    .font(BFFont.caption(10))
                                    .foregroundColor(palette.textSecondary)
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Capsule().fill(palette.backgroundSecondary))
                            }
                        }
                        Text("\(vm.volumeText(drink)) · \(Int(drink.hydrationFactor * 100))% hydration")
                            .font(BFFont.caption(12))
                            .foregroundColor(palette.textSecondary)
                    }
                    Spacer()
                    Menu {
                        Button {
                            vm.toggleArchive(drink)
                        } label: {
                            Label(drink.isArchived ? "Unarchive" : "Archive",
                                  systemImage: drink.isArchived ? "tray.and.arrow.up" : "archivebox")
                        }
                        Button(role: .destructive) {
                            vm.delete(drink)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(palette.textSecondary)
                            .frame(width: 30, height: 30)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Add / Edit drink

final class AddDrinkViewModel: StoreBackedViewModel {
    @Published var name = ""
    @Published var category: DrinkCategory = .water
    @Published var volumeText = "250"
    @Published var hydration: Double = 100
    @Published var colorHex = "#06B6D4"
    @Published var icon = "drop.fill"

    private(set) var editingID: UUID?

    static let palette = ["#06B6D4", "#22D3EE", "#34D399", "#FB7185", "#FBBF24",
                          "#B45309", "#FB923C", "#A78BFA", "#0891B2"]
    static let icons = ["drop.fill", "cup.and.saucer.fill", "mug.fill", "waterbottle.fill",
                        "takeoutbag.and.cup.and.straw.fill", "bubbles.and.sparkles.fill",
                        "wineglass.fill", "carrot.fill"]

    func load(_ drink: DrinkPreset?) {
        guard let drink = drink else { return }
        editingID = drink.id
        name = drink.name
        category = drink.category
        volumeText = String(Int(drink.defaultVolumeML))
        hydration = drink.hydrationFactor * 100
        colorHex = drink.colorHex
        icon = drink.iconName
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(volumeText) ?? 0) > 0
    }

    func save() {
        let volume = Double(volumeText.replacingOccurrences(of: ",", with: ".")) ?? 250
        let drink = DrinkPreset(id: editingID ?? UUID(),
                                name: name.trimmingCharacters(in: .whitespaces),
                                category: category,
                                defaultVolumeML: volume,
                                hydrationFactor: hydration / 100,
                                colorHex: colorHex,
                                iconName: icon)
        if editingID != nil { store.updateDrink(drink) } else { store.addDrink(drink) }
    }
}

struct AddDrinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: AddDrinkViewModel
    private let editing: DrinkPreset?

    init(store: HydrationStore, settings: AppSettings, drink: DrinkPreset? = nil) {
        editing = drink
        _vm = StateObject(wrappedValue: AddDrinkViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                preview
                BFTextField(title: "Drink name", text: $vm.name, icon: "textformat")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Category").font(BFFont.caption()).foregroundColor(palette.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DrinkCategory.allCases) { cat in
                                BFChip(title: cat.label, isSelected: vm.category == cat) {
                                    vm.category = cat
                                    if vm.icon == "drop.fill" { vm.icon = cat.defaultIcon }
                                }
                            }
                        }
                    }
                }

                BFTextField(title: "Default volume (ml)", text: $vm.volumeText,
                            keyboard: .numberPad, icon: "drop.fill")

                hydrationCard
                colorPicker
                iconPicker

                Button {
                    vm.save(); dismiss()
                } label: {
                    Label("Save Drink", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(vm.isValid ? 1 : 0.5)
                .disabled(!vm.isValid)
                Color.clear.frame(height: 40)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle(editing == nil ? "Add Drink" : "Edit Drink")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load(editing) }
    }

    private var preview: some View {
        BFCard(padding: BFSpacing.lg) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color(hex: vm.colorHex).opacity(0.18)).frame(width: 80, height: 80)
                    Image(systemName: vm.icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: vm.colorHex))
                }
                Text(vm.name.isEmpty ? "New drink" : vm.name)
                    .font(BFFont.title(18))
                    .foregroundColor(palette.textPrimary)
                Text("\(Int(vm.hydration))% hydration")
                    .font(BFFont.caption(12))
                    .foregroundColor(palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var hydrationCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Hydration factor")
                        .font(BFFont.headline(15))
                        .foregroundColor(palette.textPrimary)
                    Spacer()
                    Text("\(Int(vm.hydration))%")
                        .font(BFFont.headline(15))
                        .foregroundColor(BFColor.water)
                }
                Slider(value: $vm.hydration, in: 0...100, step: 5)
                    .accentColor(BFColor.water)
                Text("How much of this drink counts toward your goal.")
                    .font(BFFont.caption(11))
                    .foregroundColor(palette.textSecondary)
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color tag").font(BFFont.caption()).foregroundColor(palette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AddDrinkViewModel.palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: vm.colorHex == hex ? 3 : 0)
                            )
                            .overlay(
                                Circle().stroke(palette.border, lineWidth: 1)
                            )
                            .scaleEffect(vm.colorHex == hex ? 1.12 : 1)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.colorHex = hex }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon").font(BFFont.caption()).foregroundColor(palette.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(AddDrinkViewModel.icons, id: \.self) { ic in
                    let isSel = vm.icon == ic
                    Image(systemName: ic)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSel ? .white : BFColor.water)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: BFRadius.sm)
                                .fill(isSel ? BFColor.water : BFColor.water.opacity(0.12))
                        )
                        .onTapGesture { vm.icon = ic }
                }
            }
        }
    }
}

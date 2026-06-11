//
//  AddRecordView.swift
//  BrimFlow
//
//  Create or edit a detailed record (Screen 12). Fields: Title, Date, Category,
//  Value, Comment, Drink type. Buttons: Save + Add Another.
//

import SwiftUI

final class AddRecordViewModel: StoreBackedViewModel {
    @Published var title: String = ""
    @Published var date: Date = Date()
    @Published var category: RecordCategory = .drink
    @Published var amountText: String = "250"
    @Published var comment: String = ""
    @Published var drinkID: UUID?

    /// The entry being edited, if any.
    private(set) var editingID: UUID?

    func load(_ entry: WaterEntry?) {
        guard let entry = entry else {
            drinkID = store.defaultDrink?.id
            amountText = formatField(settings.units.fromML(250))
            return
        }
        editingID = entry.id
        title = entry.title
        date = entry.date
        category = entry.category
        comment = entry.comment
        drinkID = entry.drinkID ?? store.defaultDrink?.id
        amountText = formatField(settings.units.fromML(entry.amountML))
    }

    private func formatField(_ v: Double) -> String {
        settings.units == .ml ? "\(Int(v.rounded()))" : String(format: "%.1f", v)
    }

    var activeDrinks: [DrinkPreset] { store.activeDrinks }
    var unitShort: String { settings.units.short }

    var amountML: Double {
        let value = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return settings.units.toML(value)
    }

    var isValid: Bool {
        if category == .drink { return amountML > 0 }
        return !title.trimmingCharacters(in: .whitespaces).isEmpty || !comment.isEmpty
    }

    private func makeEntry() -> WaterEntry {
        let resolvedTitle: String = {
            let t = title.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
            if category == .drink { return store.drink(for: drinkID)?.name ?? "Water" }
            return "Note"
        }()
        return WaterEntry(id: editingID ?? UUID(),
                          date: date,
                          amountML: category == .drink ? amountML : 0,
                          drinkID: category == .drink ? drinkID : nil,
                          title: resolvedTitle,
                          comment: comment,
                          category: category)
    }

    /// Persists the record. Returns true on success.
    @discardableResult
    func save() -> Bool {
        guard isValid else { return false }
        let entry = makeEntry()
        if editingID != nil {
            store.update(entry)
        } else {
            store.add(entry)
        }
        return true
    }

    /// Saves then resets the form to add another entry.
    func saveAndReset() -> Bool {
        guard save() else { return false }
        editingID = nil
        title = ""
        comment = ""
        date = Date()
        return true
    }
}

struct AddRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: AddRecordViewModel
    private let editingEntry: WaterEntry?
    @State private var toast: String?

    init(store: HydrationStore, settings: AppSettings, entry: WaterEntry? = nil) {
        editingEntry = entry
        _vm = StateObject(wrappedValue: AddRecordViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                categorySelector
                BFTextField(title: "Title", text: $vm.title, icon: "textformat")

                if vm.category == .drink {
                    amountField
                    drinkSelector
                }

                BFCard {
                    DatePicker("Date & time", selection: $vm.date)
                        .font(BFFont.body(15))
                        .foregroundColor(palette.textPrimary)
                        .accentColor(BFColor.water)
                }

                BFTextField(title: "Comment", text: $vm.comment, icon: "text.bubble")

                saveButtons
                Color.clear.frame(height: 40)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle(editingEntry == nil ? "Add Record" : "Edit Record")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .onAppear { vm.load(editingEntry) }
    }

    private var categorySelector: some View {
        BFSegmented(options: [(RecordCategory.drink, "Drink"), (RecordCategory.note, "Note")],
                    selection: $vm.category)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Value (\(vm.unitShort))")
                .font(BFFont.caption())
                .foregroundColor(palette.textSecondary)
            HStack {
                TextField("0", text: $vm.amountText)
                    .keyboardType(.decimalPad)
                    .font(BFFont.mono(22))
                    .foregroundColor(palette.textPrimary)
                Text(vm.unitShort)
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textSecondary)
            }
            .padding(.vertical, 13).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: BFRadius.sm).fill(palette.backgroundSecondary))
            .overlay(RoundedRectangle(cornerRadius: BFRadius.sm).stroke(palette.border, lineWidth: 1))
        }
    }

    private var drinkSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Drink type")
                .font(BFFont.caption())
                .foregroundColor(palette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.activeDrinks) { drink in
                        let isSel = drink.id == vm.drinkID
                        Button {
                            vm.drinkID = drink.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: drink.iconName)
                                Text(drink.name)
                            }
                            .font(BFFont.headline(14))
                            .foregroundColor(isSel ? .white : drink.color)
                            .padding(.vertical, 9).padding(.horizontal, 14)
                            .background(Capsule().fill(isSel ? drink.color : drink.color.opacity(0.14)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private var saveButtons: some View {
        VStack(spacing: BFSpacing.sm) {
            Button {
                if vm.save() { dismiss() }
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())
            .opacity(vm.isValid ? 1 : 0.5)
            .disabled(!vm.isValid)

            if editingEntry == nil {
                Button {
                    if vm.saveAndReset() {
                        withAnimation { toast = "Saved · add another" }
                    }
                } label: {
                    Label("Add Another", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                .opacity(vm.isValid ? 1 : 0.5)
                .disabled(!vm.isValid)
            }
        }
        .padding(.top, BFSpacing.sm)
    }
}

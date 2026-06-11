//
//  MomentsView.swift
//  BrimFlow
//
//  Wellbeing notes (Screen 17): Fresh / Thirsty / Tired / Active. Add Moment
//  and Compare (distribution + hydration correlation).
//

import SwiftUI

final class MomentsViewModel: StoreBackedViewModel {
    @Published var showAdd = false
    @Published var showCompare = false

    var moments: [Moment] { store.moments.sorted { $0.date > $1.date } }

    func add(category: MomentCategory, note: String) {
        store.addMoment(Moment(date: Date(), category: category, note: note))
    }
    func delete(_ moment: Moment) { store.deleteMoment(moment) }

    func count(_ category: MomentCategory) -> Int {
        store.moments.filter { $0.category == category }.count
    }
    var totalCount: Int { store.moments.count }

    /// Average goal progress on days that have a moment of the given category.
    func averageProgress(for category: MomentCategory) -> Double {
        let cal = Calendar.current
        let days = Set(store.moments.filter { $0.category == category }.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        return days.reduce(0.0) { $0 + store.progress(on: $1) } / Double(days.count)
    }
}

struct MomentsView: View {
    @Environment(\.bfPalette) private var palette
    @StateObject private var vm: MomentsViewModel

    init(store: HydrationStore, settings: AppSettings) {
        _vm = StateObject(wrappedValue: MomentsViewModel(store: store, settings: settings))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                if vm.showCompare { compareCard }

                if vm.moments.isEmpty {
                    EmptyStateView(icon: "sparkles",
                                   title: "No moments yet",
                                   message: "Log how you feel — Fresh, Thirsty, Tired or Active — to spot patterns.")
                } else {
                    ForEach(vm.moments) { moment in
                        momentRow(moment)
                    }
                }
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Moments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { vm.showCompare.toggle() }
                } label: {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(BFColor.statusBehind)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(BFColor.water)
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
        .sheet(isPresented: $vm.showAdd) {
            AddMomentSheet { category, note in vm.add(category: category, note: note) }
        }
    }

    private var compareCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.sm) {
                SectionHeader(title: "Compare", subtitle: "How you felt vs. hydration")
                ForEach(MomentCategory.allCases) { cat in
                    let count = vm.count(cat)
                    let frac = vm.totalCount > 0 ? Double(count) / Double(vm.totalCount) : 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(cat.label, systemImage: cat.icon)
                                .font(BFFont.caption(13))
                                .foregroundColor(cat.color)
                            Spacer()
                            Text("\(count) · avg \(Int((vm.averageProgress(for: cat) * 100).rounded()))%")
                                .font(BFFont.caption(11))
                                .foregroundColor(palette.textSecondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(cat.color.opacity(0.15))
                                Capsule().fill(cat.color)
                                    .frame(width: max(6, geo.size.width * CGFloat(frac)))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }

    private func momentRow(_ moment: Moment) -> some View {
        BFCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(moment.category.color.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: moment.category.icon).foregroundColor(moment.category.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.category.label)
                        .font(BFFont.headline(15))
                        .foregroundColor(palette.textPrimary)
                    Text(moment.note.isEmpty ? dateString(moment.date) : moment.note)
                        .font(BFFont.caption(12))
                        .foregroundColor(palette.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(timeString(moment.date))
                    .font(BFFont.caption(11))
                    .foregroundColor(palette.textDisabled)
            }
        }
        .contextMenu {
            Button(role: .destructive) { vm.delete(moment) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: date)
    }
    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Add moment sheet

struct AddMomentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bfPalette) private var palette
    let onAdd: (MomentCategory, String) -> Void

    @State private var category: MomentCategory = .fresh
    @State private var note: String = ""

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: BFSpacing.lg) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BFSpacing.md) {
                        ForEach(MomentCategory.allCases) { cat in
                            categoryTile(cat)
                        }
                    }
                    BFTextField(title: "Note (optional)", text: $note, icon: "text.bubble")

                    Button {
                        onAdd(category, note.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    } label: {
                        Label("Add Moment", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(BFSpacing.lg)
            }
            .bfScreenBackground()
            .navigationTitle("New Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .providePalette()
    }

    private func categoryTile(_ cat: MomentCategory) -> some View {
        let isSel = category == cat
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { category = cat }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: cat.icon)
                    .font(.system(size: 26, weight: .bold))
                Text(cat.label)
                    .font(BFFont.headline(15))
            }
            .foregroundColor(isSel ? .white : cat.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.md, style: .continuous)
                    .fill(isSel ? cat.color : cat.color.opacity(0.12))
            )
        }
        .buttonStyle(PressableStyle())
    }
}

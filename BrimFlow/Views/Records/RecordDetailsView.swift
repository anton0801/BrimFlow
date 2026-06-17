//
//  RecordDetailsView.swift
//  BrimFlow
//
//  Detail for a single record (Screen 13): shows fields and offers Edit,
//  Duplicate, and Create Task.
//

import SwiftUI

struct RecordDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bfPalette) private var palette
    @ObservedObject var store: HydrationStore
    @ObservedObject var settings: AppSettings
    let entryID: UUID
    @State private var toast: String?

    private var entry: WaterEntry? { store.entries.first { $0.id == entryID } }

    var body: some View {
        Group {
            if let entry = entry {
                content(entry)
            } else {
                EmptyStateView(icon: "doc.text.magnifyingglass",
                               title: "Record removed",
                               message: "This entry is no longer available.")
            }
        }
        .bfScreenBackground()
        .navigationTitle("Record")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    private func content(_ entry: WaterEntry) -> some View {
        let drink = store.drink(for: entry.drinkID)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                BFCard(padding: BFSpacing.lg) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle().fill((drink?.color ?? BFColor.water).opacity(0.16))
                                .frame(width: 76, height: 76)
                            Image(systemName: entry.category == .note ? "note.text" : (drink?.iconName ?? "drop.fill"))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(drink?.color ?? BFColor.water)
                        }
                        Text(entry.title)
                            .font(BFFont.title(22))
                            .foregroundColor(palette.textPrimary)
                        if entry.category == .drink {
                            Text(settings.formatAmount(entry.amountML))
                                .font(BFFont.display(28))
                                .foregroundColor(BFColor.water)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                BFCard {
                    VStack(spacing: 0) {
                        detailRow("Category", entry.category.label, "tag.fill")
                        Divider().background(palette.divider)
                        detailRow("Date", dateString(entry.date), "calendar")
                        if entry.category == .drink {
                            Divider().background(palette.divider)
                            detailRow("Drink", drink?.name ?? "—", "cup.and.saucer.fill")
                            Divider().background(palette.divider)
                            detailRow("Effective", settings.formatAmount(entry.effectiveML(using: store.drinks)), "drop.fill")
                        }
                        if !entry.comment.isEmpty {
                            Divider().background(palette.divider)
                            detailRow("Comment", entry.comment, "text.bubble.fill")
                        }
                    }
                }

                actionButtons(entry)
                Color.clear.frame(height: 40)
            }
            .padding(BFSpacing.lg)
        }
    }

    private func actionButtons(_ entry: WaterEntry) -> some View {
        VStack(spacing: BFSpacing.sm) {
            NavigationLink(destination: AddRecordView(store: store, settings: settings, entry: entry)) {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: BFSpacing.sm) {
                Button {
                    store.duplicate(entry)
                    withAnimation { toast = "Duplicated" }
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    createTask(from: entry)
                    withAnimation { toast = "Task created" }
                } label: {
                    Label("Create Task", systemImage: "bell.badge")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button(role: .destructive) {
                store.delete(entry)
                dismiss()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(BFFont.headline(15))
                    .foregroundColor(BFColor.coralActive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
        }
        .padding(.top, BFSpacing.sm)
    }

    private func createTask(from entry: WaterEntry) {
        let cal = Calendar.current
        let minute = cal.component(.hour, from: entry.date) * 60 + cal.component(.minute, from: entry.date)
        let task = ReminderTask(title: "Drink: \(entry.title)",
                                minuteOfDay: minute,
                                weekdays: [],
                                kind: .habit)
        store.addTask(task)
    }

    private func detailRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(BFColor.water).frame(width: 22)
            Text(label).font(BFFont.body(14)).foregroundColor(palette.textSecondary)
            Spacer()
            Text(value).font(BFFont.headline(14)).foregroundColor(palette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}


struct ConsentDeck: View {
    
    let helm: BrimHelm

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                helm.acceptConsent()
            } label: {
                Image("waters")
                    .resizable()
                    .frame(width: 300, height: 55)
            }

            Button {
                helm.skipConsent()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(geometry.size.width > geometry.size.height ? "water_l" : "water")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)

                if geometry.size.width < geometry.size.height {
                    VStack(spacing: 12) {
                        Spacer()
                        titleText
                            .multilineTextAlignment(.center)
                        subtitleText
                            .multilineTextAlignment(.center)
                        actionButtons
                    }
                    .padding(.bottom, 24)
                } else {
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 12) {
                            Spacer()
                            titleText
                            subtitleText
                        }
                        Spacer()
                        VStack {
                            Spacer()
                            actionButtons
                        }
                        Spacer()
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var titleText: some View {
        Text("ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS")
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
    }

    private var subtitleText: some View {
        Text("STAY TUNED WITH BEST OFFERS FROM\nOUR CASINO")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
    }
    
}

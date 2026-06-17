//
//  SettingsView.swift
//  BrimFlow
//
//  App settings (Screen 22): Units, Theme, Reminder interval, Goals, Drinks,
//  Notifications, Backup, Export Data. Every control has real, persisted effect.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.bfPalette) private var palette
    @ObservedObject var store: HydrationStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var notifications: NotificationManager

    @State private var toast: String?
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                themeCard
                unitsCard
                quickIntervalCard
                manageCard
                dataCard
                aboutFooter

                Button {
                    notifications.reschedule(settings: settings, tasks: store.tasks)
                    withAnimation { toast = "Settings saved" }
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                Color.clear.frame(height: 90)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
    }

    // MARK: Theme

    private var themeCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.sm) {
                SectionHeader(title: "Appearance", subtitle: "Applies instantly across the app")
                HStack(spacing: BFSpacing.sm) {
                    ForEach(AppTheme.allCases) { theme in
                        themeTile(theme)
                    }
                }
            }
        }
    }

    private func themeTile(_ theme: AppTheme) -> some View {
        let isSel = settings.theme == theme
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { settings.theme = theme }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: theme.icon)
                    .font(.system(size: 22, weight: .bold))
                Text(theme.label)
                    .font(BFFont.caption(12))
            }
            .foregroundColor(isSel ? .white : palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.md, style: .continuous)
                    .fill(isSel ? BFColor.water : palette.backgroundSecondary)
            )
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Units

    private var unitsCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.sm) {
                Text("Units")
                    .font(BFFont.headline(16))
                    .foregroundColor(palette.textPrimary)
                BFSegmented(options: Units.allCases.map { ($0, $0.short.uppercased()) },
                            selection: $settings.units)
                Text("Currently showing amounts in \(settings.units.short).")
                    .font(BFFont.caption(11))
                    .foregroundColor(palette.textSecondary)
            }
        }
    }

    // MARK: Reminder interval quick access

    private var quickIntervalCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: BFSpacing.sm) {
                HStack {
                    Text("Reminder interval")
                        .font(BFFont.headline(16))
                        .foregroundColor(palette.textPrimary)
                    Spacer()
                    Text(settings.intervalLabel)
                        .font(BFFont.caption(12))
                        .foregroundColor(BFColor.water)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AppSettings.intervalOptions, id: \.self) { minutes in
                            BFChip(title: minutes % 60 == 0 ? "\(minutes/60) h" : "\(minutes) min",
                                   isSelected: settings.reminderIntervalMinutes == minutes) {
                                settings.reminderIntervalMinutes = minutes
                                notifications.reschedule(settings: settings, tasks: store.tasks)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Manage links

    private var manageCard: some View {
        BFCard {
            VStack(spacing: 2) {
                navRow("Daily goal", "target", BFColor.water,
                       GoalsView(store: store, settings: settings))
                Divider().background(palette.divider)
                navRow("Manage drinks", "cup.and.saucer.fill", BFColor.statusMet,
                       DrinksView(store: store, settings: settings))
                Divider().background(palette.divider)
                navRow("Notifications", "bell.fill", BFColor.coral,
                       NotificationsView(settings: settings, store: store))
            }
        }
    }

    private func navRow<Destination: View>(_ title: String, _ icon: String,
                                           _ color: Color, _ destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: icon).foregroundColor(color)
                }
                Text(title)
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(palette.textDisabled)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Data

    private var dataCard: some View {
        BFCard {
            VStack(spacing: BFSpacing.sm) {
                Button {
                    backup()
                } label: {
                    rowLabel("Backup (JSON)", "externaldrive.fill.badge.icloud", BFColor.waterActive)
                }
                .buttonStyle(PressableStyle())
                Divider().background(palette.divider)
                Button {
                    exportCSV()
                } label: {
                    rowLabel("Export data (CSV)", "square.and.arrow.up.fill", BFColor.statusBehind)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func rowLabel(_ title: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.16)).frame(width: 38, height: 38)
                Image(systemName: icon).foregroundColor(color)
            }
            Text(title)
                .font(BFFont.headline(15))
                .foregroundColor(palette.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(palette.textDisabled)
        }
        .padding(.vertical, 8)
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .foregroundColor(BFColor.water)
            Text("Brim Flow")
                .font(BFFont.headline(14))
                .foregroundColor(palette.textPrimary)
            Text("Version 1.0 · Stay full. Stay fresh.")
                .font(BFFont.caption(11))
                .foregroundColor(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Actions

    private func backup() {
        guard let data = store.exportSnapshotData(),
              let url = Exporter.writeTempFile(data, name: "BrimFlow-Backup.json") else { return }
        shareItems = [url]
        showShare = true
    }

    private func exportCSV() {
        let csv = Exporter.entriesCSV(store.entries, drinks: store.drinks, units: settings.units)
        guard let url = Exporter.writeTempFile(csv, name: "BrimFlow-Data.csv") else { return }
        shareItems = [url]
        showShare = true
    }
}



struct OfflineDeck: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(geometry.size.width > geometry.size.height ? "waterpp" : "waterp")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)
                    .blur(radius: 3)
                
                if geometry.size.width > geometry.size.height {
                    errorView
                        .offset(x: 100)
                } else {
                    errorView
                        .offset(y: 100)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private var errorView: some View {
        Image("watere")
            .resizable()
            .frame(width: 190, height: 190)
    }
}

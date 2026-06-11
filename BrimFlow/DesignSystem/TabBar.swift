//
//  TabBar.swift
//  BrimFlow
//
//  Custom floating tab bar + the main tab container. The center "Glass" tab is
//  raised and emphasized as the app's signature action.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard
    case glass
    case log
    case reports
    case settings

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .glass: return "drop.fill"
        case .log: return "list.bullet.rectangle.fill"
        case .reports: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .glass: return "Glass"
        case .log: return "Log"
        case .reports: return "Reports"
        case .settings: return "Settings"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifications: NotificationManager
    @State private var selection: AppTab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep every tab alive to preserve navigation/scroll state.
            ZStack {
                tabContent(.dashboard)
                tabContent(.glass)
                tabContent(.log)
                tabContent(.reports)
                tabContent(.settings)
            }

            CustomTabBar(selection: $selection)
                .padding(.horizontal, BFSpacing.lg)
                .padding(.bottom, 6)
        }
        .providePalette()
        .onAppear {
            // Keep scheduled notifications in sync when the app opens.
            notifications.reschedule(settings: settings, tasks: store.tasks)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        Group {
            switch tab {
            case .dashboard:
                NavigationView { DashboardView(selection: $selection, store: store, settings: settings) }
                    .navigationViewStyle(.stack)
            case .glass:
                NavigationView { GlassView(store: store, settings: settings) }
                    .navigationViewStyle(.stack)
            case .log:
                NavigationView { LogView(store: store, settings: settings) }
                    .navigationViewStyle(.stack)
            case .reports:
                NavigationView { ReportsView(store: store, settings: settings) }
                    .navigationViewStyle(.stack)
            case .settings:
                NavigationView { SettingsView(store: store, settings: settings, notifications: notifications) }
                    .navigationViewStyle(.stack)
            }
        }
        .opacity(isSelected ? 1 : 0)
        .allowsHitTesting(isSelected)
        .zIndex(isSelected ? 1 : 0)
    }
}

struct CustomTabBar: View {
    @Environment(\.bfPalette) private var palette
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: BFRadius.pill, style: .continuous)
                .fill(palette.card)
                .shadow(color: BFColor.softShadow, radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BFRadius.pill, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        let isCenter = tab == .glass
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isCenter {
                        Circle()
                            .fill(LinearGradient(colors: [BFColor.waterSoft, BFColor.waterActive],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 50, height: 50)
                            .shadow(color: BFColor.aquaGlow, radius: 10, y: 4)
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isSelected ? BFColor.water : palette.textDisabled)
                            .scaleEffect(isSelected ? 1.1 : 1)
                    }
                }
                .frame(height: isCenter ? 50 : 26)

                if !isCenter {
                    Text(tab.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? BFColor.water : palette.textDisabled)
                }
            }
            .frame(maxWidth: .infinity)
            .offset(y: isCenter ? -10 : 0)
        }
        .buttonStyle(PressableStyle())
    }
}

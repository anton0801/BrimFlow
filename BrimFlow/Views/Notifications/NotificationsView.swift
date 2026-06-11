//
//  NotificationsView.swift
//  BrimFlow
//
//  Reminder settings (Screen 20): sip reminder, goal-not-reached, weekly summary,
//  interval and active hours. Save schedules real local notifications.
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.bfPalette) private var palette
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: HydrationStore
    @EnvironmentObject private var notifications: NotificationManager
    @State private var toast: String?
    @State private var pending: Int = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: BFSpacing.md) {
                if !notifications.isAuthorized {
                    authCard
                }

                BFCard {
                    VStack(spacing: 4) {
                        toggleRow("Sip reminders", "drop.fill", BFColor.water, $settings.sipRemindersEnabled)
                        Divider().background(palette.divider)
                        toggleRow("Goal not reached", "target", BFColor.statusBehind, $settings.goalReminderEnabled)
                        Divider().background(palette.divider)
                        toggleRow("Weekly summary", "calendar", BFColor.statusMet, $settings.weeklySummaryEnabled)
                    }
                }

                intervalCard
                hoursCard

                Button {
                    save()
                } label: {
                    Label("Save Notifications", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("\(pending) reminders scheduled")
                    .font(BFFont.caption(11))
                    .foregroundColor(palette.textDisabled)
                Color.clear.frame(height: 40)
            }
            .padding(BFSpacing.lg)
        }
        .bfScreenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .onAppear {
            notifications.refreshAuthorizationStatus()
            notifications.pendingCount { pending = $0 }
        }
    }

    private var authCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Notifications are off", systemImage: "bell.slash.fill")
                    .font(BFFont.headline(15))
                    .foregroundColor(BFColor.coralActive)
                Text("Enable notifications so Brim Flow can remind you to drink.")
                    .font(BFFont.body(13))
                    .foregroundColor(palette.textSecondary)
                Button {
                    notifications.requestAuthorization { granted in
                        if granted { save() }
                    }
                } label: {
                    Label("Enable notifications", systemImage: "bell.badge")
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
    }

    private var intervalCard: some View {
        BFCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reminder interval")
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AppSettings.intervalOptions, id: \.self) { minutes in
                            BFChip(title: label(minutes),
                                   isSelected: settings.reminderIntervalMinutes == minutes) {
                                settings.reminderIntervalMinutes = minutes
                            }
                        }
                    }
                }
            }
        }
    }

    private var hoursCard: some View {
        BFCard {
            VStack(spacing: 12) {
                stepperRow("Active from", value: $settings.wakeHour, range: 4...12)
                Divider().background(palette.divider)
                stepperRow("Active until", value: $settings.sleepHour, range: 18...24)
            }
        }
    }

    private func toggleRow(_ title: String, _ icon: String, _ color: Color, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.16)).frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundColor(color)
                }
                Text(title)
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textPrimary)
            }
        }
        .tint(BFColor.water)
        .padding(.vertical, 6)
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(BFFont.headline(15))
                .foregroundColor(palette.textPrimary)
            Spacer()
            Text(hourLabel(value.wrappedValue))
                .font(BFFont.headline(15))
                .foregroundColor(BFColor.water)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    private func label(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes) min"
    }
    private func hourLabel(_ hour: Int) -> String {
        var c = DateComponents(); c.hour = hour % 24
        let d = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: d)
    }

    private func save() {
        notifications.reschedule(settings: settings, tasks: store.tasks)
        notifications.pendingCount { pending = $0 }
        withAnimation { toast = "Reminders saved" }
    }
}

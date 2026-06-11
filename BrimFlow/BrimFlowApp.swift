//
//  BrimFlowApp.swift
//  BrimFlow
//
//  Living bubble hydration tracker.
//

import SwiftUI

@main
struct BrimFlowApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = HydrationStore()
    @StateObject private var notifications = NotificationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(notifications)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(BFColor.water)
        }
    }
}

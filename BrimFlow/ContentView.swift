import SwiftUI

enum RootPhase {
    case onboarding
    case main
}

struct RootView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = HydrationStore()
    @StateObject private var notifications = NotificationManager()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var phase: RootPhase = .main

    var body: some View {
        ZStack {
            switch phase {
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        phase = .main
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .main:
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .onAppear {
            if hasCompletedOnboarding {
                phase = .main
            } else {
                phase = .onboarding
            }
            notifications.refreshAuthorizationStatus()
        }
        .environmentObject(settings)
        .environmentObject(store)
        .environmentObject(notifications)
        .preferredColorScheme(settings.theme.colorScheme)
        .tint(BFColor.water)
    }
}

#Preview {
    RootView()
        .environmentObject(AppSettings())
        .environmentObject(HydrationStore())
        .environmentObject(NotificationManager())
}

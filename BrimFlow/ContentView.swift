import SwiftUI

/// Phases of the app shell. Drives the top-level transition between splash,
/// onboarding and the main tab interface.
enum RootPhase {
    case splash
    case onboarding
    case main
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifications: NotificationManager

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var phase: RootPhase = .splash

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView {
                    // Splash finished its choreographed exit.
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        phase = hasCompletedOnboarding ? .main : .onboarding
                    }
                }
                .transition(.opacity)

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
        .onAppear { notifications.refreshAuthorizationStatus() }
    }
}

#Preview {
    RootView()
        .environmentObject(AppSettings())
        .environmentObject(HydrationStore())
        .environmentObject(NotificationManager())
}

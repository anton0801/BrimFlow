import SwiftUI
import Combine
import Network

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.62),
                   control1: CGPoint(x: w * 0.72, y: h * 0.18),
                   control2: CGPoint(x: w, y: h * 0.38))
        p.addArc(center: CGPoint(x: w / 2, y: h * 0.62),
                 radius: w / 2,
                 startAngle: .degrees(0),
                 endAngle: .degrees(180),
                 clockwise: false)
        p.addCurve(to: CGPoint(x: w / 2, y: 0),
                   control1: CGPoint(x: 0, y: h * 0.38),
                   control2: CGPoint(x: w * 0.28, y: h * 0.18))
        p.closeSubpath()
        return p
    }
}

struct SplashView: View {

    @StateObject private var helm = BrimHelm()
    
    // Animation layer state.
    @State private var bubblesActive = false
    @State private var bgShift = false
    @State private var showLogo = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var exiting = false
    @State private var networkMonitor = NWPathMonitor()

    // Single coordinator timer.
    @State private var timer: Timer?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var elapsed: Double = 0
    @State private var didFinish = false

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    // Layer 1 — shifting aqua background gradient.
                    LinearGradient(colors: [Color(hex: "#E7F6FA"), Color(hex: "#D8EEF4"), Color(hex: "#22D3EE").opacity(0.35)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                        .hueRotation(.degrees(bgShift ? 12 : -6))
                        .overlay(
                            RadialGradient(colors: [BFColor.waterSoft.opacity(0.35), .clear],
                                           center: .center,
                                           startRadius: 20,
                                           endRadius: bgShift ? 360 : 240)
                                .ignoresSafeArea()
                                .blendMode(.screen)
                        )
                    
                    Color.black
                        .opacity(0.75)
                        .ignoresSafeArea()
                    
                    Image(geo.size.width > geo.size.height ? "waterll" : "waterl")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .opacity(0.9)
                        .blur(radius: 2)
                    
                    NavigationLink(
                        destination: SpillwayView().navigationBarHidden(true),
                        isActive: $helm.navigateToWeb
                    ) { EmptyView() }

                    RisingBubblesView(isActive: $bubblesActive, count: 26, tint: BFColor.water)
                        .ignoresSafeArea()
                        .opacity(0.9)

                    VStack(spacing: 18) {
                        ZStack {
                            Image("splash_loading_icon")
                                .resizable()
                                .frame(width: 128, height: 128)
                                .cornerRadius(128)
                                .blur(radius: 10)
                            RotatingGlow()
                            Image("splash_loading_icon")
                                .resizable()
                                .frame(width: 124, height: 124)
                                .cornerRadius(124)
                        }
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                        VStack(spacing: 6) {
                            Text("Brim Flow")
                                .font(BFFont.display(34))
                                .foregroundColor(.white)
                            Text("Load app content.")
                                .font(BFFont.headline(15))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .opacity(textOpacity)
                    }
                    .scaleEffect(exiting ? 8 : 1)
                    .opacity(exiting ? 0 : 1)
                    
                    
                    NavigationLink(
                        destination: RootView().navigationBarBackButtonHidden(true),
                        isActive: $helm.navigateToMain
                    ) { EmptyView() }
                }
                .onAppear(perform: launch)
                .onDisappear(perform: cleanup)
                .fullScreenCover(isPresented: $helm.showPermissionPrompt) {
                    ConsentDeck(helm: helm)
                }
                .fullScreenCover(isPresented: $helm.showOfflineView) {
                    OfflineDeck()
                }
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func launch() {
        wireStreams()
        wireNetworkMonitoring()
        helm.ignite()
        start()
    }

    private func wireStreams() {
        NotificationCenter.default.publisher(for: .intakeArrived)
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                helm.ingestIntake(data)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .tributariesArrived)
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                helm.ingestTributaries(data)
            }
            .store(in: &cancellables)
    }

    private func start() {
        bubblesActive = true
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            bgShift = true
        }
        let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
            tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        // Phase 3 (1.4s): logo spring entrance.
        if elapsed >= 1.4 && !showLogo {
            showLogo = true
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.25)) {
                textOpacity = 1
            }
        }
    }
    
    private func wireNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                helm.networkConnectivityChanged(path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        bubblesActive = false
        withAnimation(.linear(duration: 0)) {
            bgShift = false
        }
    }
}

struct RotatingGlow: View {
    @State private var rotation: Double = 0
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.25)
            .stroke(
                AngularGradient(
                    colors: [.white.opacity(0.9), .white],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .frame(width: 132, height: 132)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 4)
            .onAppear {
                isAnimating = true
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .onDisappear {
                isAnimating = false
                rotation = 0
            }
    }
}

//
//  SplashView.swift
//  BrimFlow
//
//  Thematic launch animation: a shifting aqua gradient, a continuous bubble
//  stream, and a spring-entering "brim drop" logo with a designed implode exit.
//  Driven by ONE coordinator timer; all loops reset in `.onDisappear`.
//

import SwiftUI

/// A simple water-droplet silhouette used for the logo.
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
    let onFinished: () -> Void

    // Animation layer state.
    @State private var bubblesActive = false
    @State private var bgShift = false
    @State private var showLogo = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var exiting = false

    // Single coordinator timer.
    @State private var timer: Timer?
    @State private var elapsed: Double = 0
    @State private var didFinish = false

    var body: some View {
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

            // Layer 2 — continuous rising bubbles.
            RisingBubblesView(isActive: $bubblesActive, count: 26, tint: BFColor.water)
                .ignoresSafeArea()
                .opacity(0.9)

            // Layer 3 — logo + title.
            VStack(spacing: 18) {
                ZStack {
                    DropShape()
                        .fill(LinearGradient(colors: [BFColor.waterSoft, BFColor.waterActive],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 96, height: 116)
                        .shadow(color: BFColor.aquaGlow, radius: 18, y: 8)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(y: 6)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Brim Flow")
                        .font(BFFont.display(34))
                        .foregroundColor(Color(hex: "#0E3A45"))
                    Text("Stay full. Stay fresh.")
                        .font(BFFont.headline(15))
                        .foregroundColor(Color(hex: "#3E6B76"))
                }
                .opacity(textOpacity)
            }
            .scaleEffect(exiting ? 8 : 1)
            .opacity(exiting ? 0 : 1)
        }
        .onAppear(perform: start)
        .onDisappear(perform: cleanup)
    }

    // MARK: - Coordinator

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
        // Phase 4 (2.5s): designed exit — logo scales up and fades out.
        if elapsed >= 2.5 && !exiting {
            withAnimation(.easeIn(duration: 0.55)) {
                exiting = true
            }
        }
        // Finish shortly after the exit animation begins.
        if elapsed >= 3.05 && !didFinish {
            didFinish = true
            timer?.invalidate()
            timer = nil
            onFinished()
        }
    }

    private func cleanup() {
        // Stop every looping animation so nothing runs in the background.
        timer?.invalidate()
        timer = nil
        bubblesActive = false
        withAnimation(.linear(duration: 0)) {
            bgShift = false
        }
    }
}

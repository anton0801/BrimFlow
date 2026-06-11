//
//  OnboardingView.swift
//  BrimFlow
//
//  Three illustrated pages, each with a distinct interactive element:
//  1) tap-to-burst bubbles, 2) drag-to-fill a glass, 3) scroll-driven parallax.
//  Loops reset on `.onDisappear`; completion is reported to the coordinator.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page = 0
    @State private var isActive = true
    private let pageCount = 3

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#F2FBFD"), Color(hex: "#E7F6FA"), Color(hex: "#D8EEF4")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingTapPage(isActive: $isActive).tag(0)
                    OnboardingDragPage(isActive: $isActive).tag(1)
                    OnboardingScrollPage(isActive: $isActive).tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: page)

                controls
            }
        }
        .onDisappear { isActive = false }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            // Dot indicators.
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? BFColor.water : BFColor.dividerSoft)
                        .frame(width: i == page ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                }
            }

            HStack(spacing: 14) {
                Button("Skip") { onComplete() }
                    .font(BFFont.headline(15))
                    .foregroundColor(BFColor.secondaryText)
                    .frame(maxWidth: .infinity)

                Button(page == pageCount - 1 ? "Let's Flow" : "Next") {
                    if page == pageCount - 1 {
                        onComplete()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, BFSpacing.lg)
        }
        .padding(.bottom, 34)
        .padding(.top, 10)
    }
}

// MARK: - Page 1: tap to burst bubbles

private struct OnboardingTapPage: View {
    @Binding var isActive: Bool
    @State private var burstID = 0
    @State private var animate = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(BFColor.water.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.05 : 0.95)

                // Burst particles.
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) / 12 * 2 * .pi
                    Circle()
                        .fill(BFColor.waterSoft.opacity(0.8))
                        .frame(width: 14, height: 14)
                        .offset(x: animate ? cos(angle) * 130 : 0,
                                y: animate ? sin(angle) * 130 : 0)
                        .opacity(animate ? 0 : 1)
                }
                .id(burstID)

                DropShape()
                    .fill(LinearGradient(colors: [BFColor.waterSoft, BFColor.waterActive],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 96, height: 116)
                    .shadow(color: BFColor.aquaGlow, radius: 14, y: 6)
                    .scaleEffect(animate ? 0.9 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { triggerBurst() }

            VStack(spacing: 10) {
                Text("Understand the problem")
                    .font(BFFont.title(26))
                    .foregroundColor(Color(hex: "#0E3A45"))
                    .multilineTextAlignment(.center)
                Text("It's easy to forget to drink during a busy day. Tap the drop to see what a sip can do.")
                    .font(BFFont.body(16))
                    .foregroundColor(Color(hex: "#3E6B76"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onDisappear {
            withAnimation(.linear(duration: 0)) { pulse = false }
        }
    }

    private func triggerBurst() {
        burstID += 1
        animate = false
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.7)) { animate = true }
        }
    }
}

// MARK: - Page 2: drag to fill a glass

private struct OnboardingDragPage: View {
    @Binding var isActive: Bool
    @State private var fill: CGFloat = 0.3

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                // Mini bubble glass that follows the drag.
                BubbleGlassView(progress: Double(fill),
                                glassWidth: 130, glassHeight: 210, ringSize: 250, bubbleCount: 16)

                VStack {
                    Spacer()
                    Label("Drag up & down", systemImage: "hand.draw.fill")
                        .font(BFFont.caption(13))
                        .foregroundColor(BFColor.secondaryText)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Capsule().fill(BFColor.secondaryFill))
                }
                .frame(height: 250)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = -value.translation.height / 240
                        fill = min(max(fill + delta * 0.06, 0), 1)
                    }
            )

            Text("\(Int(fill * 100))% full")
                .font(BFFont.mono(20))
                .foregroundColor(BFColor.water)

            VStack(spacing: 10) {
                Text("Build a habit")
                    .font(BFFont.title(26))
                    .foregroundColor(Color(hex: "#0E3A45"))
                Text("Keep your hydration in one place. Log every sip and watch the glass rise.")
                    .font(BFFont.body(16))
                    .foregroundColor(Color(hex: "#3E6B76"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Spacer()
        }
    }
}

// MARK: - Page 3: scroll-driven parallax

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct OnboardingScrollPage: View {
    @Binding var isActive: Bool
    @State private var offset: CGFloat = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                // Parallax bubble layers move at different rates with scrolling.
                ForEach(0..<8, id: \.self) { i in
                    let seed = CGFloat(i)
                    Circle()
                        .fill(BFColor.water.opacity(0.10 + Double(i % 3) * 0.05))
                        .frame(width: 40 + seed * 12, height: 40 + seed * 12)
                        .offset(x: (seed.truncatingRemainder(dividingBy: 2) == 0 ? -1 : 1) * (40 + seed * 14),
                                y: 60 + seed * 60 + offset * (0.2 + seed * 0.06))
                }

                GeometryReader { geo in
                    Color.clear.preference(key: ScrollOffsetKey.self,
                                           value: geo.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)

                VStack(spacing: 28) {
                    Spacer().frame(height: 40)
                    ZStack {
                        Circle().fill(BFColor.coral.opacity(0.14)).frame(width: 200, height: 200)
                            .scaleEffect(1 + min(max(-offset / 600, 0), 0.3))
                        Image(systemName: "heart.fill")
                            .font(.system(size: 70, weight: .bold))
                            .foregroundColor(BFColor.coral)
                            .rotationEffect(.degrees(Double(offset) * 0.05))
                    }

                    VStack(spacing: 10) {
                        Text("Feel better")
                            .font(BFFont.title(26))
                            .foregroundColor(Color(hex: "#0E3A45"))
                        Text("Use a goal, bubbles and gentle reminders to stay consistent. Scroll to explore.")
                            .font(BFFont.body(16))
                            .foregroundColor(Color(hex: "#3E6B76"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }

                    VStack(spacing: 14) {
                        featureRow("drop.fill", "Living bubble glass", BFColor.water)
                        featureRow("bell.fill", "Smart sip reminders", BFColor.coral)
                        featureRow("flame.fill", "Daily streaks", BFColor.statusBehind)
                        featureRow("chart.bar.fill", "Clear reports", BFColor.statusMet)
                    }
                    .padding(.horizontal, BFSpacing.lg)

                    Spacer().frame(height: 60)
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset = $0 }
    }

    private func featureRow(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: icon).foregroundColor(color)
            }
            Text(text)
                .font(BFFont.headline(15))
                .foregroundColor(Color(hex: "#0E3A45"))
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: BFRadius.md).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: BFRadius.md).stroke(BFColor.border, lineWidth: 1))
    }
}

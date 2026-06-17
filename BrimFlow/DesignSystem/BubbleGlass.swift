//
//  BubbleGlass.swift
//  BrimFlow
//
//  The signature "living glass": a tapered vessel that fills bottom-to-top with
//  a wavy water surface and rising bubbles, wrapped in a goal ring.
//
//  Everything animated here is driven by a single `TimelineView` clock that is
//  paused via `isActive` and reset on `.onDisappear`, so no loop leaks into the
//  rest of the app.
//

import SwiftUI

// MARK: - Deterministic pseudo-random (stable per bubble index)

private func bfRand(_ seed: Double) -> Double {
    let v = sin(seed * 12.9898) * 43758.5453
    return v - floor(v)
}

// MARK: - Glass silhouette

/// A slightly tapered drinking-glass outline (narrower at the base).
struct GlassShape: Shape {
    var taper: CGFloat = 0.12
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * taper
        let r: CGFloat = min(rect.width, rect.height) * 0.16
        let topL = CGPoint(x: rect.minX, y: rect.minY)
        let topR = CGPoint(x: rect.maxX, y: rect.minY)
        let botL = CGPoint(x: rect.minX + inset, y: rect.maxY)
        let botR = CGPoint(x: rect.maxX - inset, y: rect.maxY)

        p.move(to: CGPoint(x: topL.x + r, y: topL.y))
        p.addLine(to: CGPoint(x: topR.x - r, y: topR.y))
        p.addQuadCurve(to: CGPoint(x: topR.x, y: topR.y + r),
                       control: CGPoint(x: topR.x, y: topR.y))
        p.addLine(to: CGPoint(x: botR.x, y: botR.y - r))
        p.addQuadCurve(to: CGPoint(x: botR.x - r, y: botR.y),
                       control: CGPoint(x: botR.x, y: botR.y))
        p.addLine(to: CGPoint(x: botL.x + r, y: botL.y))
        p.addQuadCurve(to: CGPoint(x: botL.x, y: botL.y - r),
                       control: CGPoint(x: botL.x, y: botL.y))
        p.addLine(to: CGPoint(x: topL.x, y: topL.y + r))
        p.addQuadCurve(to: CGPoint(x: topL.x + r, y: topL.y),
                       control: CGPoint(x: topL.x, y: topL.y))
        p.closeSubpath()
        return p
    }
}

// MARK: - Bubble glass view

struct BubbleGlassView: View {
    /// Goal progress 0...1+ controlling both the ring and the water level.
    var progress: Double
    var glassWidth: CGFloat = 150
    var glassHeight: CGFloat = 240
    var ringSize: CGFloat = 300
    var bubbleCount: Int = 22

    @State private var isActive = true
    // Time-based fill easing state.
    @State private var fromProgress: Double = 0
    @State private var toProgress: Double = 0
    @State private var animStart: Date = Date()
    private let fillDuration: Double = 0.9

    private var clampedTarget: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            // Goal ring around the glass.
            RingProgress(progress: progress, lineWidth: 16, size: ringSize) {
                EmptyView()
            }

            glass
                .frame(width: glassWidth, height: glassHeight)
        }
        .frame(width: ringSize, height: ringSize)
        .onAppear {
            isActive = true
            // Animate from empty up to the current value on first appear.
            fromProgress = 0
            toProgress = clampedTarget
            animStart = Date()
        }
        .onChange(of: clampedTarget) { newValue in
            fromProgress = currentDisplayed()
            toProgress = newValue
            animStart = Date()
        }
        .onDisappear {
            // Stop the clock so no animation runs in the background.
            isActive = false
        }
    }

    /// Eased displayed fill at "now" (used to start a new tween from the right place).
    private func currentDisplayed() -> Double {
        let elapsed = Date().timeIntervalSince(animStart)
        let t = min(max(elapsed / fillDuration, 0), 1)
        let eased = easeOut(t)
        return fromProgress + (toProgress - fromProgress) * eased
    }

    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

    private var glass: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            let now = timeline.date
            let elapsed = now.timeIntervalSinceReferenceDate
            let fillElapsed = now.timeIntervalSince(animStart)
            let t = min(max(fillElapsed / fillDuration, 0), 1)
            let displayed = fromProgress + (toProgress - fromProgress) * easeOut(t)

            Canvas { context, size in
                let glassPath = GlassShape().path(in: CGRect(origin: .zero, size: size))
                context.clip(to: glassPath)

                drawWater(in: &context, size: size, fill: displayed, elapsed: elapsed)
                drawBubbles(in: &context, size: size, fill: displayed, elapsed: elapsed)
            }
            .overlay(
                GlassShape()
                    .stroke(LinearGradient(colors: [BFColor.waterSoft.opacity(0.9), BFColor.water.opacity(0.6)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 3)
            )
            .overlay(
                // Soft highlight strip down the left side of the glass.
                GlassShape()
                    .fill(LinearGradient(colors: [.white.opacity(0.25), .clear],
                                         startPoint: .topLeading, endPoint: .center))
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
        }
    }

    // MARK: Drawing

    private func waterTopY(size: CGSize, fill: Double) -> CGFloat {
        // Leave a small empty rim at the very top even at 100%.
        let usable = size.height * 0.96
        return size.height - CGFloat(min(fill, 1)) * usable
    }

    private func drawWater(in context: inout GraphicsContext, size: CGSize, fill: Double, elapsed: Double) {
        guard fill > 0.001 else { return }
        let topY = waterTopY(size: size, fill: fill)
        let amplitude: CGFloat = 6
        let wavelength = size.width

        func wavePath(phase: Double, amp: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: topY))
            var x: CGFloat = 0
            while x <= size.width {
                let rel = Double(x / wavelength) * 2 * .pi
                let y = topY + amp * CGFloat(sin(rel + phase))
                p.addLine(to: CGPoint(x: x, y: y))
                x += 4
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
            return p
        }

        // Back wave (lighter, slower).
        let back = wavePath(phase: elapsed * 1.1 + .pi / 2, amp: amplitude * 0.7)
        context.fill(back, with: .color(BFColor.waterSoft.opacity(0.55)))

        // Front wave with vertical gradient.
        let front = wavePath(phase: elapsed * 1.7, amp: amplitude)
        context.fill(front, with: .linearGradient(
            Gradient(colors: [BFColor.waterSoft, BFColor.water, BFColor.waterActive]),
            startPoint: CGPoint(x: 0, y: topY),
            endPoint: CGPoint(x: 0, y: size.height)
        ))
    }

    private func drawBubbles(in context: inout GraphicsContext, size: CGSize, fill: Double, elapsed: Double) {
        guard fill > 0.02 else { return }
        let topY = waterTopY(size: size, fill: fill)
        let bottomY = size.height

        for i in 0..<bubbleCount {
            let seed = Double(i) + 1
            let xFrac = bfRand(seed * 1.7)
            let radius = 2 + bfRand(seed * 2.3) * 5
            let speed = 0.25 + bfRand(seed * 3.1) * 0.5
            let phaseOffset = bfRand(seed * 4.9)
            let swayAmp = 4 + bfRand(seed * 5.5) * 6

            // Rise fraction loops 0->1 (0 = bottom, 1 = surface).
            let raw = (elapsed * speed + phaseOffset).truncatingRemainder(dividingBy: 1)
            let rise = raw < 0 ? raw + 1 : raw
            let y = bottomY - rise * (bottomY - topY)
            guard y >= topY else { continue }

            let sway = CGFloat(sin(elapsed * 2 + seed)) * swayAmp
            let x = xFrac * size.width + sway

            // Fade out as the bubble nears the surface.
            let fade = 1 - rise
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.5 * fade + 0.15)))
        }
    }
}

struct RisingBubblesView: View {
    @Binding var isActive: Bool
    var count: Int = 26
    var tint: Color = .white

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for i in 0..<count {
                        let seed = Double(i) + 1
                        let xFrac = bfRand(seed * 1.3)
                        let radius = 4 + bfRand(seed * 2.7) * 16
                        let speed = 0.04 + bfRand(seed * 3.3) * 0.10
                        let phaseOffset = bfRand(seed * 4.1)
                        let swayAmp = 10 + bfRand(seed * 5.9) * 30

                        let raw = (elapsed * speed + phaseOffset).truncatingRemainder(dividingBy: 1)
                        let rise = raw < 0 ? raw + 1 : raw
                        let y = size.height - rise * (size.height + radius * 2) + radius
                        let sway = CGFloat(sin(elapsed * 0.6 + seed)) * swayAmp
                        let x = xFrac * size.width + sway

                        let fade = sin(rise * .pi) // fade in/out at edges
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(tint.opacity(0.10 + 0.18 * fade)))
                        context.stroke(Path(ellipseIn: rect),
                                       with: .color(tint.opacity(0.10 * fade)), lineWidth: 1)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

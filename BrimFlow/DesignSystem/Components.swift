//
//  Components.swift
//  BrimFlow
//
//  Custom, reusable UI building blocks used across every screen.
//

import SwiftUI

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BFFont.headline(16))
            .foregroundColor(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.md, style: .continuous)
                    .fill(LinearGradient(colors: [BFColor.waterSoft, BFColor.waterActive],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: BFColor.aquaGlow, radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BFFont.headline(16))
            .foregroundColor(BFColor.secondaryText)
            .padding(.vertical, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.md, style: .continuous)
                    .fill(BFColor.secondaryFill)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BFFont.headline(16))
            .foregroundColor(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.md, style: .continuous)
                    .fill(LinearGradient(colors: [BFColor.coralSoft, BFColor.coralActive],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: BFColor.coralGlow, radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Subtle press-scale for tappable cards/icons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Card

struct BFCard<Content: View>: View {
    @Environment(\.bfPalette) private var palette
    var padding: CGFloat = BFSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.lg, style: .continuous)
                    .fill(palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BFRadius.lg, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .shadow(color: BFColor.softShadow, radius: 14, x: 0, y: 8)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    @Environment(\.bfPalette) private var palette
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BFFont.title(20))
                    .foregroundColor(palette.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(BFFont.caption())
                        .foregroundColor(palette.textSecondary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(BFFont.headline(14))
                    .foregroundColor(BFColor.water)
            }
        }
    }
}

// MARK: - Text field

struct BFTextField: View {
    @Environment(\.bfPalette) private var palette
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var icon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BFFont.caption())
                .foregroundColor(palette.textSecondary)
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(BFColor.water)
                        .frame(width: 20)
                }
                TextField("", text: $text)
                    .font(BFFont.body(16))
                    .foregroundColor(palette.textPrimary)
                    .keyboardType(keyboard)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: BFRadius.sm, style: .continuous)
                    .fill(palette.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BFRadius.sm, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Filter chip

struct BFChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = BFColor.water
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BFFont.caption(13))
                .foregroundColor(isSelected ? .white : color)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Capsule().fill(isSelected ? color : color.opacity(0.14))
                )
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Ring progress

struct RingProgress<Label: View>: View {
    var progress: Double          // 0...1 (clamped for the arc)
    var lineWidth: CGFloat = 14
    var size: CGFloat = 120
    var tint: Color = BFColor.water
    var trackColor: Color = BFColor.secondaryFill
    @ViewBuilder var label: () -> Label

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(colors: [BFColor.waterSoft, tint, BFColor.waterActive],
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.35), radius: 6)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clamped)
            label()
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    @Environment(\.bfPalette) private var palette
    let icon: String
    let title: String
    let value: String
    var accent: Color = BFColor.water

    var body: some View {
        BFCard(padding: BFSpacing.md) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(accent.opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(accent)
                }
                Text(value)
                    .font(BFFont.title(22))
                    .foregroundColor(palette.textPrimary)
                Text(title)
                    .font(BFFont.caption())
                    .foregroundColor(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    @Environment(\.bfPalette) private var palette
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(BFColor.water.opacity(0.12)).frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(BFColor.water)
            }
            Text(title)
                .font(BFFont.title(18))
                .foregroundColor(palette.textPrimary)
            Text(message)
                .font(BFFont.body(14))
                .foregroundColor(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Confirmation toast

struct ToastView: View {
    let text: String
    var icon: String = "checkmark.circle.fill"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(text)
                .font(BFFont.headline(14))
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(
            Capsule().fill(LinearGradient(colors: [BFColor.water, BFColor.waterActive],
                                          startPoint: .leading, endPoint: .trailing))
        )
        .shadow(color: BFColor.aquaGlow, radius: 10, y: 4)
    }
}

/// Attaches an auto-dismissing toast to any view.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        ZStack {
            content
            if let message = message {
                VStack {
                    Spacer()
                    ToastView(text: message)
                        .padding(.bottom, 110)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.message = nil
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }

    /// Standard screen background gradient + palette injection.
    func bfScreenBackground() -> some View {
        modifier(ScreenBackgroundModifier())
    }
}

struct ScreenBackgroundModifier: ViewModifier {
    @Environment(\.bfPalette) private var palette
    func body(content: Content) -> some View {
        ZStack {
            palette.backgroundGradient.ignoresSafeArea()
            content
        }
    }
}

// MARK: - Segmented control

struct BFSegmented<T: Hashable>: View {
    @Environment(\.bfPalette) private var palette
    let options: [(value: T, label: String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let isSel = option.value == selection
                Text(option.label)
                    .font(BFFont.caption(13))
                    .foregroundColor(isSel ? .white : palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        ZStack {
                            if isSel {
                                RoundedRectangle(cornerRadius: BFRadius.sm - 2, style: .continuous)
                                    .fill(BFColor.water)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selection = option.value
                        }
                    }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: BFRadius.sm, style: .continuous)
                .fill(palette.backgroundSecondary)
        )
    }
}

//
//  Charts.swift
//  BrimFlow
//
//  Hand-built charts (iOS 15 compatible — no Swift Charts): a bar chart with a
//  goal line, a donut chart with legend, and a goal-completion meter.
//

import SwiftUI

// MARK: - Bar chart

struct BarChartView: View {
    @Environment(\.bfPalette) private var palette
    let data: [(date: Date, ml: Double)]
    let goal: Double
    let format: (Double) -> String

    private var maxValue: Double {
        max(goal, data.map { $0.ml }.max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let chartHeight = geo.size.height - 22
                let count = max(data.count, 1)
                let slot = geo.size.width / CGFloat(count)
                let barWidth = min(28, slot * 0.55)

                ZStack(alignment: .bottomLeading) {
                    // Goal line.
                    let goalY = chartHeight * (1 - CGFloat(min(goal / maxValue, 1)))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: goalY))
                        p.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(BFColor.coral.opacity(0.7))

                    ForEach(Array(data.enumerated()), id: \.offset) { idx, point in
                        let h = chartHeight * CGFloat(min(point.ml / maxValue, 1))
                        let metGoal = point.ml >= goal && goal > 0
                        let x = slot * CGFloat(idx) + (slot - barWidth) / 2
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LinearGradient(
                                    colors: metGoal ? [BFColor.statusMet, BFColor.statusMet.opacity(0.7)]
                                                    : [BFColor.waterSoft, BFColor.water],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: barWidth, height: max(3, h))
                        }
                        .frame(width: barWidth)
                        .position(x: x + barWidth / 2, y: chartHeight - h / 2)

                        Text(dayLabel(point.date))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .position(x: x + barWidth / 2, y: chartHeight + 12)
                    }
                }
            }
            .frame(height: 180)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = data.count > 10 ? "d" : "EEE"
        return f.string(from: date)
    }
}

// MARK: - Donut chart

struct DonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct DonutChartView: View {
    @Environment(\.bfPalette) private var palette
    let slices: [DonutSlice]

    private var total: Double { max(slices.reduce(0) { $0 + $1.value }, 0.0001) }

    var body: some View {
        HStack(spacing: BFSpacing.lg) {
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                    let start = cumulative(before: idx) / total
                    let end = (cumulative(before: idx) + slice.value) / total
                    Circle()
                        .trim(from: CGFloat(start), to: CGFloat(end))
                        .stroke(slice.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text("\(slices.count)")
                        .font(BFFont.title(20))
                        .foregroundColor(palette.textPrimary)
                    Text("types")
                        .font(BFFont.caption(10))
                        .foregroundColor(palette.textSecondary)
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(slices) { slice in
                    HStack(spacing: 8) {
                        Circle().fill(slice.color).frame(width: 10, height: 10)
                        Text(slice.label)
                            .font(BFFont.caption(12))
                            .foregroundColor(palette.textPrimary)
                        Spacer()
                        Text("\(Int((slice.value / total * 100).rounded()))%")
                            .font(BFFont.caption(12))
                            .foregroundColor(palette.textSecondary)
                    }
                }
            }
        }
    }

    private func cumulative(before index: Int) -> Double {
        slices.prefix(index).reduce(0) { $0 + $1.value }
    }
}

// MARK: - Goal completion meter

struct GoalCompletionView: View {
    @Environment(\.bfPalette) private var palette
    /// Fractions (0...1+) per day.
    let completions: [Double]

    private var metCount: Int { completions.filter { $0 >= 1 }.count }
    private var percent: Int {
        completions.isEmpty ? 0 : Int((Double(metCount) / Double(completions.count) * 100).rounded())
    }

    var body: some View {
        HStack(spacing: BFSpacing.md) {
            RingProgress(progress: completions.isEmpty ? 0 : Double(metCount) / Double(completions.count),
                         lineWidth: 10, size: 76, tint: BFColor.statusMet) {
                Text("\(percent)%")
                    .font(BFFont.headline(15))
                    .foregroundColor(palette.textPrimary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(metCount) of \(completions.count) days")
                    .font(BFFont.headline(16))
                    .foregroundColor(palette.textPrimary)
                Text("Goal reached in this period")
                    .font(BFFont.caption(12))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
        }
    }
}

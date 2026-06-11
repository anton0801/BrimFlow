//
//  Exporter.swift
//  BrimFlow
//
//  PDF report rendering, CSV export, and a UIKit share-sheet bridge.
//

import SwiftUI
import UIKit

// MARK: - Share sheet bridge

/// Presents `UIActivityViewController` from SwiftUI for sharing files/strings.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Exporter

enum Exporter {

    /// Builds a CSV string of all entries.
    static func entriesCSV(_ entries: [WaterEntry], drinks: [DrinkPreset], units: Units) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var rows = ["Date,Title,Category,Drink,Amount(\(units.short)),Effective(ml),Comment"]
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let drinkName = drinks.first(where: { $0.id == entry.drinkID })?.name ?? ""
            let amount = String(format: "%.1f", units.fromML(entry.amountML))
            let effective = String(format: "%.0f", entry.effectiveML(using: drinks))
            let comment = entry.comment.replacingOccurrences(of: ",", with: ";")
            let title = entry.title.replacingOccurrences(of: ",", with: ";")
            rows.append("\(formatter.string(from: entry.date)),\(title),\(entry.category.rawValue),\(drinkName),\(amount),\(effective),\(comment)")
        }
        return rows.joined(separator: "\n")
    }

    /// Writes a string to a temporary file and returns its URL (for sharing).
    static func writeTempFile(_ contents: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { return nil }
    }

    static func writeTempFile(_ data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return url
        } catch { return nil }
    }

    // MARK: - PDF report

    /// Renders a one-page hydration report PDF and returns its file URL.
    static func reportPDF(store: HydrationStore, settings: AppSettings) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BrimFlow-Report.pdf")

        let teal = UIColor(Color(hex: "#06B6D4"))
        let dark = UIColor(Color(hex: "#0E3A45"))
        let gray = UIColor(Color(hex: "#3E6B76"))

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let cg = ctx.cgContext

                // Header band
                cg.setFillColor(teal.cgColor)
                cg.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 90))
                draw("Brim Flow", at: CGPoint(x: 40, y: 28),
                     font: .systemFont(ofSize: 26, weight: .heavy), color: .white)
                draw("Hydration Report", at: CGPoint(x: 40, y: 60),
                     font: .systemFont(ofSize: 14, weight: .semibold), color: UIColor.white.withAlphaComponent(0.9))

                let df = DateFormatter(); df.dateStyle = .long
                draw(df.string(from: Date()), at: CGPoint(x: 40, y: 110),
                     font: .systemFont(ofSize: 12, weight: .regular), color: gray)

                // Summary stats
                var y: CGFloat = 150
                let stats: [(String, String)] = [
                    ("Daily goal", settings.formatAmount(store.dailyGoalML)),
                    ("Today's intake", settings.formatAmount(store.todayTotal)),
                    ("Today's progress", "\(Int((store.todayProgress * 100).rounded()))%"),
                    ("Current streak", "\(store.currentStreak) days"),
                    ("Longest streak", "\(store.longestStreak) days"),
                    ("7-day average", settings.formatAmount(store.averageDailyIntake))
                ]
                for (label, value) in stats {
                    draw(label, at: CGPoint(x: 40, y: y),
                         font: .systemFont(ofSize: 13, weight: .regular), color: gray)
                    draw(value, at: CGPoint(x: 320, y: y),
                         font: .systemFont(ofSize: 14, weight: .bold), color: dark)
                    y += 26
                }

                // Last 7 days bar chart
                y += 20
                draw("Last 7 days", at: CGPoint(x: 40, y: y),
                     font: .systemFont(ofSize: 16, weight: .bold), color: dark)
                y += 30

                let data = store.intakeByDay(days: 7)
                let maxML = max(store.dailyGoalML, data.map { $0.ml }.max() ?? 1)
                let chartBottom = y + 180
                let barWidth: CGFloat = 40
                let gap: CGFloat = 30
                let dfShort = DateFormatter(); dfShort.dateFormat = "EEE"

                for (i, point) in data.enumerated() {
                    let x = 50 + CGFloat(i) * (barWidth + gap)
                    let h = CGFloat(point.ml / maxML) * 160
                    let metGoal = point.ml >= store.dailyGoalML
                    let barColor = metGoal ? UIColor(Color(hex: "#22C55E")) : teal
                    cg.setFillColor(barColor.cgColor)
                    let bar = CGRect(x: x, y: chartBottom - h, width: barWidth, height: max(2, h))
                    let path = UIBezierPath(roundedRect: bar, cornerRadius: 6)
                    cg.addPath(path.cgPath); cg.fillPath()

                    draw(dfShort.string(from: point.date), at: CGPoint(x: x + 6, y: chartBottom + 6),
                         font: .systemFont(ofSize: 11, weight: .medium), color: gray)
                }

                // Goal line
                let goalY = chartBottom - CGFloat(store.dailyGoalML / maxML) * 160
                cg.setStrokeColor(UIColor(Color(hex: "#FB7185")).cgColor)
                cg.setLineWidth(1)
                cg.setLineDash(phase: 0, lengths: [4, 4])
                cg.move(to: CGPoint(x: 50, y: goalY))
                cg.addLine(to: CGPoint(x: pageRect.width - 50, y: goalY))
                cg.strokePath()
                cg.setLineDash(phase: 0, lengths: [])

                draw("Generated by Brim Flow", at: CGPoint(x: 40, y: pageRect.height - 50),
                     font: .systemFont(ofSize: 10, weight: .regular), color: gray)
            }
            return url
        } catch {
            return nil
        }
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        text.draw(at: point, withAttributes: attrs)
    }
}

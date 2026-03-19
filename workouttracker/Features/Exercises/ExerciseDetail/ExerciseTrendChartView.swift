import SwiftUI
import Charts

struct ExerciseTrendChartView: View {
    let points: [PersonalRecordsService.TrendPoint]

    @State private var metric: PersonalRecordsService.TrendMetric = .sessionVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppFormatting.localized("Trend"))
                    .font(.headline)

                Spacer()

                Picker(AppFormatting.localized("Metric"), selection: $metric) {
                    ForEach(PersonalRecordsService.TrendMetric.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }

            if points.isEmpty {
                ContentUnavailableView(AppFormatting.localized("No history yet"),
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(AppFormatting.localized("Log a few sets and you’ll see trends here."))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                Chart(points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Value", value(for: p, metric: metric))
                    )
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Value", value(for: p, metric: metric))
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: 220)
                
                if let summary = trendSummaryText() {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func value(for p: PersonalRecordsService.TrendPoint, metric: PersonalRecordsService.TrendMetric) -> Double {
        switch metric {
        case .sessionVolume: return p.sessionVolume
        case .bestEstimated1RM: return p.bestEstimated1RM
        case .bestSetWeight: return p.bestSetWeight
        case .bestReps: return Double(p.bestReps)
        }
    }
    
    private func trendSummaryText() -> String? {
        guard points.count >= 2 else { return nil }
        let last = points[points.count - 1]
        let prev = points[points.count - 2]

        let lv = value(for: last, metric: metric)
        let pv = value(for: prev, metric: metric)
        let delta = lv - pv

        switch metric {
        case .bestReps:
            let d = Int(delta.rounded())
            return AppFormatting.localizedFormat("Last: %1$lld (%2$@%3$lld vs previous)", Int64(lv.rounded()), d >= 0 ? "+" : "", Int64(d))
        default:
            let lastStr = lv.formatted(.number.precision(.fractionLength(0...1)))
            let deltaStr = delta.formatted(.number.precision(.fractionLength(0...1)))
            if pv != 0 {
                let pct = (delta / pv) * 100.0
                let pctStr = pct.formatted(.number.precision(.fractionLength(0...1)))
                return AppFormatting.localizedFormat("Last: %1$@ (%2$@%3$@, %4$@%5$@%% vs previous)", lastStr, delta >= 0 ? "+" : "", deltaStr, pct >= 0 ? "+" : "", pctStr)
            } else {
                return AppFormatting.localizedFormat("Last: %1$@ (%2$@%3$@ vs previous)", lastStr, delta >= 0 ? "+" : "", deltaStr)
            }
        }
    }
}

import SwiftUI

struct ProgressInsightsSectionView: View {
    let insights: ProgressInsightsService.Summary
    
    let onStartTarget: (ProgressInsightsService.TargetCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if !insights.targets.isEmpty {
                Text("Next up")
                    .font(.headline)

                ForEach(insights.targets) { t in
                    Button {
                        onStartTarget(t)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(t.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(t.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    // Keep a simple history link right under it (optional but useful).
                    NavigationLink {
                        WorkoutHistoryScreen(filter: .exercise(exerciseId: t.id, exerciseName: t.name))
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }

            // ... keep Trending/Stalled sections unchanged ...
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func deltaList(_ items: [ProgressInsightsService.ExerciseDelta]) -> some View {
        ForEach(items) { e in
            NavigationLink {
                WorkoutHistoryScreen(filter: .exercise(exerciseId: e.id, exerciseName: e.name))
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(e.name)
                        .lineLimit(1)

                    Spacer()

                    Text(deltaText(e))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private func deltaText(_ e: ProgressInsightsService.ExerciseDelta) -> String {
        let d = e.deltaVolume
        let sign = d >= 0 ? "+" : ""
        if let pct = e.pctDeltaVolume {
            let pctStr = (pct * 100).formatted(.number.precision(.fractionLength(0...1)))
            return "\(sign)\(d.formatted(.number.precision(.fractionLength(0...0)))) vol (\(sign)\(pctStr)%)"
        }
        return "\(sign)\(d.formatted(.number.precision(.fractionLength(0...0)))) vol"
    }
}

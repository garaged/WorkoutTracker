import Foundation
import SwiftData

@MainActor
protocol ProgressAnalyticsDataSource {
    func loadPerformanceSamples(in window: DateInterval?) throws -> [ExercisePerformanceSample]
    func loadPerformanceSamples(for exerciseID: UUID, in window: DateInterval?) throws -> [ExercisePerformanceSample]
    func loadSessionAnalyticsSamples(in window: DateInterval?) throws -> [SessionAnalyticsSample]
}

@MainActor
struct DefaultProgressAnalyticsDataSource: ProgressAnalyticsDataSource {
    private let context: ModelContext
    private let adapter: AnalyticsHistoryAdapter

    init(
        context: ModelContext,
        adapter: AnalyticsHistoryAdapter
    ) {
        self.context = context
        self.adapter = adapter
    }

    init(context: ModelContext) {
        self.init(context: context, adapter: AnalyticsHistoryAdapter())
    }

    func loadPerformanceSamples(in window: DateInterval?) throws -> [ExercisePerformanceSample] {
        let samples = try adapter.loadExercisePerformanceSamples(
            includeIncompleteSessions: false,
            context: context
        )

        return filter(samples: samples, in: window)
    }

    func loadPerformanceSamples(for exerciseID: UUID, in window: DateInterval?) throws -> [ExercisePerformanceSample] {
        let samples = try adapter.loadExercisePerformanceSamples(
            for: exerciseID,
            includeIncompleteSessions: false,
            context: context
        )

        return filter(samples: samples, in: window)
    }

    func loadSessionAnalyticsSamples(in window: DateInterval?) throws -> [SessionAnalyticsSample] {
        try adapter.loadSessionAnalyticsSamples(window: window, context: context)
    }

    private func filter(samples: [ExercisePerformanceSample], in window: DateInterval?) -> [ExercisePerformanceSample] {
        guard let window else { return samples }
        return samples.filter { window.contains($0.sessionStartedAt) }
    }
}

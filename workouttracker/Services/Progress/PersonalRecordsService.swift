import Foundation
import SwiftData

@MainActor
final class PersonalRecordsService {

    // MARK: - Public types

    struct PRDouble: Hashable {
        let value: Double
        let date: Date
        let sessionID: UUID
    }

    struct PRInt: Hashable {
        let value: Int
        let date: Date
        let sessionID: UUID
    }

    struct PersonalRecords: Hashable {
        let bestWeight: PRDouble?
        let bestReps: PRInt?
        let bestSetVolume: PRDouble?
        let bestSessionVolume: PRDouble?
        let bestEstimated1RM: PRDouble?
    }

    struct TrendPoint: Identifiable, Hashable {
        let id: UUID                 // sessionID
        let date: Date               // session.startedAt
        let sessionVolume: Double
        let bestSetWeight: Double
        let bestEstimated1RM: Double
        let bestReps: Int
    }

    struct NextTarget: Hashable {
        let text: String
        let targetWeight: Double?
        let targetReps: Int?
    }

    enum TrendMetric: String, CaseIterable, Identifiable {
        case sessionVolume = "Volume"
        case bestEstimated1RM = "Est. 1RM"
        case bestSetWeight = "Top Weight"
        case bestReps = "Top Reps"

        var id: String { rawValue }
    }

    private let calculator = PersonalRecordCalculator()
    private let adapter = AnalyticsHistoryAdapter()

    // MARK: - API

    func records(for exerciseID: UUID, context: ModelContext) throws -> PersonalRecords {
        let samples = try adapter.loadExercisePerformanceSamples(
            for: exerciseID,
            includeIncompleteSessions: false,
            context: context
        )
        let summary = calculator.summarizeExerciseProgress(for: exerciseID, samples: samples)

        return PersonalRecords(
            bestWeight: summary.bestWeight.map(Self.makePRDouble),
            bestReps: summary.bestReps.map(Self.makePRInt),
            bestSetVolume: summary.bestSetVolume.map(Self.makePRDouble),
            bestSessionVolume: summary.bestSessionVolume.map(Self.makePRDouble),
            bestEstimated1RM: summary.bestEstimatedOneRepMax.map(Self.makePRDouble)
        )
    }

    func trend(
        for exerciseID: UUID,
        limit: Int = 24,
        context: ModelContext
    ) throws -> [TrendPoint] {
        let samples = try adapter.loadExercisePerformanceSamples(
            for: exerciseID,
            includeIncompleteSessions: false,
            context: context
        )
        let sessionSnapshots = calculator.sessionProgression(from: samples)
        let trimmed = sessionSnapshots.suffix(limit)

        return trimmed.map {
            TrendPoint(
                id: $0.sessionID,
                date: $0.date,
                sessionVolume: $0.sessionVolume,
                bestSetWeight: $0.bestSetWeight,
                bestEstimated1RM: $0.bestEstimatedOneRepMax,
                bestReps: $0.bestReps
            )
        }
    }

    func nextTarget(
        for exerciseID: UUID,
        records: PersonalRecords,
        context: ModelContext
    ) throws -> NextTarget? {

        if let bw = records.bestWeight {
            let unit = try latestWeightUnit(for: exerciseID, context: context)
            let inc = recommendedWeightIncrement(unit: unit)
            let target = bw.value + inc

            let incStr = formatNumber(inc)
            let targetStr = formatNumber(target)

            let text: String
            if let unit, !unit.isEmpty {
                text = "Next target: beat your top weight by +\(incStr) \(unit) (to \(targetStr) \(unit))"
            } else {
                text = "Next target: beat your top weight by +\(incStr) (to \(targetStr))"
            }

            return NextTarget(text: text, targetWeight: target, targetReps: nil)
        }

        if let br = records.bestReps {
            let target = br.value + 1
            return NextTarget(
                text: "Next target: beat your top reps by +1 (to \(target))",
                targetWeight: nil,
                targetReps: target
            )
        }

        return nil
    }

    // MARK: - Internals
    private static func makePRDouble(_ snapshot: ExerciseProgressSummary.MetricSnapshot) -> PRDouble {
        PRDouble(value: snapshot.value, date: snapshot.achievedAt, sessionID: snapshot.sessionID)
    }

    private static func makePRInt(_ snapshot: ExerciseProgressSummary.IntMetricSnapshot) -> PRInt {
        PRInt(value: snapshot.value, date: snapshot.achievedAt, sessionID: snapshot.sessionID)
    }
}

// workouttracker/Services/Progress/PersonalRecordsService.swift

extension PersonalRecordsService {

    /// One-line “micro goal” that makes Progress feel actionable.
    func nextTargetText(
        for exerciseID: UUID,
        records: PersonalRecords,
        context: ModelContext
    ) throws -> String? {
        // Prefer weight target if we have it, otherwise reps.
        if let bw = records.bestWeight {
            let unit = try latestWeightUnit(for: exerciseID, context: context) // e.g. "kg" / "lb"
            let inc = recommendedWeightIncrement(unit: unit)

            let target = bw.value + inc

            let incStr = formatNumber(inc)
            let targetStr = formatNumber(target)

            if let unit, !unit.isEmpty {
                return "Next target: beat your top weight by +\(incStr) \(unit) (to \(targetStr) \(unit))"
            } else {
                return "Next target: beat your top weight by +\(incStr) (to \(targetStr))"
            }
        }

        if let br = records.bestReps {
            let target = br.value + 1
            return "Next target: beat your top reps by +1 (to \(target))"
        }

        return nil
    }

    // MARK: - Helpers

    private func latestWeightUnit(for exerciseID: UUID, context: ModelContext) throws -> String? {
        // Capture for predicate macro (same pattern you used elsewhere).
        let exId: UUID? = exerciseID

        var fd = FetchDescriptor<WorkoutSetLog>(
            predicate: #Predicate<WorkoutSetLog> { s in
                s.completed == true &&
                s.weight != nil &&
                s.sessionExercise?.exerciseId == exId
            },
            sortBy: [SortDescriptor(\WorkoutSetLog.completedAt, order: .reverse)]
        )
        fd.fetchLimit = 1

        let logs = try context.fetch(fd)
        guard let first = logs.first else { return nil }

        // Your code already uses `weightUnit.rawValue` elsewhere, so we mirror that.
        return first.weightUnit.rawValue
    }

    private func recommendedWeightIncrement(unit: String?) -> Double {
        let u = (unit ?? "").lowercased()
        if u.contains("lb") { return 5.0 }
        if u.contains("kg") { return 2.5 }
        return 2.5
    }

    private func formatNumber(_ x: Double) -> String {
        x.formatted(.number.precision(.fractionLength(0...1)))
    }
}

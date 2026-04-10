import SwiftData
import Foundation
import CoreLocation

// Host-only heavy-data scenarios for performance-focused UI test routes.

@MainActor
func seedHeavyStrengthSessionUITestDataIfNeeded(
    context: ModelContext,
    calendar: Calendar = .current
) throws {
    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    if sessions.contains(where: { $0.sourceRoutineNameSnapshot == PerformanceUITestSeed.heavyStrengthSessionName }) {
        return
    }

    let startedAt = calendar.date(byAdding: .minute, value: -42, to: Date()) ?? Date()
    let activityEnd = calendar.date(byAdding: .minute, value: 90, to: startedAt)

    let activity = Activity(
        title: PerformanceUITestSeed.heavyStrengthActivityTitle,
        startAt: startedAt,
        endAt: activityEnd,
        laneHint: 0,
        kind: .workout,
        workoutRoutineId: nil
    )
    activity.dayKey = DayTimelineEntryScreen.dayKey(for: startedAt)

    let session = WorkoutSession(
        startedAt: startedAt,
        sourceRoutineNameSnapshot: PerformanceUITestSeed.heavyStrengthSessionName
    )
    session.status = .inProgress
    session.endedAt = nil
    session.linkedActivityId = activity.id

    var exercises: [WorkoutSessionExercise] = []
    let completedAt = calendar.date(byAdding: .minute, value: -8, to: Date()) ?? Date()

    for exerciseIndex in 0..<10 {
        let exercise = WorkoutSessionExercise(
            order: exerciseIndex,
            exerciseId: UUID(),
            exerciseNameSnapshot: String(format: "UITest Heavy Exercise %02d", exerciseIndex + 1),
            trackingStyle: .strength,
            segment: .main,
            session: session
        )

        var setLogs: [WorkoutSetLog] = []
        for setIndex in 0..<4 {
            let isCompletedExercise = exerciseIndex < 3
            let set = WorkoutSetLog(
                order: setIndex,
                origin: .planned,
                reps: isCompletedExercise ? 8 : nil,
                weight: isCompletedExercise ? Double(40 + exerciseIndex * 5 + setIndex) : nil,
                weightUnit: .kg,
                completed: isCompletedExercise,
                completedAt: isCompletedExercise ? completedAt : nil,
                targetReps: 8,
                targetWeight: Double(40 + exerciseIndex * 5 + setIndex),
                targetWeightUnit: .kg,
                targetRestSeconds: 90
            )
            setLogs.append(set)
        }

        exercise.setLogs = setLogs
        exercises.append(exercise)
    }

    session.exercises = exercises
    activity.workoutSessionId = session.id

    context.insert(activity)
    context.insert(session)
    try context.save()
}

@MainActor
func assertHeavyStrengthSessionUITestSeed(context: ModelContext) throws {
    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    guard let session = sessions.first(where: { $0.sourceRoutineNameSnapshot == PerformanceUITestSeed.heavyStrengthSessionName }) else {
        fatalError("UITESTS assertion failed: heavy session seed expected a WorkoutSession named \(PerformanceUITestSeed.heavyStrengthSessionName).")
    }

    guard session.status == .inProgress, session.endedAt == nil else {
        fatalError("UITESTS assertion failed: heavy session seed expected the WorkoutSession to be in progress and not ended.")
    }

    guard session.linkedActivityId != nil else {
        fatalError("UITESTS assertion failed: heavy session seed expected the WorkoutSession to link to a workout Activity.")
    }

    let activities = try context.fetch(FetchDescriptor<Activity>())
    guard let activity = activities.first(where: { $0.title == PerformanceUITestSeed.heavyStrengthActivityTitle }) else {
        fatalError("UITESTS assertion failed: heavy session seed expected a linked Activity titled \(PerformanceUITestSeed.heavyStrengthActivityTitle).")
    }

    guard activity.workoutSessionId == session.id else {
        fatalError("UITESTS assertion failed: heavy session seed expected the linked Activity to reference the seeded WorkoutSession.")
    }

    let orderedExercises = session.exercises.sorted {
        if $0.order != $1.order { return $0.order < $1.order }
        return $0.id.uuidString < $1.id.uuidString
    }
    guard orderedExercises.count >= 10 else {
        fatalError("UITESTS assertion failed: heavy session seed expected at least 10 exercise cards.")
    }

    let orderedSets = orderedExercises.flatMap { exercise in
        exercise.setLogs.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    guard orderedSets.count >= 40 else {
        fatalError("UITESTS assertion failed: heavy session seed expected at least 40 set rows.")
    }

    guard orderedSets.allSatisfy({ $0.targetReps != nil && $0.targetWeight != nil && $0.targetWeightUnit == .kg }) else {
        fatalError("UITESTS assertion failed: heavy session seed expected every set row to be an editable strength-style row with deterministic targets.")
    }

    let plannerTarget = SessionResumePlanner().target(for: session)
    guard let targetSetID = plannerTarget?.setID else {
        fatalError("UITESTS assertion failed: heavy session seed expected SessionResumePlanner to resolve a target set.")
    }

    var targetExerciseIndex: Int?
    var precedingSetCount = 0
    for (index, exercise) in orderedExercises.enumerated() {
        let sets = exercise.setLogs.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
        if sets.contains(where: { $0.id == targetSetID }) {
            targetExerciseIndex = index
            break
        }
        precedingSetCount += sets.count
    }

    guard let resolvedTargetExerciseIndex = targetExerciseIndex else {
        fatalError("UITESTS assertion failed: heavy session seed expected the planner target to belong to the seeded WorkoutSession.")
    }

    guard resolvedTargetExerciseIndex > 0 else {
        fatalError("UITESTS assertion failed: heavy session seed expected the planner target to belong to a later exercise card, not the first one.")
    }

    guard precedingSetCount >= 8 else {
        fatalError("UITESTS assertion failed: heavy session seed expected at least 8 set rows before the planner target.")
    }
}

@MainActor
func seedHeavyTrackedActivityUITestDataIfNeeded(
    context: ModelContext,
    now: Date = Date()
) throws {
    let existing = try context.fetch(FetchDescriptor<TrackedActivitySession>())

    if !existing.contains(where: { $0.id == PerformanceUITestSeed.heavyTrackedLiveSessionID }) {
        let startedAt = now.addingTimeInterval(-(52 * 60))
        let liveSession = TrackedActivitySession(
            id: PerformanceUITestSeed.heavyTrackedLiveSessionID,
            createdAt: startedAt,
            updatedAt: now,
            startedAt: startedAt,
            endedAt: nil,
            activeIntervalStartedAt: startedAt,
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(
                elapsedDuration: now.timeIntervalSince(startedAt),
                distanceMeters: 8_450,
                activeEnergyKilocalories: 540,
                stepCount: 10_850
            ),
            healthKitExportState: .notRequested,
            routePoints: makeTrackedRoutePoints(
                startLatitude: 37.7749,
                startLongitude: -122.4194,
                count: 120,
                latitudeStep: 0.00018,
                longitudeStep: 0.00016
            ),
            notes: "UITest heavy live tracked session",
            lastResumedAt: startedAt
        )
        context.insert(liveSession)
    }

    if !existing.contains(where: { $0.id == PerformanceUITestSeed.heavyTrackedSummarySessionID }) {
        let startedAt = now.addingTimeInterval(-(3 * 60 * 60))
        let endedAt = startedAt.addingTimeInterval(82 * 60)
        let summarySession = TrackedActivitySession(
            id: PerformanceUITestSeed.heavyTrackedSummarySessionID,
            createdAt: startedAt,
            updatedAt: endedAt,
            startedAt: startedAt,
            endedAt: endedAt,
            activeIntervalStartedAt: nil,
            activityKind: .hiking,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(
                elapsedDuration: endedAt.timeIntervalSince(startedAt),
                distanceMeters: 11_920,
                activeEnergyKilocalories: 780,
                stepCount: 16_420
            ),
            healthKitExportState: .exported,
            routePoints: makeTrackedRoutePoints(
                startLatitude: 37.3317,
                startLongitude: -122.0301,
                count: 180,
                latitudeStep: 0.00011,
                longitudeStep: 0.00009
            ),
            notes: "UITest heavy tracked summary",
            healthKitExportAttemptedAt: endedAt,
            healthKitExportSucceededAt: endedAt,
            healthKitExportFailureMessage: nil,
            hasLocalChangesSinceHealthKitExport: false
        )
        context.insert(summarySession)
    }

    try context.save()
}

@MainActor
func assertHeavyTrackedActivityUITestSeed(context: ModelContext) throws {
    let sessions = try context.fetch(FetchDescriptor<TrackedActivitySession>())
    guard let liveSession = sessions.first(where: { $0.id == PerformanceUITestSeed.heavyTrackedLiveSessionID }) else {
        fatalError("UITESTS assertion failed: heavy tracked-activity seed expected an in-progress TrackedActivitySession with PerformanceUITestSeed.heavyTrackedLiveSessionID.")
    }

    guard liveSession.lifecycleState == .inProgress else {
        fatalError("UITESTS assertion failed: heavy tracked-activity seed expected the live session to stay in progress.")
    }

    guard liveSession.activeIntervalStartedAt != nil else {
        fatalError("UITESTS assertion failed: heavy tracked-activity seed expected an active interval anchor for elapsed timing.")
    }

    guard liveSession.routePoints.count >= 100 else {
        fatalError("UITESTS assertion failed: heavy tracked-activity seed expected at least 100 route points for the live session.")
    }
}

@MainActor
func assertHeavyTrackedSummaryUITestSeed(context: ModelContext) throws {
    let sessions = try context.fetch(FetchDescriptor<TrackedActivitySession>())
    guard let summarySession = sessions.first(where: { $0.id == PerformanceUITestSeed.heavyTrackedSummarySessionID }) else {
        fatalError("UITESTS assertion failed: heavy tracked-summary seed expected a completed TrackedActivitySession with PerformanceUITestSeed.heavyTrackedSummarySessionID.")
    }

    guard summarySession.lifecycleState == .completed else {
        fatalError("UITESTS assertion failed: heavy tracked-summary seed expected the summary session to be completed.")
    }

    guard summarySession.healthKitExportState == .exported else {
        fatalError("UITESTS assertion failed: heavy tracked-summary seed expected the summary session to be exported to Apple Health.")
    }

    guard summarySession.routePoints.count >= 150 else {
        fatalError("UITESTS assertion failed: heavy tracked-summary seed expected at least 150 route points.")
    }
}

private func makeTrackedRoutePoints(
    startLatitude: CLLocationDegrees,
    startLongitude: CLLocationDegrees,
    count: Int,
    latitudeStep: CLLocationDegrees,
    longitudeStep: CLLocationDegrees
) -> [TrackedActivityRoutePoint] {
    (0..<count).map { index in
        let wobble = Double(index % 5) * 0.00001
        let location = CLLocation(
            latitude: startLatitude + (Double(index) * latitudeStep) + wobble,
            longitude: startLongitude + (Double(index) * longitudeStep) - wobble
        )
        return TrackedActivityRoutePoint(location: location)
    }
}

import Foundation
import SwiftData
import CoreLocation

enum PerformanceSeedInstaller {
    static let installedMarkerKey = "debug.largeSeedInstalled.v1"

    static func clearInstalledMarker() {
        UserDefaults.standard.removeObject(forKey: installedMarkerKey)
    }

    @discardableResult
    static func installIfRequested(
        context: ModelContext,
        env: [String: String],
        calendar: Calendar = .current
    ) throws -> Bool {
        #if DEBUG
        guard env["DEBUG_INSTALL_LARGE_SEED"] == "1" else { return false }

        if UserDefaults.standard.bool(forKey: installedMarkerKey) {
            return false
        }

        if try hasInstalledLargeSeed(context: context) {
            UserDefaults.standard.set(true, forKey: installedMarkerKey)
            return false
        }

        try seedLargeStrengthInstallIfNeeded(context: context, calendar: calendar)
        try seedLargeTrackedActivityInstallIfNeeded(context: context, now: Date(), calendar: calendar)
        UserDefaults.standard.set(true, forKey: installedMarkerKey)
        return true
        #else
        return false
        #endif
    }

    private static func hasInstalledLargeSeed(context: ModelContext) throws -> Bool {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        if sessions.contains(where: { $0.sourceRoutineNameSnapshot == PerformanceInstallSeed.activeStrengthSessionName }) {
            return true
        }

        let tracked = try context.fetch(FetchDescriptor<TrackedActivitySession>())
        return tracked.contains(where: { $0.id == PerformanceInstallSeed.heavyTrackedSummarySessionID })
    }
}

enum PerformanceInstallSeed {
    static let activeStrengthSessionName = "DEBUG — Large Seed Active Session"
    static let activeStrengthActivityTitle = "DEBUG — Large Seed Active Workout"
    static let historicalStrengthPrefix = "DEBUG — Large Seed History"

    static let heavyTrackedLiveSessionID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    static let heavyTrackedSummarySessionID = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    static let trackedHistoryNotePrefix = "DEBUG large tracked history"

    static let strengthExercises: [(id: UUID, name: String, trackingStyle: ExerciseTrackingStyle, baseWeight: Double, reps: Int)] = [
        (UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, "Barbell Back Squat", .strength, 100, 5),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, "Bench Press", .strength, 75, 6),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, "Deadlift", .strength, 120, 5),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, "Overhead Press", .strength, 45, 6),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, "Bent-Over Row", .strength, 70, 8),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000006")!, "Pull-Up", .strength, 0, 8),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000007")!, "Incline Dumbbell Press", .strength, 30, 10),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000008")!, "Romanian Deadlift", .strength, 90, 8),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000009")!, "Leg Press", .strength, 180, 12),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000010")!, "Lat Pulldown", .strength, 55, 10),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000011")!, "Seated Cable Row", .strength, 50, 10),
        (UUID(uuidString: "10000000-0000-0000-0000-000000000012")!, "Dumbbell Lunge", .strength, 22.5, 10)
    ]
}

func seedLargeStrengthInstallIfNeeded(
    context: ModelContext,
    calendar: Calendar = .current
) throws {
    let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
    if sessions.contains(where: { $0.sourceRoutineNameSnapshot == PerformanceInstallSeed.activeStrengthSessionName }) {
        return
    }

    let now = Date()
    let startedAt = calendar.date(byAdding: .minute, value: -55, to: now) ?? now
    let activityEnd = calendar.date(byAdding: .minute, value: 110, to: startedAt)

    let activity = Activity(
        title: PerformanceInstallSeed.activeStrengthActivityTitle,
        startAt: startedAt,
        endAt: activityEnd,
        laneHint: 0,
        kind: .workout,
        workoutRoutineId: nil
    )
    activity.dayKey = DayTimelineEntryScreen.dayKey(for: startedAt)

    let activeSession = WorkoutSession(
        startedAt: startedAt,
        sourceRoutineNameSnapshot: PerformanceInstallSeed.activeStrengthSessionName
    )
    activeSession.status = .inProgress
    activeSession.endedAt = nil
    activeSession.linkedActivityId = activity.id

    var activeExercises: [WorkoutSessionExercise] = []
    let completedAt = calendar.date(byAdding: .minute, value: -10, to: now) ?? now

    for (exerciseIndex, spec) in PerformanceInstallSeed.strengthExercises.enumerated() {
        let exercise = WorkoutSessionExercise(
            order: exerciseIndex,
            exerciseId: spec.id,
            exerciseNameSnapshot: spec.name,
            trackingStyle: spec.trackingStyle,
            segment: .main,
            session: activeSession
        )

        var setLogs: [WorkoutSetLog] = []
        for setIndex in 0..<5 {
            let completedSetsForExercise: Int
            switch exerciseIndex {
            case 0...2: completedSetsForExercise = 5
            case 3: completedSetsForExercise = 2
            default: completedSetsForExercise = 0
            }

            let isCompleted = setIndex < completedSetsForExercise
            let weightValue = spec.baseWeight == 0 ? nil : (spec.baseWeight + Double(setIndex) * 2.5)
            let set = WorkoutSetLog(
                order: setIndex,
                origin: .planned,
                reps: isCompleted ? spec.reps : nil,
                weight: isCompleted ? weightValue : nil,
                weightUnit: .kg,
                completed: isCompleted,
                completedAt: isCompleted ? completedAt : nil,
                targetReps: spec.reps,
                targetWeight: weightValue,
                targetWeightUnit: .kg,
                targetRestSeconds: 90
            )
            setLogs.append(set)
        }

        exercise.setLogs = setLogs
        activeExercises.append(exercise)
    }

    activeSession.exercises = activeExercises
    activity.workoutSessionId = activeSession.id
    context.insert(activity)
    context.insert(activeSession)

    let historySessionCount = 24
    for sessionIndex in 0..<historySessionCount {
        let daysAgo = max(2, sessionIndex * 3 + 2)
        let sessionStart = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let session = WorkoutSession(
            startedAt: sessionStart,
            sourceRoutineNameSnapshot: "\(PerformanceInstallSeed.historicalStrengthPrefix) \(sessionIndex + 1)"
        )
        session.status = .completed
        session.endedAt = calendar.date(byAdding: .minute, value: 68 + (sessionIndex % 4) * 6, to: sessionStart)

        var exercises: [WorkoutSessionExercise] = []
        let exerciseRangeStart = sessionIndex % 4
        let chosenExercises = Array(PerformanceInstallSeed.strengthExercises[exerciseRangeStart..<(exerciseRangeStart + 6)])

        for (exerciseOrder, spec) in chosenExercises.enumerated() {
            let exercise = WorkoutSessionExercise(
                order: exerciseOrder,
                exerciseId: spec.id,
                exerciseNameSnapshot: spec.name,
                trackingStyle: spec.trackingStyle,
                segment: .main,
                session: session
            )

            var setLogs: [WorkoutSetLog] = []
            var secondsOffset = 7 * 60
            for setIndex in 0..<4 {
                let weightValue = spec.baseWeight == 0 ? nil : (spec.baseWeight + Double(sessionIndex) * 1.25 + Double(setIndex) * 2.5)
                let repsValue = max(4, spec.reps - (sessionIndex % 3) + (setIndex % 2))
                let completedAtValue = sessionStart.addingTimeInterval(TimeInterval(secondsOffset))
                let set = WorkoutSetLog(
                    order: setIndex,
                    origin: .planned,
                    reps: repsValue,
                    weight: weightValue,
                    weightUnit: .kg,
                    completed: true,
                    completedAt: completedAtValue,
                    targetReps: spec.reps,
                    targetWeight: weightValue,
                    targetWeightUnit: .kg,
                    targetRestSeconds: 120
                )
                setLogs.append(set)
                secondsOffset += 180
            }

            exercise.setLogs = setLogs
            exercises.append(exercise)
        }

        session.exercises = exercises
        context.insert(session)
    }

    try context.save()
}

func seedLargeTrackedActivityInstallIfNeeded(
    context: ModelContext,
    now: Date = Date(),
    calendar: Calendar = .current
) throws {
    let existing = try context.fetch(FetchDescriptor<TrackedActivitySession>())

    if !existing.contains(where: { $0.id == PerformanceInstallSeed.heavyTrackedLiveSessionID }) {
        let startedAt = now.addingTimeInterval(-(64 * 60))
        let liveSession = TrackedActivitySession(
            id: PerformanceInstallSeed.heavyTrackedLiveSessionID,
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
                distanceMeters: 9_850,
                activeEnergyKilocalories: 610,
                stepCount: 12_100
            ),
            healthKitExportState: .notRequested,
            routePoints: makeInstallTrackedRoutePoints(
                startLatitude: 37.7749,
                startLongitude: -122.4194,
                count: 180,
                latitudeStep: 0.00015,
                longitudeStep: 0.00013
            ),
            notes: "DEBUG large tracked live session",
            lastResumedAt: startedAt
        )
        context.insert(liveSession)
    }

    if !existing.contains(where: { $0.id == PerformanceInstallSeed.heavyTrackedSummarySessionID }) {
        let startedAt = now.addingTimeInterval(-(4 * 60 * 60))
        let endedAt = startedAt.addingTimeInterval(96 * 60)
        let summarySession = TrackedActivitySession(
            id: PerformanceInstallSeed.heavyTrackedSummarySessionID,
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
                distanceMeters: 14_320,
                activeEnergyKilocalories: 890,
                stepCount: 19_400
            ),
            healthKitExportState: .exported,
            routePoints: makeInstallTrackedRoutePoints(
                startLatitude: 37.3317,
                startLongitude: -122.0301,
                count: 220,
                latitudeStep: 0.00010,
                longitudeStep: 0.00008
            ),
            notes: "DEBUG large tracked summary",
            healthKitExportAttemptedAt: endedAt,
            healthKitExportSucceededAt: endedAt,
            healthKitExportFailureMessage: nil,
            hasLocalChangesSinceHealthKitExport: false
        )
        context.insert(summarySession)
    }

    let historyCount = 16
    for index in 0..<historyCount {
        let note = "\(PerformanceInstallSeed.trackedHistoryNotePrefix) \(index + 1)"
        if existing.contains(where: { $0.notes == note }) {
            continue
        }

        let daysAgo = index + 2
        let startedAt = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let durationMinutes = 32 + (index % 6) * 9
        let endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let isExportFailed = index % 5 == 0
        let kind: TrackedActivityKind = index % 3 == 0 ? .hiking : (index % 2 == 0 ? .running : .walking)
        let distance = Double(3_200 + index * 650)
        let steps = 4_500 + index * 700
        let calories = Double(210 + index * 35)
        let routePointCount = 90 + index * 8

        let session = TrackedActivitySession(
            createdAt: startedAt,
            updatedAt: endedAt,
            startedAt: startedAt,
            endedAt: endedAt,
            activeIntervalStartedAt: nil,
            activityKind: kind,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(
                elapsedDuration: endedAt.timeIntervalSince(startedAt),
                distanceMeters: distance,
                activeEnergyKilocalories: calories,
                stepCount: steps
            ),
            healthKitExportState: isExportFailed ? .failed : .exported,
            routePoints: makeInstallTrackedRoutePoints(
                startLatitude: 19.4326 + (Double(index) * 0.001),
                startLongitude: -99.1332 - (Double(index) * 0.001),
                count: routePointCount,
                latitudeStep: 0.00006,
                longitudeStep: 0.00005
            ),
            notes: note,
            healthKitExportAttemptedAt: endedAt,
            healthKitExportSucceededAt: isExportFailed ? nil : endedAt,
            healthKitExportFailureMessage: isExportFailed ? "DEBUG large seed simulated Health export failure" : nil,
            hasLocalChangesSinceHealthKitExport: false
        )
        context.insert(session)
    }

    try context.save()
}

private func makeInstallTrackedRoutePoints(
    startLatitude: CLLocationDegrees,
    startLongitude: CLLocationDegrees,
    count: Int,
    latitudeStep: CLLocationDegrees,
    longitudeStep: CLLocationDegrees
) -> [TrackedActivityRoutePoint] {
    (0..<count).map { index in
        let wobble = Double(index % 7) * 0.00001
        let location = CLLocation(
            latitude: startLatitude + (Double(index) * latitudeStep) + wobble,
            longitude: startLongitude + (Double(index) * longitudeStep) - wobble
        )
        return TrackedActivityRoutePoint(location: location)
    }
}

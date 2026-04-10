import SwiftUI
import Combine
import SwiftData
import UIKit

struct UITestHostRootView: View {
    private let env = ProcessInfo.processInfo.environment
    private let cal = Calendar.current

    @State private var timelineJump: TimelineJump? = nil

    private struct TimelineJump: Identifiable {
        let id = UUID()
        let day: Date
    }

    var body: some View {
        NavigationStack {
            switch (env["UITESTS_START"] ?? "calendar").lowercased() {
            case "settings":
                SettingsScreen()
            case "activities":
                ActivitiesHomeView()
            case "tracked-session":
                TrackedActivitySessionScreen(sessionID: TrackedActivityUITestSeed.liveSessionID)
            case "tracked-session-heavy":
                TrackedActivitySessionScreen(sessionID: PerformanceUITestSeed.heavyTrackedLiveSessionID)
                    .accessibilityIdentifier("UITestHeavyTrackedSession.Screen")
            case "tracked-summary":
                TrackedActivityFinishSummaryView(sessionID: TrackedActivityUITestSeed.summarySessionID)
            case "tracked-summary-heavy":
                TrackedActivityFinishSummaryView(sessionID: PerformanceUITestSeed.heavyTrackedSummarySessionID)
                    .accessibilityIdentifier("UITestHeavyTrackedSummary.Screen")
            case "home":
                UITestHomeRouteLauncherView()
            case "progress":
                ProgressDashboardView()
            case "routines":
                RoutinesScreen()
            case "exercise-library":
                ExerciseLibraryScreen()
            case "exercise-picker":
                ExercisePickerSheet(onPick: { _ in })
            case "session":
                UITestStrengthSessionBootstrapView()
            case "session-heavy":
                UITestHeavyStrengthSessionBootstrapView()
            case "calendar", "":
                DayTimelineEntryScreen()
            default:
                DayTimelineEntryScreen()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("workouttracker.openTimelineForDate"))) { note in
            guard let date = note.object as? Date else { return }
            timelineJump = TimelineJump(day: cal.startOfDay(for: date))
        }
        .fullScreenCover(item: $timelineJump) { jump in
            NavigationStack {
                DayTimelineEntryScreen(initialDay: jump.day)
            }
        }
    }
}

private struct UITestStrengthSessionBootstrapView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var launchedSession: WorkoutSession?
    @State private var didBootstrap = false

    private let env = ProcessInfo.processInfo.environment

    var body: some View {
        Group {
            if let session = launchedSession {
                WorkoutSessionScreen(session: session)
            } else {
                ProgressView()
                    .accessibilityIdentifier("UITestSessionBootstrap.Progress")
                    .task {
                        bootstrapIfNeeded()
                    }
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        guard !routines.isEmpty else {
            fatalError(
                """
                UITESTS assertion failed: session route expected at least 1 WorkoutRoutine \
                after seeding. Ensure starter-pack routine seeding is enabled for UITestHost.
                """
            )
        }

        let wantsLinkedFlow = env["UITESTS_LINKED_FLOW"] == "1"

        let preferred = routines.sorted { lhs, rhs in
            let lhsIsPreferredLinked = wantsLinkedFlow && lhs.name == "UITest — Linked Main"
            let rhsIsPreferredLinked = wantsLinkedFlow && rhs.name == "UITest — Linked Main"
            if lhsIsPreferredLinked != rhsIsPreferredLinked { return lhsIsPreferredLinked }

            let lhsIsUITest = lhs.name == "UITest Routine"
            let rhsIsUITest = rhs.name == "UITest Routine"
            if lhsIsUITest != rhsIsUITest { return lhsIsUITest }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        guard let chosen = firstRoutineProducingEditableStrengthSession(from: preferred) else {
            fatalError(
                """
                UITESTS assertion failed: session route could not build a WorkoutSession \
                containing a strength-style editable set row (Reps/Weight fields).
                """
            )
        }

        if wantsLinkedFlow {
            guard chosen.routine.name == "UITest — Linked Main" else {
                fatalError("UITESTS assertion failed: linked-flow route expected UITest — Linked Main to be selected first.")
            }

            let segments: [WorkoutExerciseSegment] = chosen.session.exercises
                .sorted { $0.order < $1.order }
                .map(\.segment)

            guard segments == [.warmUp, .main, .coolDown] else {
                fatalError("UITESTS assertion failed: linked-flow route expected warm-up -> main -> cool-down session segments.")
            }
        }

        let session = chosen.session
        normalizeAnchorSetForUITests(in: session)

        let calendar = Calendar.current
        let start = Date()
        let end = calendar.date(byAdding: .minute, value: 60, to: start)

        let activity = Activity(
            title: chosen.routine.name,
            startAt: start,
            endAt: end,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: chosen.routine.id
        )
        activity.dayKey = start.dayKey()

        do {
            modelContext.insert(activity)
            modelContext.insert(session)
            activity.workoutSessionId = session.id
            try modelContext.save()

            let editableStrengthRows = session.exercises.reduce(0) { partial, exercise in
                partial + exercise.setLogs.filter { set in
                    !WorkoutSetRowRouting.shouldUseTimedRow(for: exercise, set: set)
                }.count
            }

            if editableStrengthRows == 0 {
                fatalError(
                    """
                    UITESTS assertion failed: session route bootstrapped a WorkoutSession \
                    with 0 editable strength rows.
                    """
                )
            }

            launchedSession = session
        } catch {
            fatalError("UITESTS session bootstrap failed: \(error)")
        }
    }

    @MainActor
    private func firstRoutineProducingEditableStrengthSession(
        from routines: [WorkoutRoutine]
    ) -> (routine: WorkoutRoutine, session: WorkoutSession)? {
        for routine in routines {
            let executionSegments = WorkoutRoutineMapper.toExecutionSegments(routine: routine)
            let templates = WorkoutRoutineMapper.toExerciseTemplates(executionSegments: executionSegments)
            let session = WorkoutSessionFactory.makeSession(
                linkedActivityId: nil,
                sourceRoutineId: routine.id,
                sourceRoutineNameSnapshot: routine.name,
                exercises: templates,
                prefillActualsFromTargets: true
            )

            let hasEditableStrengthRow = session.exercises.contains { exercise in
                exercise.setLogs.contains { set in
                    !WorkoutSetRowRouting.shouldUseTimedRow(for: exercise, set: set)
                }
            }

            if hasEditableStrengthRow {
                return (routine, session)
            }
        }

        return nil
    }

    @MainActor
    private func normalizeAnchorSetForUITests(in session: WorkoutSession) {
        guard let (exercise, set) = firstEditableStrengthAnchor(in: session) else {
            fatalError(
                """
                UITESTS assertion failed: session bootstrap could not find a non-timed \
                strength row to use as the UI-test anchor set.
                """
            )
        }

        let minExerciseOrder = session.exercises.map(\.order).min() ?? 0
        exercise.order = minExerciseOrder - 1

        let minSetOrder = exercise.setLogs.map(\.order).min() ?? 0
        set.order = minSetOrder - 1

        set.completed = false
        set.completedAt = nil
        set.reps = set.reps ?? set.targetReps ?? 5
        set.weightUnit = .kg
        if set.weight == nil || set.weight == 0 {
            set.weight = 100
        }

        if set.targetReps == nil {
            set.targetReps = set.reps
        }

        if env["UITESTS_REST_TIMER_SHORT"] == "1" {
            set.targetRestSeconds = 2
        } else if (set.targetRestSeconds ?? 0) <= 0 {
            set.targetRestSeconds = 60
        }
    }

    @MainActor
    private func firstEditableStrengthAnchor(
        in session: WorkoutSession
    ) -> (exercise: WorkoutSessionExercise, set: WorkoutSetLog)? {
        let orderedExercises = session.exercises.sorted { $0.order < $1.order }
        for exercise in orderedExercises {
            let orderedSets = exercise.setLogs.sorted { $0.order < $1.order }
            for set in orderedSets where !WorkoutSetRowRouting.shouldUseTimedRow(for: exercise, set: set) {
                return (exercise, set)
            }
        }
        return nil
    }
}

private struct UITestHeavyStrengthSessionBootstrapView: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @State private var launchedSession: WorkoutSession?
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if let session = launchedSession {
                WorkoutSessionScreen(session: session)
            } else {
                ProgressView()
                    .accessibilityIdentifier("UITestHeavySessionBootstrap.Progress")
                    .task {
                        bootstrapIfNeeded()
                    }
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        guard let session = sessions.first(where: { $0.sourceRoutineNameSnapshot == PerformanceUITestSeed.heavyStrengthSessionName }) else {
            fatalError(
                "UITESTS assertion failed: heavy session route expected a seeded WorkoutSession named \(PerformanceUITestSeed.heavyStrengthSessionName)."
            )
        }

        guard session.status == .inProgress, session.endedAt == nil else {
            fatalError("UITESTS assertion failed: heavy session route expected the seeded WorkoutSession to be in progress and not ended.")
        }

        let orderedExercises = session.exercises.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        guard orderedExercises.count >= 10 else {
            fatalError("UITESTS assertion failed: heavy session route expected at least 10 seeded exercise cards.")
        }

        let planner = SessionResumePlanner().target(for: session)
        guard let targetSetID = planner?.setID else {
            fatalError("UITESTS assertion failed: heavy session route expected SessionResumePlanner to resolve a target set.")
        }

        var targetExerciseIndex: Int?
        var precedingSetCount = 0
        for (index, exercise) in orderedExercises.enumerated() {
            let sets = exercise.setLogs.sorted { lhs, rhs in
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            if sets.contains(where: { $0.id == targetSetID }) {
                targetExerciseIndex = index
                break
            }
            precedingSetCount += sets.count
        }

        guard let resolvedTargetExerciseIndex = targetExerciseIndex else {
            fatalError("UITESTS assertion failed: heavy session route expected the planner target to belong to the seeded WorkoutSession.")
        }

        guard resolvedTargetExerciseIndex > 0 else {
            fatalError("UITESTS assertion failed: heavy session route expected the planner target to belong to a later exercise card.")
        }

        guard precedingSetCount >= 8 else {
            fatalError("UITESTS assertion failed: heavy session route expected at least 8 set rows before the planner target.")
        }

        launchedSession = session
    }
}

private struct UITestHomeRouteLauncherView: View {
    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    private let env = ProcessInfo.processInfo.environment

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppRootView()

            if env["UITESTS_DEEP_LINK_SMOKE"] == "1",
               let url = deepLinkURLIfReady() {
                Button("Open deep-link smoke route") {
                    NotificationCenter.default.post(
                        name: Notification.Name("workouttracker.openURLForTesting"),
                        object: url
                    )
                }
                .accessibilityIdentifier("UITestHomeRouteLauncher.OpenDeepLink")
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
    }

    @MainActor
    private func deepLinkURLIfReady() -> URL? {
        guard let session = sessions.first(where: { $0.sourceRoutineNameSnapshot == "UITest — Active Scroll" }) else {
            return nil
        }

        guard session.status == .inProgress, session.endedAt == nil else {
            fatalError(
                "UITESTS assertion failed: Deep-link smoke route expected 'UITest — Active Scroll' to be in-progress and not ended."
            )
        }

        let orderedExercises = session.exercises.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }

        var precedingSetCount = 0
        var targetExercise: WorkoutSessionExercise?

        for (index, exercise) in orderedExercises.enumerated() {
            let orderedSets = exercise.setLogs.sorted {
                if $0.order != $1.order { return $0.order < $1.order }
                return $0.id.uuidString < $1.id.uuidString
            }

            defer { precedingSetCount += orderedSets.count }

            guard !orderedSets.isEmpty else { continue }

            let hasIncompleteSet = orderedSets.contains(where: { !$0.completed })
            if index > 0 && precedingSetCount >= 4 && hasIncompleteSet {
                targetExercise = exercise
                break
            }
        }

        guard let targetExercise else {
            fatalError(
                """
                UITESTS assertion failed: Deep-link smoke route expected a later exercise card \
                with at least 4 preceding set rows and at least 1 incomplete set.
                """
            )
        }

        return URL(
            string: "workouttracker://session/\(session.id.uuidString)/exercise/\(targetExercise.id.uuidString)"
        )
    }
}

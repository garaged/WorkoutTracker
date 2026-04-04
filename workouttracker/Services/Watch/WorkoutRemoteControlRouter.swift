// File: workouttracker/Services/Watch/WorkoutRemoteControlRouter.swift

import Foundation
import SwiftData
import Combine

@MainActor
final class WorkoutRemoteControlRouter {
    
    static let shared = WorkoutRemoteControlRouter()
    
    private var container: ModelContainer? = nil
    private let logging = WorkoutLoggingService()
    private let restTimer = RestTimerController.shared
    private let sessionResumePlanner = SessionResumePlanner()
    private let trackedActivityRecorder = TrackedActivityRecorder()
    
    private struct Cursor {
        var exerciseID: UUID?
        var setID: UUID?
    }
    
    // “Pinned” strength session: set by the UI when the user is in the workout screen.
    // This remains the most reliable signal for strength remote control.
    private var pinnedSessionID: UUID? = nil
    // Pinned tracked-activity session: set by watch-started activities or the phone activity screen.
    private var pinnedTrackedActivitySessionID: UUID? = nil
    
    private var cursorBySessionID: [UUID: Cursor] = [:]
    private var cancellables: Set<AnyCancellable> = []
    
    private init() {}
    
    func start(modelContainer: ModelContainer) {
        guard container == nil else { return } // idempotent
        container = modelContainer
        
        WatchConnectivityService.shared.start()
        WatchConnectivityService.shared.onCommand = { [weak self] cmd in
            self?.handle(cmd)
        }
        
        // Push updates when rest timer changes (for watch UI).
        restTimer.$remainingSeconds
            .sink { [weak self] _ in self?.pushNowPlayingIfNeeded() }
            .store(in: &cancellables)
        
        restTimer.$isRunning
            .sink { [weak self] _ in self?.pushNowPlayingIfNeeded() }
            .store(in: &cancellables)
        
        // Heartbeat: keeps watch state fresh even if UI didn’t call updateCursor yet.
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pushNowPlayingIfNeeded()
            }
            .store(in: &cancellables)
        
        pushNowPlayingIfNeeded()
    }
    
    /// Called by the phone UI (WorkoutSessionScreen) whenever the user is inside a workout.
    func updateCursor(sessionID: UUID, exerciseID: UUID?, setID: UUID?) {
        pinnedTrackedActivitySessionID = nil
        pinnedSessionID = sessionID
        cursorBySessionID[sessionID] = Cursor(exerciseID: exerciseID, setID: setID)
        pushNowPlayingIfNeeded()
    }
    
    /// Call when workout ends or user leaves the workout screen.
    func clearNowPlaying(sessionID: UUID) {
        if pinnedSessionID == sessionID { pinnedSessionID = nil }
        pushNowPlayingIfNeeded()
    }

    func focusTrackedActivity(sessionID: UUID) {
        pinnedSessionID = nil
        pinnedTrackedActivitySessionID = sessionID
        pushNowPlayingIfNeeded()
    }

    func clearTrackedActivityFocus(sessionID: UUID) {
        if pinnedTrackedActivitySessionID == sessionID {
            pinnedTrackedActivitySessionID = nil
        }
        pushNowPlayingIfNeeded()
    }

    func refreshNowPlaying() {
        pushNowPlayingIfNeeded()
    }
    
    // MARK: - Command handling
    
    private func handle(_ cmd: WatchCommand) {
        guard let container else { return }
        let context = ModelContext(container)

        switch cmd.kind {
        case .requestState:
            pushNowPlayingIfNeeded()
            return

        case .startRoutine:
            handleStartRoutine(cmd, context: context)
            return

        case .startTrackedActivity:
            handleStartTrackedActivity(cmd, context: context)
            return

        case .resumeCurrentTrackedActivity:
            handleTrackedActivityQuickEntry(cmd, context: context)
            return

        case .pauseTrackedActivity, .resumeTrackedActivity, .finishTrackedActivity:
            handleTrackedActivityLifecycle(cmd, context: context)
            return

        case .openCurrentSession, .resumeCurrentSession:
            handleQuickEntry(cmd, context: context)
            return

        case .toggleRestTimer, .markSetComplete, .nextSet, .previousSet:
            break
        }

        // Prefer pinned session. If command includes a sessionID, use it.
        guard let session = resolveSession(for: cmd, context: context) else {
            pushNowPlayingIfNeeded()
            return
        }

        // Accept commands if either:
        // - The session is actually in progress, OR
        // - It’s pinned by the UI (user is in workout screen).
        if !(session.status == .inProgress || pinnedSessionID == session.id) {
            pushNowPlayingIfNeeded()
            return
        }

        ensureCursorExists(for: session)

        let beforeSetID = cursorBySessionID[session.id]?.setID

        switch cmd.kind {
        case .toggleRestTimer:
            restTimer.toggle(defaultSeconds: defaultRestSeconds(for: session))

        case .markSetComplete:
            if let sid = cmd.setID, let setUUID = UUID(uuidString: sid) {
                setCursor(to: setUUID, in: session)
            }
            markCurrentSetComplete(in: session, context: context)

        case .nextSet:
            moveCursor(in: session, delta: +1)

        case .previousSet:
            moveCursor(in: session, delta: -1)

        case .requestState, .openCurrentSession, .resumeCurrentSession, .startRoutine,
             .startTrackedActivity, .resumeCurrentTrackedActivity,
             .pauseTrackedActivity, .resumeTrackedActivity, .finishTrackedActivity:
            break
        }

        syncLiveActivity(context: context)

        let afterSetID = cursorBySessionID[session.id]?.setID
        if beforeSetID != afterSetID {
            postSelectedSetEvent(sessionID: session.id)
        }

        pushNowPlaying(for: session)
    }
    
    // MARK: - Session resolution
    
    private func resolveSession(for cmd: WatchCommand, context: ModelContext) -> WorkoutSession? {
        if let sid = cmd.sessionID,
           let uuid = UUID(uuidString: sid),
           let session = fetchSession(id: uuid, context: context) {
            return session
        }

        if let pinned = resolvedPinnedSession(context: context) {
            return pinned
        }

        return preferredActiveSession(context: context)
    }

    private func resolveQuickEntrySession(for cmd: WatchCommand, context: ModelContext) -> WorkoutSession? {
        if let sid = cmd.sessionID,
           let uuid = UUID(uuidString: sid),
           let session = fetchSession(id: uuid, context: context),
           isLaunchable(session) {
            return session
        }

        if let pinned = resolvedPinnedSession(context: context),
           isLaunchable(pinned) {
            return pinned
        }

        return preferredActiveSession(context: context)
    }
    
    private func fetchSessionsSorted(context: ModelContext) -> [WorkoutSession] {
        let fd = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )
        return (try? context.fetch(fd)) ?? []
    }
    
    private func fetchSession(id: UUID, context: ModelContext) -> WorkoutSession? {
        // Avoid SwiftData predicate macro edge cases: just fetch sorted and filter.
        let sessions = fetchSessionsSorted(context: context)
        return sessions.first(where: { $0.id == id })
    }

    private func fetchTrackedActivitySessionsSorted(context: ModelContext) -> [TrackedActivitySession] {
        let fd = FetchDescriptor<TrackedActivitySession>(
            sortBy: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(fd)) ?? []
    }

    private func fetchTrackedActivitySession(id: UUID, context: ModelContext) -> TrackedActivitySession? {
        let sessions = fetchTrackedActivitySessionsSorted(context: context)
        return sessions.first(where: { $0.id == id })
    }


    private func fetchActivitiesByID(context: ModelContext) -> [UUID: Activity] {
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        return Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    private func resolvedPinnedSession(context: ModelContext) -> WorkoutSession? {
        guard let pinnedSessionID else { return nil }
        guard let session = fetchSession(id: pinnedSessionID, context: context) else {
            cursorBySessionID.removeValue(forKey: pinnedSessionID)
            self.pinnedSessionID = nil
            return nil
        }
        return session
    }

    private func resolvedPinnedTrackedActivitySession(context: ModelContext) -> TrackedActivitySession? {
        guard let pinnedTrackedActivitySessionID else { return nil }
        guard let session = fetchTrackedActivitySession(id: pinnedTrackedActivitySessionID, context: context) else {
            self.pinnedTrackedActivitySessionID = nil
            return nil
        }
        return session
    }

    private func preferredActiveTrackedActivitySession(context: ModelContext) -> TrackedActivitySession? {
        fetchTrackedActivitySessionsSorted(context: context)
            .first(where: { $0.lifecycleState == .inProgress || $0.lifecycleState == .paused })
    }

    private func preferredActiveSession(context: ModelContext) -> WorkoutSession? {
        sessionResumePlanner.currentActiveSession(
            from: fetchSessionsSorted(context: context),
            activitiesByID: fetchActivitiesByID(context: context)
        )
    }

    private func isLaunchable(_ session: WorkoutSession) -> Bool {
        session.status == .inProgress && session.endedAt == nil
    }
    
    // MARK: - Cursor + navigation
    
    private func ensureCursorExists(for session: WorkoutSession) {
        var cursor = cursorBySessionID[session.id] ?? Cursor(exerciseID: nil, setID: nil)
        
        if let setID = cursor.setID, findSet(in: session, setID: setID) != nil {
            cursorBySessionID[session.id] = cursor
            return
        }
        
        if let first = orderedSets(in: session).first(where: { !$0.set.completed }) ?? orderedSets(in: session).first {
            cursor.exerciseID = first.exercise.id
            cursor.setID = first.set.id
            cursorBySessionID[session.id] = cursor
        }
    }
    
    private func setCursor(to setID: UUID, in session: WorkoutSession) {
        if let pair = findSet(in: session, setID: setID) {
            cursorBySessionID[session.id] = Cursor(exerciseID: pair.exercise.id, setID: pair.set.id)
        }
    }
    
    private func moveCursor(in session: WorkoutSession, delta: Int) {
        let ordered = orderedSets(in: session)
        guard !ordered.isEmpty else { return }
        
        let cursor = cursorBySessionID[session.id]
        let currentID = cursor?.setID ?? ordered.first!.set.id
        
        guard let idx = ordered.firstIndex(where: { $0.set.id == currentID }) else { return }
        
        let newIdx = max(0, min(ordered.count - 1, idx + delta))
        let target = ordered[newIdx]
        cursorBySessionID[session.id] = Cursor(exerciseID: target.exercise.id, setID: target.set.id)
    }
    
    private func orderedSets(in session: WorkoutSession) -> [(exercise: WorkoutSessionExercise, set: WorkoutSetLog)] {
        let exercises = session.exercises.sorted { $0.order < $1.order }
        return exercises.flatMap { ex in
            ex.setLogs.sorted { $0.order < $1.order }.map { (exercise: ex, set: $0) }
        }
    }
    
    private func findSet(in session: WorkoutSession, setID: UUID) -> (exercise: WorkoutSessionExercise, set: WorkoutSetLog)? {
        for ex in session.exercises {
            if let s = ex.setLogs.first(where: { $0.id == setID }) {
                return (ex, s)
            }
        }
        return nil
    }
    
    // MARK: - Actions
    
    private func markCurrentSetComplete(in session: WorkoutSession, context: ModelContext) {
        ensureCursorExists(for: session)
        guard let setID = cursorBySessionID[session.id]?.setID,
              let pair = findSet(in: session, setID: setID)
        else { return }
        
        let wasCompleted = pair.set.completed
        logging.toggleCompleted(pair.set, context: context)
        
        do { try context.save() } catch { /* non-fatal */ }
        
        if !wasCompleted, pair.set.completed {
            let rest = max(1, pair.set.targetRestSeconds ?? 90)
            restTimer.start(seconds: rest)
            moveCursor(in: session, delta: +1)
        }
        postCompletionChanged(sessionID: session.id, setID: pair.set.id, isCompleted: pair.set.completed)
    }
    
    private func defaultRestSeconds(for session: WorkoutSession) -> Int {
        ensureCursorExists(for: session)
        if let setID = cursorBySessionID[session.id]?.setID,
           let pair = findSet(in: session, setID: setID),
           let t = pair.set.targetRestSeconds {
            return max(1, t)
        }
        return 90
    }
    
    private func syncLiveActivity(context: ModelContext) {
        guard #available(iOS 16.1, *) else { return }

        let snapshot = CurrentSessionSnapshotBuilder().buildWidgetSnapshot(context: context)

        Task { @MainActor in
            await LiveActivityCoordinator().sync(using: snapshot)
        }
    }

    // MARK: - Watch state pushing
    
    private func pushNowPlayingIfNeeded() {
        guard let container else { return }
        let context = ModelContext(container)

        if let trackedSession = resolvedPinnedTrackedActivitySession(context: context),
           trackedSession.lifecycleState == .inProgress || trackedSession.lifecycleState == .paused {
            pushNowPlaying(for: trackedSession, context: context)
            return
        }

        if let session = resolvedPinnedSession(context: context) {
            if isLaunchable(session) || pinnedSessionID == session.id {
                ensureCursorExists(for: session)
                pushNowPlaying(for: session, context: context)
                return
            }
        }

        if let strengthSession = preferredActiveSession(context: context) {
            ensureCursorExists(for: strengthSession)
            pushNowPlaying(for: strengthSession, context: context)
            return
        }

        if let trackedSession = preferredActiveTrackedActivitySession(context: context) {
            pushNowPlaying(for: trackedSession, context: context)
            return
        }

        WatchConnectivityService.shared.pushNowPlayingState(makeInactiveState(context: context))
    }
    
    private func pushNowPlaying(for session: WorkoutSession, context: ModelContext? = nil) {
        WatchConnectivityService.shared.pushNowPlayingState(makeWatchState(for: session, context: context))
    }

    private func pushNowPlaying(for session: TrackedActivitySession, context: ModelContext? = nil) {
        WatchConnectivityService.shared.pushNowPlayingState(makeWatchState(for: session, context: context))
    }

    private func makeInactiveState(context: ModelContext) -> WatchNowPlayingState {
        var inactive = WatchNowPlayingState.inactive
        inactive.quickStartRoutines = quickStartRoutines(context: context)
        return inactive
    }

    private func quickStartRoutines(context: ModelContext) -> [WatchRoutineSummary] {
        let routines = (try? context.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []
        return routines
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(5)
            .map { WatchRoutineSummary(id: $0.id.uuidString, name: $0.name) }
    }
    
    private func makeWatchState(for session: WorkoutSession, context: ModelContext? = nil) -> WatchNowPlayingState {
        ensureCursorExists(for: session)
        
        let ordered = orderedSets(in: session)
        guard !ordered.isEmpty else {
            return WatchNowPlayingState(
                presentationKind: .strengthSession,
                isActiveSession: true,
                exerciseName: session.sourceRoutineNameSnapshot ?? "Workout",
                setTitle: nil,
                setDetail: nil,
                isRestRunning: restTimer.isRunning,
                restRemainingSeconds: restTimer.isRunning ? restTimer.remainingSeconds : nil,
                restEndsAtEpochSeconds: restTimer.activeEndDate?.timeIntervalSince1970,
                canGoPrevious: false,
                canGoNext: false,
                isPaused: false,
                canPauseOrResume: false,
                canFinish: false,
                elapsedSeconds: nil,
                elapsedUpdatedAtEpochSeconds: nil,
                sessionID: session.id.uuidString,
                setID: nil,
                quickStartRoutines: context.map(quickStartRoutines(context:)) ?? []
            )
        }
        
        let cursorSetID = cursorBySessionID[session.id]?.setID ?? ordered.first!.set.id
        let idx = ordered.firstIndex(where: { $0.set.id == cursorSetID }) ?? 0
        let pair = ordered[idx]
        
        let setsInExercise = pair.exercise.setLogs.sorted { $0.order < $1.order }
        let setNum = pair.set.order + 1
        let total = max(1, setsInExercise.count)
        
        let detail = formatSetDetail(pair.set)
        
        return WatchNowPlayingState(
            presentationKind: .strengthSession,
            isActiveSession: true,
            exerciseName: pair.exercise.exerciseNameSnapshot,
            setTitle: "Set \(setNum) of \(total)",
            setDetail: detail,
            isRestRunning: restTimer.isRunning,
            restRemainingSeconds: restTimer.isRunning ? restTimer.remainingSeconds : nil,
            restEndsAtEpochSeconds: restTimer.activeEndDate?.timeIntervalSince1970,
            canGoPrevious: idx > 0,
            canGoNext: idx < ordered.count - 1,
            isPaused: false,
            canPauseOrResume: false,
            canFinish: false,
            elapsedSeconds: nil,
            elapsedUpdatedAtEpochSeconds: nil,
            sessionID: session.id.uuidString,
            setID: pair.set.id.uuidString,
            quickStartRoutines: context.map(quickStartRoutines(context:)) ?? []
        )
    }
    
    private func makeWatchState(for session: TrackedActivitySession, context: ModelContext? = nil) -> WatchNowPlayingState {
        let liveTotals = trackedActivityRecorder.liveTotals(for: session)
        let elapsedSeconds = Int(liveTotals.elapsedDuration.rounded(.down))
        let environmentTitle = session.environment == .unspecified ? nil : session.environment.displayName
        let detail = session.notes?.trimmingCharacters(in: .whitespacesAndNewlines)

        return WatchNowPlayingState(
            presentationKind: .trackedActivity,
            isActiveSession: session.lifecycleState == .inProgress || session.lifecycleState == .paused,
            exerciseName: session.activityKind.displayName,
            setTitle: environmentTitle,
            setDetail: detail?.isEmpty == false ? detail : nil,
            isRestRunning: false,
            restRemainingSeconds: nil,
            restEndsAtEpochSeconds: nil,
            canGoPrevious: false,
            canGoNext: false,
            isPaused: session.lifecycleState == .paused,
            canPauseOrResume: session.lifecycleState == .inProgress || session.lifecycleState == .paused,
            canFinish: session.lifecycleState == .inProgress || session.lifecycleState == .paused,
            elapsedSeconds: elapsedSeconds,
            elapsedUpdatedAtEpochSeconds: Date().timeIntervalSince1970,
            sessionID: session.id.uuidString,
            setID: nil,
            quickStartRoutines: context.map(quickStartRoutines(context:)) ?? []
        )
    }

    private func formatSetDetail(_ set: WorkoutSetLog) -> String {
        if set.actualDurationSeconds != nil || set.targetDurationSeconds != nil || set.actualDistance != nil || set.targetDistance != nil {
            var parts: [String] = []
            if let secs = set.actualDurationSeconds ?? set.targetDurationSeconds {
                let m = secs / 60
                let s = secs % 60
                parts.append(String(format: "%d:%02d", m, s))
            }
            if let dist = set.actualDistance ?? set.targetDistance {
                parts.append(String(format: "%.2f", dist))
            }
            return parts.isEmpty ? "Timed set" : parts.joined(separator: " • ")
        }
        
        let reps = set.reps.map(String.init) ?? "—"
        let weight = set.weight.map(formatWeight) ?? "—"
        return "\(reps) reps @ \(weight) \(set.weightUnit.rawValue)"
    }
    
    private func formatWeight(_ w: Double) -> String {
        if abs(w.rounded() - w) < 0.0001 { return String(format: "%.0f", w) }
        return String(format: "%.1f", w)
    }
    
    private func stagePhoneOpen(route: AppRoute) {
        IntentLaunchBridge.stage(route: route)
        NotificationCenter.default.post(
            name: .workoutWatchOpenRequested,
            object: WorkoutWatchOpenRequestedEvent(route: route)
        )
    }

    private func quickEntryRoute(for session: WorkoutSession, command: WatchCommandKind) -> AppRoute {
        switch command {
        case .resumeCurrentSession:
            return sessionResumePlanner.resumeRoute(
                for: session,
                hasConfiguredRestTimer: restTimer.isRunning
            ) ?? sessionResumePlanner.openRoute(for: session)
        case .openCurrentSession:
            return sessionResumePlanner.openRoute(for: session)
        default:
            return sessionResumePlanner.openRoute(for: session)
        }
    }

    // MARK: - Phone UI sync (events)

    private func postSelectedSetEvent(sessionID: UUID) {
        let cur = cursorBySessionID[sessionID]
        NotificationCenter.default.post(
            name: .workoutWatchSelectedSet,
            object: WorkoutWatchSelectedSetEvent(
                sessionID: sessionID,
                exerciseID: cur?.exerciseID,
                setID: cur?.setID
            )
        )
    }

    private func postCompletionChanged(sessionID: UUID, setID: UUID, isCompleted: Bool) {
        NotificationCenter.default.post(
            name: .workoutWatchSetCompletionChanged,
            object: WorkoutWatchSetCompletionChangedEvent(
                sessionID: sessionID,
                setID: setID,
                isCompleted: isCompleted
            )
        )
    }
}


extension WorkoutRemoteControlRouter {
    private func handleQuickEntry(_ cmd: WatchCommand, context: ModelContext) {
        guard let session = resolveQuickEntrySession(for: cmd, context: context) else {
            WatchConnectivityService.shared.pushNowPlayingState(makeInactiveState(context: context))
            return
        }

        pinnedSessionID = session.id
        ensureCursorExists(for: session)

        if cmd.kind == .resumeCurrentSession {
            try? WorkoutSessionStarter.resumeForActiveLogging(session, context: context)
        }

        let route = quickEntryRoute(for: session, command: cmd.kind)
        stagePhoneOpen(route: route)

        syncLiveActivity(context: context)
        pushNowPlaying(for: session, context: context)
    }

    private func handleStartRoutine(_ cmd: WatchCommand, context: ModelContext) {
        guard let routineIDString = cmd.routineID,
              let routineID = UUID(uuidString: routineIDString) else {
            WatchConnectivityService.shared.pushNowPlayingState(makeInactiveState(context: context))
            return
        }

        let outcome = try? IntentActionCoordinator().startRoutine(routineID: routineID, context: context)

        guard case .opened(let route)? = outcome,
              let sessionID = route.sessionID,
              let session = fetchSession(id: sessionID, context: context) else {
            WatchConnectivityService.shared.pushNowPlayingState(makeInactiveState(context: context))
            return
        }

        pinnedTrackedActivitySessionID = nil
        pinnedSessionID = session.id
        ensureCursorExists(for: session)
        stagePhoneOpen(route: route)
        syncLiveActivity(context: context)
        pushNowPlaying(for: session, context: context)
    }

    private func handleStartTrackedActivity(_ cmd: WatchCommand, context: ModelContext) {
        let kind = TrackedActivityKind(rawValue: cmd.trackedActivityKindRaw ?? "") ?? .walking
        let environment = ActivityEnvironment(rawValue: cmd.activityEnvironmentRaw ?? "") ?? kind.defaultEnvironment

        guard let session = try? trackedActivityRecorder.createSession(
            activityKind: kind,
            environment: environment,
            notes: nil,
            context: context
        ) else {
            WatchConnectivityService.shared.pushNowPlayingState(makeInactiveState(context: context))
            return
        }

        pinnedSessionID = nil
        pinnedTrackedActivitySessionID = session.id
        pushNowPlaying(for: session, context: context)
    }

    private func handleTrackedActivityQuickEntry(_ cmd: WatchCommand, context: ModelContext) {
        guard let session = resolveTrackedActivitySession(for: cmd, context: context) else {
            pushNowPlayingIfNeeded()
            return
        }

        if session.lifecycleState == .paused || session.lifecycleState == .planned {
            try? trackedActivityRecorder.resume(session, context: context)
        }

        pinnedSessionID = nil
        pinnedTrackedActivitySessionID = session.id
        pushNowPlaying(for: session, context: context)
    }

    private func handleTrackedActivityLifecycle(_ cmd: WatchCommand, context: ModelContext) {
        guard let session = resolveTrackedActivitySession(for: cmd, context: context) else {
            pushNowPlayingIfNeeded()
            return
        }

        switch cmd.kind {
        case .pauseTrackedActivity:
            try? trackedActivityRecorder.pause(session, context: context)
            pinnedTrackedActivitySessionID = session.id
            pushNowPlaying(for: session, context: context)

        case .resumeTrackedActivity:
            try? trackedActivityRecorder.resume(session, context: context)
            pinnedTrackedActivitySessionID = session.id
            pushNowPlaying(for: session, context: context)

        case .finishTrackedActivity:
            try? trackedActivityRecorder.complete(session, context: context)
            if pinnedTrackedActivitySessionID == session.id {
                pinnedTrackedActivitySessionID = nil
            }
            pushNowPlayingIfNeeded()

        case .requestState, .toggleRestTimer, .markSetComplete, .nextSet, .previousSet,
             .openCurrentSession, .resumeCurrentSession, .startRoutine,
             .startTrackedActivity, .resumeCurrentTrackedActivity:
            break
        }
    }

    private func resolveTrackedActivitySession(for cmd: WatchCommand, context: ModelContext) -> TrackedActivitySession? {
        if let sid = cmd.sessionID,
           let uuid = UUID(uuidString: sid),
           let session = fetchTrackedActivitySession(id: uuid, context: context),
           session.lifecycleState == .inProgress || session.lifecycleState == .paused {
            return session
        }

        if let pinned = resolvedPinnedTrackedActivitySession(context: context),
           pinned.lifecycleState == .inProgress || pinned.lifecycleState == .paused {
            return pinned
        }

        return preferredActiveTrackedActivitySession(context: context)
    }
}

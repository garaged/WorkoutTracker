import Foundation

struct WorkoutWidgetSnapshot: Codable, Equatable {
    struct ActiveSession: Codable, Equatable {
        enum RestState: String, Codable, Equatable {
            case inactive
            case running
            case overdue
        }

        let sessionID: UUID
        let title: String?
        let currentExerciseName: String?
        let currentSetIndex: Int?
        let totalSets: Int?
        let elapsedSeconds: Int
        let restState: RestState
        let restSeconds: Int?
        let isResumable: Bool
        let isFinishable: Bool
        let openRouteURL: String?
        let resumeRouteURL: String?
        let restRouteURL: String?
    }

    struct Streak: Codable, Equatable {
        let currentStreakDays: Int
        let longestStreakDays: Int
        let workoutsThisWeek: Int
    }

    let generatedAt: Date
    let activeSession: ActiveSession?
    let streak: Streak
    let schemaVersion: Int
}

enum WidgetSharedSnapshotReader {
    static let appGroupIdentifier = "group.garaged.org.workouttracker"
    static let snapshotFileName = "widget_snapshot.json"

    static func load() -> WorkoutWidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Widgets", isDirectory: true)
            .appendingPathComponent(snapshotFileName),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? decoder.decode(WorkoutWidgetSnapshot.self, from: data)
    }
}

struct ActiveSessionWidgetViewModel: Equatable {
    let title: String
    let subtitle: String
    let accessoryText: String?
    let footnote: String?
    let url: URL
    let hasSession: Bool
}

struct StreakWidgetViewModel: Equatable {
    let title: String
    let currentStreakText: String
    let longestStreakText: String
    let workoutsThisWeekText: String
    let url: URL
}

enum WidgetSnapshotAdapters {
    static func activeSessionModel(from snapshot: WorkoutWidgetSnapshot?) -> ActiveSessionWidgetViewModel {
        guard let session = snapshot?.activeSession else {
            return emptySessionModel()
        }

        let preferredURL = WidgetDeepLinks.preferredURL(for: session)

        let subtitle: String
        if let exercise = session.currentExerciseName, !exercise.isEmpty {
            subtitle = exercise
        } else if session.isResumable {
            subtitle = "Resume your workout"
        } else {
            subtitle = "Open current workout"
        }

        let accessoryText: String?
        if let currentSetIndex = session.currentSetIndex,
           let totalSets = session.totalSets,
           totalSets > 0 {
            accessoryText = "Set \(currentSetIndex)/\(totalSets)"
        } else {
            accessoryText = nil
        }

        let footnote: String?
        if let restSeconds = session.restSeconds {
            let prefix = session.restState == .overdue ? "Rest overdue" : "Rest"
            footnote = "\(prefix): \(formattedDuration(seconds: restSeconds))"
        } else {
            footnote = "Elapsed: \(formattedElapsed(seconds: session.elapsedSeconds))"
        }

        return ActiveSessionWidgetViewModel(
            title: session.title ?? "Active Session",
            subtitle: subtitle,
            accessoryText: accessoryText,
            footnote: footnote,
            url: preferredURL,
            hasSession: true
        )
    }

    static func streakModel(from snapshot: WorkoutWidgetSnapshot?) -> StreakWidgetViewModel {
        let streak = snapshot?.streak ?? .init(currentStreakDays: 0, longestStreakDays: 0, workoutsThisWeek: 0)
        return StreakWidgetViewModel(
            title: "Consistency",
            currentStreakText: "Current streak: \(streak.currentStreakDays) day\(streak.currentStreakDays == 1 ? "" : "s")",
            longestStreakText: "Best: \(streak.longestStreakDays) day\(streak.longestStreakDays == 1 ? "" : "s")",
            workoutsThisWeekText: "This week: \(streak.workoutsThisWeek) workout\(streak.workoutsThisWeek == 1 ? "" : "s")",
            url: WidgetDeepLinks.streakURL()
        )
    }

    private static func emptySessionModel() -> ActiveSessionWidgetViewModel {
        ActiveSessionWidgetViewModel(
            title: "No Active Session",
            subtitle: "Start a routine to see live progress here.",
            accessoryText: nil,
            footnote: "Open WorkoutTracker",
            url: WidgetDeepLinks.preferredURL(for: nil),
            hasSession: false
        )
    }

    private static func unavailableSessionModel() -> ActiveSessionWidgetViewModel {
        ActiveSessionWidgetViewModel(
            title: "Session Unavailable",
            subtitle: "Open WorkoutTracker to refresh your current session.",
            accessoryText: nil,
            footnote: "Open WorkoutTracker",
            url: WidgetDeepLinks.preferredURL(for: nil),
            hasSession: false
        )
    }

    private static func formattedElapsed(seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(max(0, seconds))) ?? "0m"
    }

    private static func formattedDuration(seconds: Int) -> String {
        let absolute = abs(seconds)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = absolute >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        let base = formatter.string(from: TimeInterval(absolute)) ?? "0s"
        return seconds < 0 ? "-\(base)" : base
    }
}

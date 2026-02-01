// workouttracker/Services/Workouts/WorkoutHistoryFiltering.swift
import Foundation

enum WorkoutHistoryFiltering {

    static func filteredSessions(
        sessions: [WorkoutSession],
        completedOnly: Bool,
        routineFilterName: String?,
        exerciseFilterId: UUID?,
        allowExerciseFilter: Bool,
        searchText: String
    ) -> [WorkoutSession] {
        var out = sessions

        if completedOnly {
            out = out.filter { $0.status == .completed }
        }

        if let routineFilterName {
            out = out.filter { ($0.sourceRoutineNameSnapshot ?? "Quick Workout") == routineFilterName }
        }

        if allowExerciseFilter, let exId = exerciseFilterId {
            out = out.filter { s in
                s.exercises.contains(where: { $0.exerciseId == exId })
            }
        }

        let q = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !q.isEmpty else { return out }

        return out.filter { s in
            let routine = (s.sourceRoutineNameSnapshot ?? "Quick Workout").lowercased()
            if routine.contains(q) { return true }
            return s.exercises.contains(where: { $0.exerciseNameSnapshot.lowercased().contains(q) })
        }
    }

    static func groupedDays(
        calendar: Calendar,
        sessions: [WorkoutSession]
    ) -> [(day: Date, sessions: [WorkoutSession])] {
        let dict = Dictionary(grouping: sessions) { s in
            calendar.startOfDay(for: s.startedAt)
        }

        return dict
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.day > $1.day }
    }
}

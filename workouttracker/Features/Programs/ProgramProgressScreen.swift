import SwiftUI
import SwiftData

struct ProgramProgressScreen: View {
    let program: TrainingProgram
    let assignmentID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openTimelineForDate) private var openTimelineForDate

    @State private var assignment: ProgramAssignment?
    @State private var availableRoutineSlugs: Set<String> = []

    var body: some View {
        Group {
            if let assignment {
                content(for: assignment)
            } else {
                ContentUnavailableView(
                    String(localized: "Program Progress Unavailable", defaultValue: "Program Progress Unavailable"),
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text(String(localized: "This assignment could not be loaded.", defaultValue: "This assignment could not be loaded."))
                )
            }
        }
        .navigationTitle(String(localized: "Program Progress", defaultValue: "Program Progress"))
        .accessibilityIdentifier("Programs.Progress.Screen")
        .task {
            loadAssignment()
            loadRoutineAvailability()
        }
    }

    @ViewBuilder
    private func content(for assignment: ProgramAssignment) -> some View {
        let now = Date()
        let adherence = ProgramAdherenceService.summary(for: assignment, program: program, now: now)
        let position = adherence.position
        let plannedDays = ProgramPlanner.plannedDays(
            for: assignment,
            program: program,
            weekIndex: position.currentWeekIndex,
            now: now
        )
        let nextActionable = ProgramPlanner.nextActionableDay(for: assignment, program: program, now: now)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                progressHeader(position: position)

                WeekProgressCard(
                    weekTitle: currentWeekTitle(weekIndex: position.currentWeekIndex),
                    completion: adherence.currentWeekCompletion
                )

                NextRecommendedActionCard(
                    recommendation: adherence.recommendation,
                    nextActionable: nextActionable,
                    onOpenCalendar: nextActionable.map { plannedDay in
                        { openTimelineForDate(plannedDay.scheduledDate) }
                    }
                )
                .accessibilityIdentifier("Programs.Progress.NextAction")

                if adherence.outstandingMissedDays > 0 {
                    MissedSessionCard(
                        missedCount: adherence.outstandingMissedDays,
                        currentWeekIndex: position.currentWeekIndex
                    )
                    .accessibilityIdentifier("Programs.Progress.MissedCard")
                }

                if let deloadMessage = deloadMessage(for: assignment, position: position) {
                    DeloadCueCard(message: deloadMessage)
                        .accessibilityIdentifier("Programs.Progress.DeloadCard")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Current week", defaultValue: "Current week"))
                        .font(.headline)

                    ForEach(plannedDays) { day in
                        ProgramDayRow(
                            day: day,
                            isRoutineAvailable: isRoutineAvailable(for: day)
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .accessibilityIdentifier("Programs.Progress.CurrentWeek")
            }
            .padding(16)
        }
    }

    private func progressHeader(position: ProgramPosition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(program.name)
                .font(.title2.bold())

            Text(
                String(
                    format: String(localized: "Week %lld • Day %lld", defaultValue: "Week %lld • Day %lld"),
                    Int64(position.currentWeekIndex),
                    Int64(position.currentDayIndex ?? 0)
                )
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            if position.isBehindSchedule {
                Text(String(localized: "Some scheduled days are still incomplete.", defaultValue: "Some scheduled days are still incomplete."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func currentWeekTitle(weekIndex: Int) -> String {
        program.orderedWeeks.first(where: { $0.index == weekIndex })?.displayTitle
        ?? String(format: String(localized: "Week %lld", defaultValue: "Week %lld"), Int64(weekIndex))
    }

    private func deloadMessage(
        for assignment: ProgramAssignment,
        position: ProgramPosition
    ) -> String? {
        if assignment.executionState?.deloadedWeekIndexes.contains(position.currentWeekIndex) == true {
            return String(
                format: String(localized: "Week %lld is a deload week.", defaultValue: "Week %lld is a deload week."),
                Int64(position.currentWeekIndex)
            )
        }

        guard let upcomingWeek = program.orderedWeeks.first(where: { $0.index == position.currentWeekIndex + 1 }) else {
            return nil
        }

        let hasDeloadRule = upcomingWeek.days.contains { day in
            day.prescriptions.contains { prescription in
                prescription.progressionRules.contains { rule in
                    if case .deloadEvery = rule { return true }
                    return false
                }
            }
        }

        guard hasDeloadRule else { return nil }
        return String(
            format: String(localized: "Deload week starts next: Week %lld.", defaultValue: "Deload week starts next: Week %lld."),
            Int64(upcomingWeek.index)
        )
    }

    private func loadAssignment() {
        do {
            let descriptor = FetchDescriptor<ProgramAssignment>(
                predicate: #Predicate { $0.id == assignmentID }
            )
            assignment = try modelContext.fetch(descriptor).first
        } catch {
            assignment = nil
        }
    }

    private func loadRoutineAvailability() {
        let map = (try? ProgramPackAssetMapStore.load()) ?? .empty
        availableRoutineSlugs = Set(map.routinesBySlug.keys)
    }

    private func isRoutineAvailable(for day: PlannedProgramDay) -> Bool {
        guard let routineSlug = day.routineSlug, !routineSlug.isEmpty else { return true }
        return availableRoutineSlugs.contains(TrainingProgram.makeSlug(routineSlug))
    }
}

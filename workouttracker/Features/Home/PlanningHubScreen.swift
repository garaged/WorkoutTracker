import SwiftUI
import SwiftData

struct PlanningHubScreen: View {
    @Query(sort: [SortDescriptor(\TemplateActivity.title, order: .forward)])
    private var templates: [TemplateActivity]

    @Query(sort: [SortDescriptor(\ProgramAssignment.assignedAt, order: .reverse)])
    private var assignments: [ProgramAssignment]

    @State private var installedProgramCount: Int?
    @State private var activeProgram: TrainingProgram?
    @State private var activeProgramSummary: ActiveProgramSummary?

    private let applyDay: Date
    private let importExportService = ProgramImportExportService()

    init(applyDay: Date) {
        self.applyDay = applyDay
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                NavigationLink {
                    TemplatesScreen(applyDay: applyDay)
                } label: {
                    PlanningEntryCard(
                        title: String(localized: "Templates", defaultValue: "Templates"),
                        subtitle: String(localized: "Reusable day plans that can preload your calendar.", defaultValue: "Reusable day plans that can preload your calendar."),
                        systemImage: "wand.and.stars",
                        tint: .indigo,
                        status: templateStatus,
                        accessibilityIdentifier: "PlanningHub.Card.Templates"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    if let activeProgram, let activeAssignment {
                        ProgramProgressScreen(program: activeProgram, assignmentID: activeAssignment.id)
                    } else {
                        ProgramLibraryScreen()
                    }
                } label: {
                    PlanningEntryCard(
                        title: programCardTitle,
                        subtitle: programCardSubtitle,
                        systemImage: "books.vertical",
                        tint: .orange,
                        status: programStatus,
                        detailLines: activeProgramDetailLines
                    )
                }
                .buttonStyle(.plain)

                if activeProgram != nil {
                    NavigationLink {
                        ProgramLibraryScreen()
                    } label: {
                        Label(
                            String(localized: "Open library", defaultValue: "Open library"),
                            systemImage: "books.vertical"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -6)
                }

                footer
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(String(localized: "Plans", defaultValue: "Plans"))
        .task {
            await refreshProgramSummary()
        }
        .onChange(of: assignmentFingerprint) { _, _ in
            Task {
                await refreshProgramSummary()
            }
        }
    }

    private func refreshProgramSummary() async {
        do {
            let installedPrograms = try await importExportService.loadLibrary()
            installedProgramCount = installedPrograms.count

            guard let assignment = assignments.first(where: { $0.isActive }) else {
                activeProgram = nil
                activeProgramSummary = nil
                return
            }

            guard let program = installedPrograms.first(where: { $0.id == assignment.programId }) else {
                activeProgram = nil
                activeProgramSummary = ActiveProgramSummary(
                    programName: assignment.programNameSnapshot,
                    statusLine: String(localized: "Current assignment unavailable", defaultValue: "Current assignment unavailable"),
                    nextLine: String(localized: "Re-import the program to restore planning details.", defaultValue: "Re-import the program to restore planning details.")
                )
                return
            }

            activeProgram = program
            let position = ProgramPlanner.currentPosition(for: assignment, program: program)
            let nextActionable = ProgramPlanner.nextActionableDay(for: assignment, program: program)

            let statusLine: String
            if position.isProgramComplete {
                statusLine = String(localized: "Program complete", defaultValue: "Program complete")
            } else if position.isBehindSchedule {
                statusLine = String(
                    format: String(localized: "planning.programs.status.behind", defaultValue: "Week %lld • behind schedule"),
                    Int64(position.currentWeekIndex)
                )
            } else {
                statusLine = String(
                    format: String(localized: "planning.programs.status.on_track", defaultValue: "Week %lld • on track"),
                    Int64(position.currentWeekIndex)
                )
            }

            let nextLine: String
            if let nextActionable {
                let dateText = nextActionable.scheduledDate.formatted(date: .abbreviated, time: .omitted)
                nextLine = String(
                    format: String(localized: "planning.programs.next_day", defaultValue: "Next: Day %1$lld %2$@ • %3$@"),
                    Int64(nextActionable.dayIndex),
                    nextActionable.title,
                    dateText
                )
            } else {
                nextLine = String(localized: "No upcoming training day", defaultValue: "No upcoming training day")
            }

            activeProgramSummary = ActiveProgramSummary(
                programName: assignment.programNameSnapshot,
                statusLine: statusLine,
                nextLine: nextLine
            )
        } catch {
            installedProgramCount = nil
            activeProgram = nil
            activeProgramSummary = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Planning", defaultValue: "Planning"))
                .font(.largeTitle.bold())

            Text(String(localized: "Choose a lightweight template for recurring days or a structured program for multi-week training.", defaultValue: "Choose a lightweight template for recurring days or a structured program for multi-week training."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        Text(String(localized: "Program follow-up happens in Calendar after scheduling. Import, export, and asset repair stay available inside Programs and Settings.", defaultValue: "Program follow-up happens in Calendar after scheduling. Import, export, and asset repair stay available inside Programs and Settings."))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private var templateStatus: String {
        if templates.isEmpty {
            return String(localized: "No templates yet", defaultValue: "No templates yet")
        }
        return String(
            format: String(localized: "planning.templates.count", defaultValue: "%lld templates"),
            Int64(templates.count)
        )
    }

    private var programStatus: String {
        if activeProgramSummary != nil {
            return String(localized: "Active program", defaultValue: "Active program")
        }

        guard let installedProgramCount else {
            return String(localized: "Library unavailable", defaultValue: "Library unavailable")
        }

        if installedProgramCount == 0 {
            return String(localized: "No installed programs", defaultValue: "No installed programs")
        }

        return String(
            format: String(localized: "planning.programs.count", defaultValue: "%lld installed"),
            Int64(installedProgramCount)
        )
    }

    private var programCardTitle: String {
        if activeProgramSummary != nil {
            return String(localized: "Continue Program", defaultValue: "Continue Program")
        }
        return String(localized: "Programs", defaultValue: "Programs")
    }

    private var programCardSubtitle: String {
        if activeProgramSummary != nil {
            return String(localized: "Review your current multi-week plan here. Scheduled workout days are followed from Calendar.", defaultValue: "Review your current multi-week plan here. Scheduled workout days are followed from Calendar.")
        }
        return String(localized: "Import, review, and schedule multi-week training plans.", defaultValue: "Import, review, and schedule multi-week training plans.")
    }

    private var activeProgramDetailLines: [String] {
        guard let activeProgramSummary else { return [] }
        return [
            activeProgramSummary.programName,
            activeProgramSummary.statusLine,
            activeProgramSummary.nextLine,
            String(localized: "Follow scheduled days from Calendar.", defaultValue: "Follow scheduled days from Calendar.")
        ]
    }

    private var assignmentFingerprint: [String] {
        assignments.map { assignment in
            "\(assignment.id.uuidString)|\(assignment.programId.uuidString)|\(assignment.statusRaw)|\(assignment.startDate.timeIntervalSince1970)"
        }
    }

    private var activeAssignment: ProgramAssignment? {
        guard let activeProgram else { return nil }
        return assignments.first { $0.programId == activeProgram.id && $0.isActive }
    }
}

private struct PlanningEntryCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let status: String
    var detailLines: [String] = []
    var accessibilityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.12))
                )

            if !detailLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(detailLines, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
        .shadow(radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). \(status)")
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

private struct ActiveProgramSummary {
    let programName: String
    let statusLine: String
    let nextLine: String
}

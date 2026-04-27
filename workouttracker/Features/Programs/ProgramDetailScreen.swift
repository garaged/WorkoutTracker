// workouttracker/Features/Programs/ProgramDetailScreen.swift
import SwiftUI
import SwiftData

struct ProgramDetailScreen: View {
    let program: TrainingProgram

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ProgramAssignment.assignedAt, order: .reverse)])
    private var assignments: [ProgramAssignment]

    @State private var showScheduleSheet = false

    @State private var schedPreview: ProgramSchedulingService.Preview? = nil
    @State private var isInstallingAssets = false

    @State private var installMessage: String? = nil
    @State private var showInstallMessage = false

    var body: some View {
        List {
            Section(AppFormatting.localized("Overview")) {
                Text(program.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let summary = program.summary, !summary.isEmpty {
                    Text(summary)
                        .foregroundStyle(.secondary)
                }

                LabeledContent(AppFormatting.localized("Duration"), value: AppFormatting.localizedFormat("%lld weeks", Int64(program.durationWeeks)))

                if program.level != .unknown {
                    LabeledContent(AppFormatting.localized("Level"), value: program.level.rawValue.capitalized)
                }

                if let author = program.author, !author.isEmpty {
                    LabeledContent(AppFormatting.localized("Author"), value: author)
                }

                if !program.tags.isEmpty {
                    LabeledContent(AppFormatting.localized("Tags"), value: program.tags.joined(separator: ", "))
                }

                if !program.equipment.isEmpty {
                    LabeledContent(AppFormatting.localized("Equipment"), value: program.equipment.joined(separator: ", "))
                }

                // ✅ NEW: schedulable status + missing routines + install CTA
                schedulableStatusBlock

                if let activeAssignment {
                    NavigationLink {
                        ProgramProgressScreen(program: program, assignmentID: activeAssignment.id)
                    } label: {
                        Label(AppFormatting.localized("View program progress"), systemImage: "chart.bar.doc.horizontal")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("programs.detail.progressButton")
                }

                NavigationLink {
                    ProgramAssignmentScreen(program: program)
                } label: {
                    Label(
                        activeAssignment == nil
                            ? AppFormatting.localized("Assign this program")
                            : AppFormatting.localized("Reassign program"),
                        systemImage: "flag.checkered"
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("programs.detail.assignButton")

                Button {
                    showScheduleSheet = true
                } label: {
                    Label(AppFormatting.localized("Schedule this program"), systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("programs.detail.scheduleButton")
                .padding(.top, 6)
                .disabled(!(schedPreview?.isSchedulable ?? true))
            }

            Section(AppFormatting.localized("Weeks")) {
                ForEach(program.orderedWeeks, id: \.id) { week in
                    DisclosureGroup(week.displayTitle) {
                        if let goal = week.goal, !goal.isEmpty {
                            Text(goal)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }

                        ForEach(week.orderedDays, id: \.id) { day in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(AppFormatting.localizedFormat("Day %lld", Int64(day.index)))
                                        .font(.headline)
                                    Text(day.title)
                                        .foregroundStyle(.secondary)
                                }

                                if let focus = day.focus, !focus.isEmpty {
                                    Text(focus)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }

                                if day.blocks.isEmpty {
                                    Text(AppFormatting.localized("No blocks"))
                                        .font(.callout)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    ForEach(day.blocks, id: \.id) { b in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(b.title)
                                            HStack(spacing: 8) {
                                                Text(b.kind.rawValue.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                if let mins = b.estimatedMinutes {
                                                    Text(AppFormatting.localizedFormat("%lld min", Int64(mins)))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            if let notes = b.notes, !notes.isEmpty {
                                                Text(notes)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle(AppFormatting.localized("Program"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showScheduleSheet = true
                } label: {
                    Label(AppFormatting.localized("Schedule"), systemImage: "calendar.badge.plus")
                }
                .accessibilityIdentifier("programs.detail.scheduleToolbarButton")
                .disabled(!(schedPreview?.isSchedulable ?? true))
            }
        }
        .sheet(isPresented: $showScheduleSheet) {
            ProgramScheduleSheet(program: program)
        }
        .task {
            refreshSchedulablePreview()
        }
        .alert(AppFormatting.localized("Program assets"), isPresented: $showInstallMessage) {
            Button(String(localized: "OK", defaultValue: "OK"), role: .cancel) { }
        } message: {
            Text(installMessage ?? String(localized: "Done.", defaultValue: "Done."))
        }
    }

    // MARK: - Schedulable status

    private var activeAssignment: ProgramAssignment? {
        assignments.first { $0.programId == program.id && $0.isActive }
    }

    private var schedulableStatusBlock: some View {
        Group {
            if let p = schedPreview {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: p.isSchedulable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(p.isSchedulable ? .green : .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                p.isSchedulable
                                    ? String(localized: "Schedulable", defaultValue: "Schedulable")
                                    : String(localized: "Missing routines", defaultValue: "Missing routines")
                            )
                                .font(.subheadline.weight(.semibold))

                            Text(
                                p.isSchedulable
                                    ? String(localized: "All required routines are installed.", defaultValue: "All required routines are installed.")
                                    : String(localized: "Install the missing routines to enable scheduling.", defaultValue: "Install the missing routines to enable scheduling.")
                            )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    if !p.isSchedulable {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppFormatting.localized("Missing routine slugs:"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(p.missingRoutineSlugs, id: \.self) { slug in
                                Text(slug)
                                    .font(.caption)
                                    .textSelection(.enabled)
                            }

                            Button {
                                Task { installRequiredAssetsFromCatalog() }
                            } label: {
                                HStack {
                                    if isInstallingAssets {
                                        ProgressView().controlSize(.small)
                                    }
                                    Text(
                                        isInstallingAssets
                                            ? String(localized: "Installing...", defaultValue: "Installing...")
                                            : String(localized: "Install required assets", defaultValue: "Install required assets")
                                    )
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isInstallingAssets)
                            .accessibilityIdentifier("programs.detail.installAssetsButton")

                            Text(AppFormatting.localized("This installs routines/exercises from the bundled catalog (if available). Imported packs should be re-imported if their assets are missing."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 6)
            } else {
                // Initial load placeholder (avoids layout jump)
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(AppFormatting.localized("Checking requirements…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func refreshSchedulablePreview() {
        let opts = ProgramSchedulingService.Options(
            startDate: Date(),
            startTime: Date(),
            includeRestDays: true,
            conflictStrategy: .skipConflicts
        )
        schedPreview = ProgramSchedulingService.preview(program: program, options: opts)
    }

    private func installRequiredAssetsFromCatalog() {
        guard !isInstallingAssets else { return }
        isInstallingAssets = true
        defer { isInstallingAssets = false }

        do {
            let load = try ProgramCatalogService().loadCatalog()
            guard let pack = load.packV2, pack.formatVersion == 2 else {
                installMessage = String(
                    localized: "No bundled V2 catalog assets found. If this program came from an import, re-import the pack to reinstall its routines.",
                    defaultValue: "No bundled V2 catalog assets found. If this program came from an import, re-import the pack to reinstall its routines."
                )
                showInstallMessage = true
                return
            }

            let r = try ProgramPackInstallService.installAssets(from: pack, context: modelContext)

            // Refresh status after install
            refreshSchedulablePreview()

            if let p = schedPreview, p.isSchedulable {
                installMessage = String(
                    format: String(
                        localized: "Installed assets. Added %1$lld routines and %2$lld exercises.",
                        defaultValue: "Installed assets. Added %1$lld routines and %2$lld exercises."
                    ),
                    Int64(r.installedRoutines),
                    Int64(r.installedExercises)
                )
            } else {
                installMessage = String(
                    localized: "Installed catalog assets, but this program still has missing routines. If it was imported, re-import its pack.",
                    defaultValue: "Installed catalog assets, but this program still has missing routines. If it was imported, re-import its pack."
                )
            }
            showInstallMessage = true
        } catch {
            installMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showInstallMessage = true
        }
    }
}

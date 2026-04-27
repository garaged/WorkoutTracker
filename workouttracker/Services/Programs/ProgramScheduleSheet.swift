// workouttracker/Services/Programs/ProgramScheduleSheet.swift
import SwiftUI
import SwiftData
import Foundation

struct ProgramScheduleSheet: View {
    let program: TrainingProgram

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openTimelineForDate) private var openTimelineForDate

    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())

    // ✅ UITESTS: schedule close to "now" so it’s visible and hittable in timeline
    @State private var startTime: Date = {
        let env = ProcessInfo.processInfo.environment
        if env["UITESTS"] == "1" || ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return Date()
        }
        let cal = Calendar.current
        let now = Date()
        return cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
    }()

    @State private var includeRestDays = true

    // ✅ UITESTS: allow overlap so we never end up with 0 created due to conflicts
    @State private var conflict: ProgramSchedulingService.ConflictStrategy = {
        let env = ProcessInfo.processInfo.environment
        if env["UITESTS"] == "1" || ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return .allowOverlap
        }
        return .skipConflicts
    }()

    @State private var openTimelineAfterSchedule = true

    @State private var isScheduling = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        let preview = ProgramSchedulingService.preview(program: program, options: options)

        NavigationStack {
            List {
                Section(AppFormatting.localized("Start")) {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                }

                Section(AppFormatting.localized("Options")) {
                    Toggle(AppFormatting.localized("Create Rest between training days"), isOn: $includeRestDays)

                    Picker(AppFormatting.localized("Conflicts"), selection: $conflict) {
                        ForEach(ProgramSchedulingService.ConflictStrategy.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }

                    Toggle(AppFormatting.localized("After scheduling, open start day in timeline"), isOn: $openTimelineAfterSchedule)
                        .accessibilityIdentifier("programs.schedule.openTimelineToggle")
                }

                Section(AppFormatting.localized("Preview")) {
                    LabeledContent(AppFormatting.localized("Activities"), value: "\(preview.totalActivities)")
                    LabeledContent(AppFormatting.localized("Workouts"), value: "\(preview.workoutActivities)")
                    LabeledContent(AppFormatting.localized("Training days"), value: "\(preview.trainingDays)")

                    if let r = preview.dateRange {
                        LabeledContent(AppFormatting.localized("Range"),
                            value: "\(r.lowerBound.formatted(date: .abbreviated, time: .omitted)) → \(r.upperBound.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                if !preview.isSchedulable {
                    Section(AppFormatting.localized("Required routines not installed")) {
                        Text(AppFormatting.localized("This program can’t be scheduled until its routines exist in your library (V2 rule)."))
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        ForEach(preview.missingRoutineSlugs, id: \.self) { s in
                            Text(s).font(.callout)
                        }
                    }
                }
            }
            .navigationTitle(AppFormatting.localized("Schedule Program"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppFormatting.localized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { scheduleNow() } label: {
                        if isScheduling { ProgressView() } else { Text(AppFormatting.localized("Schedule")) }
                    }
                    .disabled(isScheduling || !preview.isSchedulable)
                    .accessibilityIdentifier("programs.schedule.confirmButton")
                }
            }
        }
        .alert(AppFormatting.localized("Error"), isPresented: $showError) {
            Button(AppFormatting.localized("OK"), role: .cancel) { }
        } message: {
            Text(errorMessage ?? AppFormatting.localized("Unknown error."))
        }
    }

    private var options: ProgramSchedulingService.Options {
        .init(
            startDate: startDate,
            startTime: startTime,
            includeRestDays: includeRestDays,
            conflictStrategy: conflict
        )
    }

    private func scheduleNow() {
        isScheduling = true
        defer { isScheduling = false }

        do {
            let r = try ProgramSchedulingService.schedule(program: program, options: options, context: modelContext)

            // ✅ Don’t jump to an empty timeline; fail loudly instead.
            if r.created == 0 {
                errorMessage = "No activities were created. Try changing Conflicts (Allow overlaps / Replace in slot) or verify the program has training days."
                showError = true
                return
            }

            try upsertProgramAssignment()

            if openTimelineAfterSchedule {
                // ✅ Jump to the *first scheduled workout day*, not necessarily the picked startDate.
                let dayToOpen =
                    ProgramSchedulingService.firstPlannedDayToOpen(program: program, options: options)
                    ?? Calendar.current.startOfDay(for: startDate)

                // Keep env hook (future router)
                openTimelineForDate(dayToOpen)

                // Hard guarantee for AppRootView / UITestHost listener
                NotificationCenter.default.post(
                    name: Notification.Name("workouttracker.openTimelineForDate"),
                    object: dayToOpen
                )
            }

            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    private func upsertProgramAssignment() throws {
        _ = try ProgramAssignmentService.activateProgram(
            program,
            startDate: startDate,
            anchorStrategy: .calendarAligned,
            context: modelContext
        )
    }
}

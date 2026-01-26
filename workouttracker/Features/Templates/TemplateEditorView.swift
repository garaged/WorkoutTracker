import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    enum Mode {
        case create
        case edit(TemplateActivity)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var template: TemplateActivity

    private let mode: Mode

    // Form state (kept local so we can edit recurrence cleanly)
    @State private var title: String = ""
    @State private var isEnabled: Bool = true

    @State private var startTime: Date = Calendar.current.date(
        bySettingHour: 8, minute: 0, second: 0, of: Date()
    ) ?? Date()

    @State private var durationMinutes: Int = 45

    @State private var recurrenceKind: RecurrenceRule.Kind = .daily
    @State private var interval: Int = 1
    @State private var weekdays: Set<Weekday> = []

    @State private var ruleStartDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var ruleEndDate: Date = Date()

    // Phase 2: scope + preview
    @State private var updateScope: UpdateScope = .thisAndFuture
    @State private var overwriteActual: Bool = false
    @State private var updatePreview: TemplateUpdatePreview = .init(affectedCount: 0, sampleStartDates: [])
    @State private var previewError: String?

    private let applyDay: Date

    private let planner = TemplateUpdatePlanner()
    private let applier = TemplateUpdateApplier()

    init(mode: Mode, applyDay: Date) {
        self.mode = mode
        self.applyDay = applyDay

        switch mode {
        case .create:
            // Draft object only used to drive the form bindings.
            // We do NOT insert it unless user taps Save.
            self.template = TemplateActivity(
                title: "",
                defaultStartMinute: 8 * 60,
                defaultDurationMinutes: 45,
                isEnabled: true,
                recurrence: RecurrenceRule(kind: .daily),
                kind: .generic,
                workoutRoutineId: nil
            )

        case .edit(let t):
            self.template = t
        }
    }

    var body: some View {
        Form {
            Section("Template") {
                TextField("Title", text: $title)

                Toggle("Enabled", isOn: $isEnabled)

                DatePicker("Default start time", selection: $startTime, displayedComponents: .hourAndMinute)

                Stepper(value: $durationMinutes, in: 5...360, step: 5) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(durationMinutes) min").foregroundStyle(.secondary)
                    }
                }
            }

            Section("Type") {
                Picker("Kind", selection: $template.kind) {
                    Text("General").tag(ActivityKind.generic)
                    Text("Workout").tag(ActivityKind.workout)
                }
                .pickerStyle(.segmented)
            }

            if template.kind == .workout {
                Section("Workout") {
                    RoutinePickerField(routineId: $template.workoutRoutineId)

                    Text("This routine will be attached to every generated workout activity from this template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Recurrence") {
                Picker("Repeats", selection: $recurrenceKind) {
                    Text("One-time").tag(RecurrenceRule.Kind.none)
                    Text("Daily").tag(RecurrenceRule.Kind.daily)
                    Text("Weekly").tag(RecurrenceRule.Kind.weekly)
                }

                if recurrenceKind != .none {
                    Stepper(value: $interval, in: 1...30) {
                        HStack {
                            Text("Interval")
                            Spacer()
                            Text(intervalLabel).foregroundStyle(.secondary)
                        }
                    }
                }

                if recurrenceKind == .weekly {
                    WeekdayPicker(weekdays: $weekdays)
                }

                DatePicker("Start date", selection: $ruleStartDate, displayedComponents: .date)

                Toggle("End date", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker(" ", selection: $ruleEndDate, displayedComponents: .date)
                }
            }

            if case .edit = mode {
                Section("Apply scope") {
                    Picker("Scope", selection: $updateScope) {
                        ForEach(UpdateScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }

                    Toggle("Overwrite actual fields", isOn: $overwriteActual)

                    if let previewError {
                        Text(previewError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(previewSummaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !updatePreview.sampleStartDates.isEmpty {
                            Text("Next: " + updatePreview.sampleStartDates
                                .map { $0.formatted(date: .abbreviated, time: .shortened) }
                                .joined(separator: ", ")
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        deleteTemplate()
                    } label: {
                        Label("Delete template", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(modeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            loadIfEditing()
            refreshUpdatePreview()
        }
        .onChange(of: previewInputs) { _, _ in
            refreshUpdatePreview()
        }
        .onChange(of: template.kind) { _, newKind in
            if newKind != .workout {
                template.workoutRoutineId = nil
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "New Template"
        case .edit: return "Edit Template"
        }
    }

    private var intervalLabel: String {
        switch recurrenceKind {
        case .daily:
            return interval == 1 ? "Every day" : "Every \(interval) days"
        case .weekly:
            return interval == 1 ? "Every week" : "Every \(interval) weeks"
        case .none:
            return ""
        }
    }

    private var previewSummaryText: String {
        let c = updatePreview.affectedCount
        let noun = (c == 1) ? "item" : "items"
        switch updateScope {
        case .thisInstance:
            return "This will update \(c) \(noun) (apply day only)."
        case .thisAndFuture:
            return "This will update \(c) \(noun) (this & future; materialized rows only)."
        case .allInstances:
            return "This will update \(c) \(noun) (all materialized rows)."
        }
    }

    private struct PreviewInputs: Hashable {
        let title: String
        let isEnabled: Bool
        let startMinute: Int
        let durationMinutes: Int

        let recurrenceKind: RecurrenceRule.Kind
        let interval: Int
        let weekdays: [Weekday]
        let ruleStartDate: Date
        let hasEndDate: Bool
        let ruleEndDate: Date

        let kind: ActivityKind
        let routineId: UUID?

        let scope: UpdateScope
        let overwriteActual: Bool
    }

    private var previewInputs: PreviewInputs {
        PreviewInputs(
            title: title,
            isEnabled: isEnabled,
            startMinute: minutesFromDate(startTime),
            durationMinutes: durationMinutes,
            recurrenceKind: recurrenceKind,
            interval: interval,
            weekdays: weekdays.sorted { $0.rawValue < $1.rawValue },
            ruleStartDate: ruleStartDate,
            hasEndDate: hasEndDate,
            ruleEndDate: ruleEndDate,
            kind: template.kind,
            routineId: template.workoutRoutineId,
            scope: updateScope,
            overwriteActual: overwriteActual
        )
    }

    private func loadIfEditing() {
        guard case let .edit(t) = mode else {
            // defaults for create
            ruleStartDate = Date()
            ruleEndDate = Date()
            return
        }

        title = t.title
        isEnabled = t.isEnabled
        durationMinutes = t.defaultDurationMinutes

        // start time -> Date
        startTime = dateFromMinutes(t.defaultStartMinute)

        // recurrence
        let r = t.recurrence
        recurrenceKind = r.kind
        interval = max(1, r.interval)
        weekdays = r.weekdays
        ruleStartDate = r.startDate
        if let e = r.endDate {
            hasEndDate = true
            ruleEndDate = e
        } else {
            hasEndDate = false
            ruleEndDate = Date()
        }

        template.kind = t.kind
        template.workoutRoutineId = t.workoutRoutineId
    }

    private func refreshUpdatePreview() {
        guard case .edit = mode else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            previewError = nil
            updatePreview = .init(affectedCount: 0, sampleStartDates: [])
            return
        }

        var rule = RecurrenceRule(kind: recurrenceKind)
        rule.interval = max(1, interval)
        rule.startDate = ruleStartDate
        rule.endDate = hasEndDate ? ruleEndDate : nil

        if recurrenceKind == .weekly {
            var wds = weekdays
            if wds.isEmpty {
                let wdInt = Calendar.current.component(.weekday, from: ruleStartDate)
                if let wd = Weekday(rawValue: wdInt) { wds = [wd] }
            }
            rule.weekdays = wds
        } else {
            rule.weekdays = []
        }

        let selectedKind = template.kind
        let selectedRoutineId: UUID? = (selectedKind == .workout) ? template.workoutRoutineId : nil

        // If we're in edit mode, template.id is valid
        let draft = TemplateDraft(
            id: template.id,
            title: cleanTitle,
            isEnabled: isEnabled,
            defaultStartMinute: minutesFromDate(startTime),
            defaultDurationMinutes: durationMinutes,
            recurrence: rule,
            kind: selectedKind,
            workoutRoutineId: selectedRoutineId
        )

        do {
            let plan = try planner.makePlan(
                templateId: template.id,
                draft: draft,
                scope: updateScope,
                applyDay: applyDay,
                context: modelContext,
                daysAhead: 120,
                detachIfNoLongerMatches: true,
                overwriteActual: overwriteActual,
                includeApplyDayCreate: true,
                resurrectOverridesOnApplyDay: true,
                forceApplyDay: true
            )
            previewError = nil
            updatePreview = plan.preview
        } catch {
            previewError = "Couldn’t compute preview: \(error.localizedDescription)"
            updatePreview = .init(affectedCount: 0, sampleStartDates: [])
        }
    }

    private struct TemplateSnapshot {
        let title: String
        let isEnabled: Bool
        let defaultStartMinute: Int
        let defaultDurationMinutes: Int
        let recurrence: RecurrenceRule
        let kind: ActivityKind
        let workoutRoutineId: UUID?
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let startMinute = minutesFromDate(startTime)

        var rule = RecurrenceRule(kind: recurrenceKind)
        rule.interval = max(1, interval)
        rule.startDate = ruleStartDate
        rule.endDate = hasEndDate ? ruleEndDate : nil

        if recurrenceKind == .weekly {
            if weekdays.isEmpty {
                let wdInt = Calendar.current.component(.weekday, from: ruleStartDate)
                if let wd = Weekday(rawValue: wdInt) { weekdays = [wd] }
            }
            rule.weekdays = weekdays
        } else {
            rule.weekdays = []
        }

        // ✅ Use the UI binding as the source of truth
        let selectedKind = self.template.kind
        let selectedRoutineId: UUID? = (selectedKind == .workout) ? self.template.workoutRoutineId : nil

        switch mode {
        case .create:
            let t = TemplateActivity(
                title: cleanTitle,
                defaultStartMinute: startMinute,
                defaultDurationMinutes: durationMinutes,
                isEnabled: isEnabled,
                recurrence: rule,
                kind: selectedKind,
                workoutRoutineId: selectedRoutineId
            )
            modelContext.insert(t)
            try? modelContext.save()

            do {
                try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: modelContext)
            } catch {
                print("Preload after create failed: \(error)")
            }
            dismiss()

        case .edit(let t):
            // Snapshot for rollback (no “acts weird” partial state)
            let before = TemplateSnapshot(
                title: t.title,
                isEnabled: t.isEnabled,
                defaultStartMinute: t.defaultStartMinute,
                defaultDurationMinutes: t.defaultDurationMinutes,
                recurrence: t.recurrence,
                kind: t.kind,
                workoutRoutineId: t.workoutRoutineId
            )

            // Apply edits to template (in-memory)
            t.title = cleanTitle
            t.isEnabled = isEnabled
            t.defaultStartMinute = startMinute
            t.defaultDurationMinutes = durationMinutes
            t.recurrence = rule
            t.kind = selectedKind
            t.workoutRoutineId = selectedRoutineId

            let draft = TemplateDraft(
                id: t.id,
                title: cleanTitle,
                isEnabled: isEnabled,
                defaultStartMinute: startMinute,
                defaultDurationMinutes: durationMinutes,
                recurrence: rule,
                kind: selectedKind,
                workoutRoutineId: selectedRoutineId
            )

            do {
                let plan = try planner.makePlan(
                    templateId: t.id,
                    draft: draft,
                    scope: updateScope,
                    applyDay: applyDay,
                    context: modelContext,
                    daysAhead: 120,
                    detachIfNoLongerMatches: true,
                    overwriteActual: overwriteActual,
                    includeApplyDayCreate: true,
                    resurrectOverridesOnApplyDay: true,
                    forceApplyDay: true
                )

                try applier.apply(plan: plan, context: modelContext)

                // ✅ single save point
                try modelContext.save()
                dismiss()

            } catch {
                // Rollback activities + template fields
                // (No save happened if we’re here)
                t.title = before.title
                t.isEnabled = before.isEnabled
                t.defaultStartMinute = before.defaultStartMinute
                t.defaultDurationMinutes = before.defaultDurationMinutes
                t.recurrence = before.recurrence
                t.kind = before.kind
                t.workoutRoutineId = before.workoutRoutineId

                // Best-effort rollback if a plan was partially applied (applier also rolls back on its own errors)
                print("Template update failed: \(error)")
            }
        }
    }

    private func deleteTemplate() {
        guard case let .edit(t) = mode else { return }
        modelContext.delete(t)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Time conversion

    private func minutesFromDate(_ d: Date) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: d)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        return (h * 60) + m
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        return cal.date(byAdding: .minute, value: minutes, to: base) ?? Date()
    }
}

// MARK: - Weekday picker

private struct WeekdayPicker: View {
    @Binding var weekdays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Days").font(.subheadline).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { wd in
                    let selected = weekdays.contains(wd)

                    Button {
                        if selected { weekdays.remove(wd) } else { weekdays.insert(wd) }
                    } label: {
                        Text(label(for: wd))
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selected ? Color.primary.opacity(0.15) : Color.secondary.opacity(0.10))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(selected ? "\(label(for: wd)) selected" : label(for: wd))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func label(for w: Weekday) -> String {
        switch w {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

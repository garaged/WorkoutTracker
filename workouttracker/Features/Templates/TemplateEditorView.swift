import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    enum Mode {
        case create
        case edit(TemplateActivity)
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
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
    @State private var showApplyToDayAlert = false
    @State private var lastSavedTemplateId: UUID?
    @State private var upcomingUpdateStatus: String?

    
    private let applyDay: Date
    
    init(mode: Mode, applyDay: Date) {
        self.mode = mode
        self.applyDay = applyDay
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
        .onAppear { loadIfEditing() }
        .alert("Apply changes to this day?", isPresented: $showApplyToDayAlert) {
            Button("Apply (keep edits)") {
                applyToDay(overwriteActual: false)
            }
            Button("Force apply", role: .destructive) {
                applyToDay(overwriteActual: true)
            }
            Button("Not now", role: .cancel) {
                dismiss()
            }
        } message: {
            if let upcomingUpdateStatus {
                Text("✅ \(upcomingUpdateStatus)\n\nApply updates today's generated instance (and can bring it back if deleted).")
            } else {
                Text("Apply updates today's generated instance (and can bring it back if deleted).")
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
            // If user didn’t pick weekdays, default to startDate’s weekday
            if weekdays.isEmpty {
                let wdInt = Calendar.current.component(.weekday, from: ruleStartDate)
                if let wd = Weekday(rawValue: wdInt) { weekdays = [wd] }
            }
            rule.weekdays = weekdays
        } else {
            rule.weekdays = []
        }
        
        let template: TemplateActivity
        
        switch mode {
        case .create:
            let t = TemplateActivity(
                title: cleanTitle,
                defaultStartMinute: startMinute,
                defaultDurationMinutes: durationMinutes,
                isEnabled: isEnabled,
                recurrence: rule
            )
            modelContext.insert(t)
            template = t
            
        case .edit(let t):
            t.title = cleanTitle
            t.isEnabled = isEnabled
            t.defaultStartMinute = startMinute
            t.defaultDurationMinutes = durationMinutes
            t.recurrence = rule
            template = t
        }
        
        lastSavedTemplateId = template.id
        try? modelContext.save()

        switch mode {
        case .create:
            // Create should feel instant: generate for the current day immediately.
            do {
                try TemplatePreloader.ensureDayIsPreloaded(for: applyDay, context: modelContext)
            } catch {
                print("Preload after create failed: \(error)")
            }
            dismiss()

        case .edit:
            let cal = Calendar.current
            let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: applyDay)) ?? applyDay

            do {
                try TemplatePreloader.updateExistingUpcomingInstances(
                    templateId: template.id,
                    from: tomorrow,
                    daysAhead: 120,
                    context: modelContext
                )
                upcomingUpdateStatus = "Updated existing upcoming instances for the next 120 days."
            } catch {
                upcomingUpdateStatus = "Couldn’t update upcoming instances: \(error.localizedDescription)"
                print("Bulk update upcoming instances failed: \(error)")
            }

            showApplyToDayAlert = true

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
    
    private func applyToDay(overwriteActual: Bool) {
        guard let id = lastSavedTemplateId else { dismiss(); return }
        do {
            try TemplatePreloader.applyTemplateChange(
                templateId: id,
                for: applyDay,
                context: modelContext,
                forceForDay: true,
                resurrectIfOverridden: true,
                overwriteActual: overwriteActual
            )
        } catch {
            print("Apply template change failed: \(error)")
        }
        dismiss()
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

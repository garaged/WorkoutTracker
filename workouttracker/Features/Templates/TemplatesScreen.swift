import SwiftUI
import SwiftData

struct TemplatesScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\TemplateActivity.title, order: .forward)])
    private var templates: [TemplateActivity]

    private var orderedTemplates: [TemplateActivity] {
        templates.sorted { a, b in
            if a.isEnabled != b.isEnabled { return a.isEnabled && !b.isEnabled }
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }

    private let applyDay: Date

    init(applyDay: Date) {
        self.applyDay = applyDay
    }

    var body: some View {
        List {
            if templates.isEmpty {
                ContentUnavailableView(AppFormatting.localized("No schedule templates"),
                    systemImage: "wand.and.stars",
                    description: Text(AppFormatting.localized("Create schedule templates so Today is preloaded automatically."))
                )
            } else {
                ForEach(orderedTemplates) { t in
                    NavigationLink {
                        TemplateEditorView(mode: .edit(t), applyDay: applyDay)
                    } label: {
                        TemplateRow(template: t)
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
        }
        .navigationTitle(AppFormatting.localized("Schedule Templates"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    RoutinesScreen()
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                }

                NavigationLink {
                    TemplateEditorView(mode: .create, applyDay: applyDay)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func deleteTemplates(_ indexSet: IndexSet) {
        for i in indexSet {
            modelContext.delete(orderedTemplates[i])
        }
        try? modelContext.save()
    }
}

private struct TemplateRow: View {
    @Environment(\.modelContext) private var modelContext
    let template: TemplateActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(template.title).font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { template.isEnabled },
                    set: { newValue in
                        template.isEnabled = newValue
                        try? modelContext.save()
                    }
                ))
                .labelsHidden()
            }

            HStack(spacing: 8) {
                Text(startTimeLabel(minutes: template.defaultStartMinute))
                Text(AppFormatting.localized("•")).foregroundStyle(.secondary)
                Text(String(format: String(localized: "templates.row.duration_minutes.compact", defaultValue: "%lldm"), Int64(template.defaultDurationMinutes)))
                Text(AppFormatting.localized("•")).foregroundStyle(.secondary)
                Text(recurrenceSummary(template.recurrence))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func startTimeLabel(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func recurrenceSummary(_ r: RecurrenceRule) -> String {
        switch r.kind {
        case .none: return String(localized: "templates.recurrence.one_time.lowercase", defaultValue: "one-time")
        case .daily: return r.interval <= 1 ? String(localized: "templates.recurrence.daily", defaultValue: "daily") : String(format: String(localized: "templates.recurrence.every_n_days.lowercase", defaultValue: "every %lld days"), Int64(r.interval))
        case .weekly:
            let days = r.weekdays.sorted { $0.rawValue < $1.rawValue }.map(wdAbbrev).joined(separator: ",")
            let base = r.interval <= 1 ? String(localized: "templates.recurrence.weekly", defaultValue: "weekly") : String(format: String(localized: "templates.recurrence.every_n_weeks.lowercase", defaultValue: "every %lld weeks"), Int64(r.interval))
            return days.isEmpty ? base : String(format: String(localized: "templates.recurrence.weekly_with_days", defaultValue: "%1$@ (%2$@)"), base, days)
        }
    }

    private func wdAbbrev(_ w: Weekday) -> String {
        switch w {
        case .sunday: return String(localized: "weekday.sun.short", defaultValue: "Sun")
        case .monday: return String(localized: "weekday.mon.short", defaultValue: "Mon")
        case .tuesday: return String(localized: "weekday.tue.short", defaultValue: "Tue")
        case .wednesday: return String(localized: "weekday.wed.short", defaultValue: "Wed")
        case .thursday: return String(localized: "weekday.thu.short", defaultValue: "Thu")
        case .friday: return String(localized: "weekday.fri.short", defaultValue: "Fri")
        case .saturday: return String(localized: "weekday.sat.short", defaultValue: "Sat")
        }
    }
}

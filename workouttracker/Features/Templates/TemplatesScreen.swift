import SwiftUI
import SwiftData

struct TemplatesScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\TemplateActivity.title, order: .forward),
    ])
    private var templates: [TemplateActivity]

    private var orderedTemplates: [TemplateActivity] {
        templates.sorted { a, b in
            if a.isEnabled != b.isEnabled { return a.isEnabled && !b.isEnabled } // enabled first
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }
    
    private let applyDay: Date

    init(applyDay: Date) {
        self.applyDay = applyDay
    }
    
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No templates",
                        systemImage: "wand.and.stars",
                        description: Text("Create templates so Today is preloaded automatically.")
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
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNew) {
                NavigationStack {
                    TemplateEditorView(mode: .create, applyDay: applyDay)
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
                Text(template.title)
                    .font(.headline)

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
                Text("•").foregroundStyle(.secondary)
                Text("\(template.defaultDurationMinutes)m")
                Text("•").foregroundStyle(.secondary)
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
        case .none:
            return "one-time"
        case .daily:
            return r.interval <= 1 ? "daily" : "every \(r.interval) days"
        case .weekly:
            let days = r.weekdays
                .sorted { $0.rawValue < $1.rawValue }
                .map { wdAbbrev($0) }
                .joined(separator: ",")
            let base = r.interval <= 1 ? "weekly" : "every \(r.interval) weeks"
            return days.isEmpty ? base : "\(base) (\(days))"
        }
    }

    private func wdAbbrev(_ w: Weekday) -> String {
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

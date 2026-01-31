import SwiftUI

struct MeasurementsScreen: View {

    // MARK: Persistence (v1)
    @AppStorage("measurements.entries.v1") private var entriesJSON: String = "[]"

    @State private var entries: [MeasurementEntry] = []
    @State private var mode: Mode = .overview

    @State private var showAdd: Bool = false
    @State private var editing: MeasurementEntry? = nil

    private let cal = Calendar.current

    enum Mode: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case trends = "Trends"
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }

            if entries.isEmpty {
                ContentUnavailableView(
                    "No Measurements Yet",
                    systemImage: "ruler",
                    description: Text("Add your first entry to start tracking trends.")
                )
                .listRowBackground(Color.clear)
            } else {
                switch mode {
                case .overview:
                    overview
                case .trends:
                    trends
                }
            }
        }
        .navigationTitle("Measurements")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add measurement")
            }
        }
        .onAppear {
            entries = decode(entriesJSON)
            normalize()
        }
        .onChange(of: entries) { _, newValue in
            entriesJSON = encode(newValue)
        }
        .sheet(isPresented: $showAdd) {
            MeasurementEditorSheet(
                title: "Add Measurement",
                initial: .new(defaultDate: Date()),
                onSave: { newEntry in
                    entries.append(newEntry)
                    normalize()
                }
            )
        }
        .sheet(item: $editing) { entry in
            MeasurementEditorSheet(
                title: "Edit Measurement",
                initial: entry,
                onSave: { updated in
                    if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
                        entries[idx] = updated
                        normalize()
                    }
                }
            )
        }
    }

    // MARK: - Overview

    private var overview: some View {
        let types = MeasurementType.allCases
        let series = seriesByType(entries)

        return Group {
            Section("Latest") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    ForEach(types, id: \.self) { t in
                        let s = series[t, default: []]
                        LatestCard(type: t, series: s)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // edit most recent entry for that type
                                if let last = s.last {
                                    editing = last
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            historySections
        }
    }

    private var historySections: some View {
        let grouped = groupedDays(entries)

        return Group {
            ForEach(grouped, id: \.day) { g in
                Section(g.title) {
                    ForEach(g.items) { e in
                        Button { editing = e } label: {
                            MeasurementRow(entry: e)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(e)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trends

    private var trends: some View {
        let series = seriesByType(entries)

        return Group {
            Section("By Type") {
                ForEach(MeasurementType.allCases, id: \.self) { t in
                    let s = series[t, default: []]
                    TrendRow(type: t, series: s)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // edit most recent entry
                            if let last = s.last { editing = last }
                        }
                }
            }
        }
    }

    // MARK: - Data shaping

    private func seriesByType(_ entries: [MeasurementEntry]) -> [MeasurementType: [MeasurementEntry]] {
        let dict = Dictionary(grouping: entries) { $0.type }
        return dict.mapValues { $0.sorted(by: { $0.date < $1.date }) }
    }

    private func groupedDays(_ entries: [MeasurementEntry]) -> [DayGroup] {
        let dict = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        return dict
            .map { day, items in
                DayGroup(day: day, items: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.day > $1.day }
    }

    private func delete(_ entry: MeasurementEntry) {
        entries.removeAll { $0.id == entry.id }
        normalize()
    }

    private func normalize() {
        // Keep newest first for list browsing
        entries.sort { $0.date > $1.date }
    }

    // MARK: - JSON helpers

    private func decode<T: Decodable>(_ s: String) -> T {
        guard let data = s.data(using: .utf8) else {
            return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8)))
        }
        do {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            return try dec.decode(T.self, from: data)
        } catch {
            return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8)))
        }
    }

    private func encode<T: Encodable>(_ v: T) -> String {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(v)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}

// MARK: - Models (local v1)

private struct MeasurementEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var type: MeasurementType
    var value: Double
    var unit: MeasurementUnit
    var note: String

    static func new(defaultDate: Date) -> MeasurementEntry {
        let t: MeasurementType = .weight
        return .init(id: UUID(), date: defaultDate, type: t, value: 0, unit: t.defaultUnit, note: "")
    }

    var valueString: String {
        switch unit {
        case .percent: return "\(fmt(value))%"
        case .kg:      return "\(fmt(value)) kg"
        case .lb:      return "\(fmt(value)) lb"
        case .cm:      return "\(fmt(value)) cm"
        case .inch:    return "\(fmt(value)) in"
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: (abs(v.rounded() - v) < 0.0001) ? "%.0f" : "%.1f", v)
    }
}

private enum MeasurementType: String, CaseIterable, Codable, Hashable {
    case weight, bodyFat, waist, chest, hips, thigh, arm, neck

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .bodyFat: return "Body Fat"
        case .waist: return "Waist"
        case .chest: return "Chest"
        case .hips: return "Hips"
        case .thigh: return "Thigh"
        case .arm: return "Arm"
        case .neck: return "Neck"
        }
    }

    var defaultUnit: MeasurementUnit {
        switch self {
        case .weight: return .kg
        case .bodyFat: return .percent
        default: return .cm
        }
    }

    var allowedUnits: [MeasurementUnit] {
        switch self {
        case .weight: return [.kg, .lb]
        case .bodyFat: return [.percent]
        default: return [.cm, .inch]
        }
    }
}

private enum MeasurementUnit: String, CaseIterable, Codable, Hashable {
    case kg, lb, cm, inch, percent
}

private struct DayGroup: Hashable {
    let day: Date
    let items: [MeasurementEntry]

    var title: String {
        day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - UI

private struct MeasurementRow: View {
    let entry: MeasurementEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.type.displayName).font(.headline)
                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.valueString).font(.headline)
        }
        .padding(.vertical, 6)
    }
}

/// Sparkline: lightweight Path-based chart (no Charts.framework needed)
private struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(0.000001, maxV - minV)

            Path { p in
                guard values.count >= 2 else { return }
                for (i, v) in values.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(values.count - 1)
                    let yNorm = (v - minV) / span
                    let y = h - (h * CGFloat(yNorm))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(lineWidth: 2)
            .opacity(values.count >= 2 ? 1 : 0)
        }
    }
}

private struct LatestCard: View {
    let type: MeasurementType
    let series: [MeasurementEntry]

    var body: some View {
        let last = series.last
        let sparkVals = series.suffix(20).map(\.value)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let last {
                    Text(last.valueString)
                        .font(.headline)
                } else {
                    Text("—").font(.headline).foregroundStyle(.secondary)
                }
            }

            SparklineView(values: sparkVals)
                .frame(height: 26)
                .foregroundStyle(.tint)
                .opacity(sparkVals.count >= 2 ? 1 : 0.25)

            if let last {
                Text(last.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Tap + to add")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TrendRow: View {
    let type: MeasurementType
    let series: [MeasurementEntry]

    private var last: MeasurementEntry? { series.last }

    var body: some View {
        let spark = series.suffix(30).map(\.value)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(type.displayName).font(.headline)
                Spacer()
                Text(last?.valueString ?? "—")
                    .font(.headline)
                    .foregroundStyle(last == nil ? .secondary : .primary)
            }

            HStack(spacing: 12) {
                let d7 = delta(daysBack: 7)
                let d30 = delta(daysBack: 30)

                TrendDelta(label: "7d", delta: d7)
                TrendDelta(label: "30d", delta: d30)

                Spacer()

                SparklineView(values: spark)
                    .frame(width: 120, height: 22)
                    .foregroundStyle(.tint)
                    .opacity(spark.count >= 2 ? 1 : 0.25)
            }
        }
        .padding(.vertical, 6)
    }

    private func delta(daysBack: Int) -> Double? {
        guard let last else { return nil }
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -daysBack, to: last.date) ?? last.date
        let past = series.last(where: { $0.date <= cutoff }) ?? series.first
        guard let past else { return nil }
        return last.value - past.value
    }
}

private struct TrendDelta: View {
    let label: String
    let delta: Double?

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)

            if let delta {
                Text(deltaString(delta))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(delta == 0 ? .secondary : .primary)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
    }

    private func deltaString(_ d: Double) -> String {
        let s = String(format: (abs(d.rounded() - d) < 0.0001) ? "%.0f" : "%.1f", d)
        return (d > 0 ? "+\(s)" : s)
    }
}

private struct MeasurementEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initial: MeasurementEntry
    let onSave: (MeasurementEntry) -> Void

    @State private var id: UUID
    @State private var date: Date
    @State private var type: MeasurementType
    @State private var value: Double
    @State private var unit: MeasurementUnit
    @State private var note: String

    init(title: String, initial: MeasurementEntry, onSave: @escaping (MeasurementEntry) -> Void) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        _id = State(initialValue: initial.id)
        _date = State(initialValue: initial.date)
        _type = State(initialValue: initial.type)
        _value = State(initialValue: initial.value)
        _unit = State(initialValue: initial.unit)
        _note = State(initialValue: initial.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement") {
                    Picker("Type", selection: $type) {
                        ForEach(MeasurementType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .onChange(of: type) { _, newType in
                        if !newType.allowedUnits.contains(unit) {
                            unit = newType.defaultUnit
                        }
                    }

                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("0", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    Picker("Unit", selection: $unit) {
                        ForEach(type.allowedUnits, id: \.self) { u in
                            Text(unitLabel(u)).tag(u)
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(.init(id: id, date: date, type: type, value: value, unit: unit, note: note))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func unitLabel(_ u: MeasurementUnit) -> String {
        switch u {
        case .kg: return "kg"
        case .lb: return "lb"
        case .cm: return "cm"
        case .inch: return "in"
        case .percent: return "%"
        }
    }
}

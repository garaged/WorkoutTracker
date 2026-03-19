import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var goalPrefill: GoalPrefillStore
    @AppStorage("profile.equipment.custom.v1") private var customEquipmentJSON: String = "[]"
    
    @AppStorage("exerciseIllustrationSet")
    private var selectedIllustrationSetRaw: String = ExerciseIllustrationSet.dummyV1.rawValue
    
    let exercise: Exercise
    let startWorkoutAction: ((Exercise) -> Void)?

    @State private var history: [WorkoutSetLog] = []
    @State private var records: PersonalRecordsService.PersonalRecords?
    @State private var trendPoints: [PersonalRecordsService.TrendPoint] = []
    @State private var loadError: String?
    @State private var nextTarget: PersonalRecordsService.NextTarget? = nil
    @State private var showNextTargetActions: Bool = false
    @State private var showEquipmentEditor: Bool = false

    private let prService = PersonalRecordsService()

    init(exercise: Exercise, startWorkoutAction: ((Exercise) -> Void)? = nil) {
        self.exercise = exercise
        self.startWorkoutAction = startWorkoutAction
    }
    
    private var customEquipmentLabels: [String] {
        decode(customEquipmentJSON)
    }
    
    private func decode<T: Decodable>(_ s: String) -> T {
        guard let data = s.data(using: .utf8) else {
            return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8)))
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8))) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                equipmentSection

                if let instructions = exercise.instructions,
                   !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sectionTitle("Instructions")
                    Text(instructions)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let notes = exercise.notes,
                   !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sectionTitle("Notes")
                    Text(notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                }

                // ✅ “Sticky” CTA comes early
                if let startWorkoutAction {
                    Button {
                        startWorkoutAction(exercise)
                    } label: {
                        Label(AppFormatting.localized("Start workout with this exercise"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // ✅ PRs + trend are the “sticky” part (actionable at a glance)
                if let records {
                    ExercisePRSummaryView(
                        records: records,
                        nextTargetText: nextTarget?.text,
                        onTapNextTarget: (nextTarget == nil) ? nil : { showNextTargetActions = true }
                    )
                } else if loadError == nil {
                    ProgressView().frame(maxWidth: .infinity)
                }

                ExerciseTrendChartView(points: trendPoints)

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Raw history stays below
                historySection
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: exercise.id) {
            await loadAll()
        }
        .refreshable {
            await loadAll()
        }
        .confirmationDialog(
            "Next target",
            isPresented: $showNextTargetActions,
            titleVisibility: .visible
        ) {
            Button(AppFormatting.localized("Start workout and apply target")) {
                applyNextTargetPrefill()
                startWorkoutAction?(exercise)
            }
            Button(AppFormatting.localized("Apply for next workout")) {
                applyNextTargetPrefill()
            }
            Button(AppFormatting.localized("Cancel"), role: .cancel) {}
        } message: {
            if let text = nextTarget?.text {
                Text(text)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.title2.weight(.bold))
                Spacer()
                Text(exercise.modality.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            mediaPreview
        }
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if let name = resolvedIllustrationAssetName, !name.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.06))

                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            switch exercise.mediaKind {
            case .none:
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 220)
                    .overlay {
                        ContentUnavailableView(AppFormatting.localized("No media"),
                            systemImage: "photo",
                            description: Text(AppFormatting.localized("Add an asset name later."))
                        )
                    }

            case .bundledAsset:
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 220)
                    .overlay {
                        ContentUnavailableView(AppFormatting.localized("Missing illustration"),
                            systemImage: "photo",
                            description: Text(AppFormatting.localized("No illustration asset could be resolved for this exercise."))
                        )
                    }

            case .remoteURL:
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 220)
                    .overlay {
                        ContentUnavailableView(AppFormatting.localized("Remote media"),
                            systemImage: "link",
                            description: Text(AppFormatting.localized("We’ll support loading remote video/GIF later."))
                        )
                    }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppFormatting.localized("History"))
                    .font(.headline)
                Spacer()
                NavigationLink {
                    WorkoutHistoryScreen(filter: .exercise(exerciseId: exercise.id, exerciseName: exercise.name))
                } label: {
                    Text(AppFormatting.localized("See all"))
                }
                .font(.subheadline)
            }

            if history.isEmpty {
                ContentUnavailableView(AppFormatting.localized("No logged sets yet"),
                    systemImage: "clock",
                    description: Text(AppFormatting.localized("Complete sets in a workout session to see history here."))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let points = chartPoints(from: history)

                VStack(alignment: .leading, spacing: 10) {
                    statsRow(history)

                    Chart(points) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                    }
                    .frame(height: 180)

                    Text(pointsCaption(points))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statsRow(_ sets: [WorkoutSetLog]) -> some View {
        let completedCount = sets.count
        let last = sets.compactMap(\.completedAt).max()
        return HStack(spacing: 10) {
            statPill(title: AppFormatting.localized("Sets"), value: "\(completedCount)")
            if let last {
                statPill(title: AppFormatting.localized("Last"), value: last.formatted(.dateTime.month(.abbreviated).day()))
            }
            Spacer()
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @MainActor
    private func loadAll() async {
        await loadHistory()
        await reloadPRsAndTrends()
    }

    @MainActor
    private func reloadPRsAndTrends() async {
        do {
            loadError = nil

            let rec = try prService.records(for: exercise.id, context: modelContext)
            records = rec

            trendPoints = try prService.trend(for: exercise.id, limit: 24, context: modelContext)

            // Structured target (contains both display text + numeric goal)
            nextTarget = try prService.nextTarget(for: exercise.id, records: rec, context: modelContext)
        } catch {
            loadError = "Progress failed to load: \(error)"
            records = nil
            trendPoints = []
            nextTarget = nil
        }
    }

    // MARK: - History loading

    @MainActor
    private func loadHistory() async {
        // ✅ capture plain value outside the predicate macro
        let exId: UUID? = exercise.id

        do {
            let desc = FetchDescriptor<WorkoutSetLog>(
                predicate: #Predicate<WorkoutSetLog> { s in
                    s.completed == true &&
                    s.sessionExercise?.exerciseId == exId
                },
                sortBy: [SortDescriptor(\WorkoutSetLog.completedAt, order: .forward)]
            )
            history = try modelContext.fetch(desc).filter { $0.completedAt != nil }
        } catch {
            history = []
        }
    }

    // MARK: - Chart mapping

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let unit: String?
    }

    private func chartPoints(from sets: [WorkoutSetLog]) -> [Point] {
        return sets.compactMap { s in
            guard let d = s.completedAt else { return nil }
            switch exercise.modality {
            case .strength:
                return Point(date: d, value: s.weight ?? 0, unit: s.weightUnit.rawValue)
            case .timed, .cardio, .mobility:
                return Point(date: d, value: Double(s.reps ?? 0), unit: nil)
            }
        }
    }

    private func pointsCaption(_ points: [Point]) -> String {
        switch exercise.modality {
        case .strength:
            let unit = points.last?.unit ?? ""
            return unit.isEmpty ? AppFormatting.localized("Weight over time") : AppFormatting.localizedFormat("Weight over time (%@)", unit)
        case .timed:
            return AppFormatting.localized("Seconds over time")
        case .cardio:
            return AppFormatting.localized("Effort over time")
        case .mobility:
            return AppFormatting.localized("Reps/seconds over time")
        }
    }
    
    @MainActor
    private func applyNextTargetPrefill() {
        guard let t = nextTarget else { return }
        goalPrefill.set(.init(
            exerciseId: exercise.id,
            weight: t.targetWeight,
            reps: t.targetReps
        ))
    }
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppFormatting.localized("Equipment"))
                    .font(.headline)
                Spacer()
                Button {
                    showEquipmentEditor = true
                } label: {
                    Label(AppFormatting.localized("Edit"), systemImage: "tag")
                }
                .buttonStyle(.bordered)
            }

            if exercise.equipmentTags.isEmpty {
                Text(AppFormatting.localized("No equipment tags yet."))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exercise.equipmentTags, id: \.self) { tag in
                            TagChip(
                                label: EquipmentCatalog.label(for: tag),
                                systemImage: EquipmentCatalog.symbol(for: tag)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .sheet(isPresented: $showEquipmentEditor) {
            EquipmentTagsEditorSheet(
                title: exercise.name,
                initialTags: Set(exercise.equipmentTags),
                customLabels: customEquipmentLabels,
                onSave: { tags in
                    // Store canonical tags on the exercise
                    exercise.setEquipmentTags(Array(tags).sorted())
                    // SwiftData will persist changes automatically; no explicit save required here.
                }
            )
        }
    }

    private struct TagChip: View {
        let label: String
        let systemImage: String

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
        }
    }
    
    private var selectedIllustrationSet: ExerciseIllustrationSet {
        ExerciseIllustrationSet(rawValue: selectedIllustrationSetRaw) ?? .dummyV1
    }

    private var resolvedBundledAssetName: String? {
        let raw = exercise.mediaAssetName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // No stored value: try resolving by exercise display name.
        if raw.isEmpty {
            return ExerciseIllustrationCatalog.assetName(
                for: exercise.name,
                set: selectedIllustrationSet
            )
        }

        // New model: stored stable key like "back_squat".
        if let resolved = ExerciseIllustrationCatalog.assetName(
            forExerciseKey: raw,
            set: selectedIllustrationSet
        ) {
            return resolved
        }

        // Legacy/manual fallback:
        // if the stored value is already a concrete asset name, keep using it.
        return raw
    }
    
    private var resolvedIllustrationAssetName: String? {
        guard let stableKey = ExerciseIllustrationCatalog.stableKey(
            fromStoredMediaAssetName: exercise.mediaAssetName,
            exerciseName: exercise.name
        ) else {
            return nil
        }

        return ExerciseIllustrationCatalog.assetName(
            forExerciseKey: stableKey,
            set: selectedIllustrationSet
        )
    }
}

private struct EquipmentTagsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialTags: Set<String>
    let customLabels: [String]
    let onSave: (Set<String>) -> Void

    @State private var selected: Set<String>
    @State private var newTagLabel: String = ""

    init(
        title: String,
        initialTags: Set<String>,
        customLabels: [String],
        onSave: @escaping (Set<String>) -> Void
    ) {
        self.title = title
        self.initialTags = initialTags
        self.customLabels = customLabels
        self.onSave = onSave
        _selected = State(initialValue: initialTags)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(AppFormatting.localizedFormat("%lld selected", Int64(selected.count)))
                        .foregroundStyle(.secondary)
                }

                Section(AppFormatting.localized("Common")) {
                    ForEach(EquipmentCatalog.common) { item in
                        row(tag: item.id, label: item.label, symbol: item.symbol)
                    }
                }

                if !customLabels.isEmpty {
                    Section(AppFormatting.localized("Custom")) {
                        ForEach(customLabels.sorted(), id: \.self) { label in
                            let tag = EquipmentCatalog.slugify(label)
                            row(tag: tag, label: label, symbol: EquipmentCatalog.symbol(for: tag))
                        }
                    }
                }

                Section(AppFormatting.localized("Add tag")) {
                    HStack {
                        TextField(AppFormatting.localized("e.g. Dip Station"), text: $newTagLabel)
                        Button(AppFormatting.localized("Add")) {
                            let tag = EquipmentCatalog.slugify(newTagLabel)
                            guard !tag.isEmpty else { return }
                            selected.insert(tag)
                            newTagLabel = ""
                        }
                        .disabled(EquipmentCatalog.slugify(newTagLabel).isEmpty)
                    }
                    Text(AppFormatting.localized("Tags are stored as canonical keys (letters/numbers only)."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppFormatting.localized("Cancel")) { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppFormatting.localized("Save")) {
                        onSave(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func row(tag: String, label: String, symbol: String) -> some View {
        let isOn = selected.contains(tag)

        return Button {
            if isOn { selected.remove(tag) } else { selected.insert(tag) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 22)

                Text(label)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    private enum EquipmentTagCatalog {
        struct Item: Identifiable, Hashable {
            let id: String      // canonical tag (slug): "dumbbell"
            let label: String   // display: "Dumbbells"
            let symbol: String  // SF Symbol
        }

        static let common: [Item] = [
            .init(id: "dumbbell",   label: "Dumbbells",        symbol: "dumbbell.fill"),
            .init(id: "barbell",    label: "Barbell",          symbol: "figure.strengthtraining.traditional"),
            .init(id: "kettlebell", label: "Kettlebell",       symbol: "figure.strengthtraining.traditional"),
            .init(id: "plates",     label: "Weight Plates",    symbol: "circle.grid.3x3.fill"),

            .init(id: "bench",      label: "Bench",            symbol: "bed.double.fill"),
            .init(id: "pullupbar",  label: "Pull-up Bar",      symbol: "figure.pullup"),
            .init(id: "bands",      label: "Resistance Bands", symbol: "circle.dashed"),

            .init(id: "cable",      label: "Cable Machine",    symbol: "cable.connector"),
            .init(id: "smith",      label: "Smith Machine",    symbol: "square.split.2x2"),
            .init(id: "legpress",   label: "Leg Press",        symbol: "figure.strengthtraining.traditional"),

            .init(id: "treadmill",  label: "Treadmill",        symbol: "figure.run"),
            .init(id: "bike",       label: "Stationary Bike",  symbol: "bicycle"),
            .init(id: "rower",      label: "Rowing Machine",   symbol: "figure.rower")
        ]

        static func label(for tag: String) -> String {
            common.first(where: { $0.id == tag })?.label ?? tag
        }

        static func symbol(for tag: String) -> String {
            common.first(where: { $0.id == tag })?.symbol ?? "wrench.and.screwdriver"
        }

        /// "Pull-up Bar" -> "pullupbar"
        static func slugify(_ raw: String) -> String {
            let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return String(lower.filter { $0.isLetter || $0.isNumber })
        }
    }

    private struct EquipmentTagsEditorSheet: View {
        @Environment(\.dismiss) private var dismiss

        let title: String
        let initialTags: Set<String>
        let customLabels: [String]
        let onSave: (Set<String>) -> Void

        @State private var selected: Set<String>
        @State private var newTagLabel: String = ""

        init(
            title: String,
            initialTags: Set<String>,
            customLabels: [String],
            onSave: @escaping (Set<String>) -> Void
        ) {
            self.title = title
            self.initialTags = initialTags
            self.customLabels = customLabels
            self.onSave = onSave
            _selected = State(initialValue: initialTags)
        }

        var body: some View {
            NavigationStack {
                List {
                    Section {
                        Text(AppFormatting.localizedFormat("%lld selected", Int64(selected.count)))
                            .foregroundStyle(.secondary)
                    }

                    Section(AppFormatting.localized("Common")) {
                        ForEach(EquipmentTagCatalog.common) { item in
                            row(tag: item.id, label: item.label, symbol: item.symbol)
                        }
                    }

                    if !customLabels.isEmpty {
                        Section(AppFormatting.localized("Custom")) {
                            ForEach(customLabels.sorted(), id: \.self) { label in
                                let tag = EquipmentTagCatalog.slugify(label)
                                row(tag: tag, label: label, symbol: EquipmentTagCatalog.symbol(for: tag))
                            }
                        }
                    }

                    Section(AppFormatting.localized("Add tag")) {
                        HStack {
                            TextField(AppFormatting.localized("e.g. Dip Station"), text: $newTagLabel)
                            Button(AppFormatting.localized("Add")) {
                                let tag = EquipmentTagCatalog.slugify(newTagLabel)
                                guard !tag.isEmpty else { return }
                                selected.insert(tag)
                                newTagLabel = ""
                            }
                            .disabled(EquipmentTagCatalog.slugify(newTagLabel).isEmpty)
                        }

                        Text(AppFormatting.localized("Tags are stored as canonical keys (letters/numbers only)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(AppFormatting.localized("Cancel")) { dismiss() }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AppFormatting.localized("Save")) {
                            onSave(selected)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }

        private func row(tag: String, label: String, symbol: String) -> some View {
            let isOn = selected.contains(tag)

            return Button {
                if isOn { selected.remove(tag) } else { selected.insert(tag) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .frame(width: 22)

                    Text(label)

                    Spacer()

                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }
}

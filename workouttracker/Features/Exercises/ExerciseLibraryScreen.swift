import SwiftUI
import SwiftData

struct ExerciseLibraryScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Exercise.name, order: .forward)])
    private var allExercises: [Exercise]

    @State private var searchText: String = ""
    @State private var showArchived: Bool = false
    @State private var modalityFilter: ExerciseModality? = nil

    @State private var showNewExerciseSheet = false
    @State private var editingExercise: Exercise? = nil

    @AppStorage("profile.equipment.selected.v1") private var equipmentSelectedJSON: String = "[]"
    @State private var filterByEquipment: Bool = false

    // ✅ Equipment picked by the user (canonicalized so it matches Exercise.equipmentTags)
    private var selectedEquipmentTags: Set<String> {
        let raw: [String] = decode(equipmentSelectedJSON)
        return Set(raw.map(canonicalizeEquipmentTag).filter { !$0.isEmpty })
    }

    private var filtered: [Exercise] {
        allExercises
            .filter { showArchived ? true : !$0.isArchived }
            .filter {
                guard let modalityFilter else { return true }
                return $0.modality == modalityFilter
            }
            .filter {
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return true }
                return $0.name.localizedCaseInsensitiveContains(q)
            }
            .filter {
                // ✅ Equipment filter composed with existing filters
                guard filterByEquipment else { return true }
                let selected = selectedEquipmentTags
                guard !selected.isEmpty else { return true }
                return $0.matchesEquipmentFilter(selected)
            }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No exercises",
                    systemImage: "dumbbell",
                    description: Text("Create your first exercise to start building routines and tracking history.")
                )
            } else {
                ForEach(filtered) { ex in
                    NavigationLink {
                        ExerciseDetailScreen(exercise: ex)
                    } label: {
                        ExerciseRow(exercise: ex)
                    }
                    .contextMenu {
                        Button {
                            editingExercise = ex
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: ex.isArchived ? .cancel : .destructive) {
                            ex.isArchived.toggle()
                            ex.updatedAt = Date()
                            try? modelContext.save()
                        } label: {
                            Label(ex.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewExerciseSheet = true } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EquipmentPickerScreen()
                } label: {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .accessibilityLabel("Equipment")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button { filterByEquipment.toggle() } label: {
                    Image(systemName: filterByEquipment
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                // ✅ FIX: use the real property in scope
                .disabled(selectedEquipmentTags.isEmpty)
                .accessibilityLabel("Filter by equipment")
            }
        }
        .safeAreaInset(edge: .top) {
            filtersBar
                .padding(.horizontal)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showNewExerciseSheet) {
            NavigationStack {
                ExerciseEditorSheet(mode: .create)
            }
        }
        .sheet(item: $editingExercise) { ex in
            NavigationStack {
                ExerciseEditorSheet(mode: .edit(ex))
            }
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("All") { modalityFilter = nil }
                Divider()
                ForEach(ExerciseModality.allCases, id: \.self) { m in
                    Button(m.rawValue.capitalized) { modalityFilter = m }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(modalityFilter?.rawValue.capitalized ?? "All modalities")
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Toggle("Archived", isOn: $showArchived)
                .toggleStyle(.switch)
                .labelsHidden()

            Spacer()
        }
    }

    // MARK: - Equipment normalization (makes filter work even if picker stores display names)

    private func canonicalizeEquipmentTag(_ raw: String) -> String {
        let s = slugify(raw)

        // common plural -> singular
        let singular = s.hasSuffix("s") ? String(s.dropLast()) : s

        // map common display-ish values to canonical exercise tags
        switch singular {
        case "dumbbell", "dumbbellset": return "dumbbell"
        case "barbell": return "barbell"
        case "kettlebell": return "kettlebell"
        case "weightplate", "plate", "plates", "weightplates": return "plates"

        case "pullupbar", "pullup": return "pullupbar"
        case "resistanceband", "band", "bands": return "bands"
        case "bench": return "bench"

        case "cablemachine", "cable": return "cable"
        case "smithmachine", "smith": return "smith"
        case "legpress": return "legpress"

        case "treadmill": return "treadmill"
        case "stationarybike", "bike": return "bike"
        case "rowingmachine", "rower": return "rower"

        default:
            return singular
        }
    }

    private func slugify(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return String(lower.filter { $0.isLetter || $0.isNumber })
    }

    private func labelForEquipmentTag(_ tag: String) -> String {
        switch tag {
        case "dumbbell": return "Dumbbells"
        case "barbell": return "Barbell"
        case "kettlebell": return "Kettlebell"
        case "plates": return "Plates"
        case "bench": return "Bench"
        case "pullupbar": return "Pull-up Bar"
        case "bands": return "Bands"
        case "cable": return "Cable"
        case "smith": return "Smith"
        case "legpress": return "Leg Press"
        case "treadmill": return "Treadmill"
        case "bike": return "Bike"
        case "rower": return "Rower"
        default:
            return tag
        }
    }

    // MARK: - JSON helpers

    private func decode<T: Decodable>(_ s: String) -> T {
        guard let data = s.data(using: .utf8) else {
            return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8)))
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8))) }
    }
}

// MARK: - Row UI (chips)

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.headline)

                    Text(exercise.modality.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if exercise.isArchived {
                    Text("Archived")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            // ✅ Equipment chips (subtle + scroll if needed)
            if !exercise.equipmentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(exercise.equipmentTags.prefix(4), id: \.self) { tag in
                            Text(tagLabel(tag))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func tagLabel(_ tag: String) -> String {
        // Keep labels readable; if you add EquipmentCatalog later, swap to that.
        switch tag {
        case "dumbbell": return "Dumbbells"
        case "barbell": return "Barbell"
        case "kettlebell": return "Kettlebell"
        case "plates": return "Plates"
        case "bench": return "Bench"
        case "pullupbar": return "Pull-up Bar"
        case "bands": return "Bands"
        case "cable": return "Cable"
        case "smith": return "Smith"
        case "legpress": return "Leg Press"
        case "treadmill": return "Treadmill"
        case "bike": return "Bike"
        case "rower": return "Rower"
        default: return tag
        }
    }
}

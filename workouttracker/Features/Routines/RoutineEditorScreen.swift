import SwiftUI
import SwiftData

struct RoutineEditorScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var seedResultText: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "No routines yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create one later in Phase C. For now, seed demo routines to unblock workout sessions.")
                    )
                    .padding(.bottom, 12)

                    #if DEBUG
                    Button {
                        seed()
                    } label: {
                        Label("Seed Demo Routines", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    #endif

                } else {
                    List {
                        Section("Routines") {
                            ForEach(routines) { r in
                                HStack {
                                    Text(r.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        #if DEBUG
                        Section {
                            Button {
                                seed()
                            } label: {
                                Label("Seed Demo Routines (only if empty)", systemImage: "wand.and.stars")
                            }
                        }
                        #endif
                    }
                }
            }
            .navigationTitle("Routines")
            .alert("Seed Result", isPresented: Binding(
                get: { seedResultText != nil },
                set: { if !$0 { seedResultText = nil } }
            )) {
                Button("OK", role: .cancel) { seedResultText = nil }
            } message: {
                Text(seedResultText ?? "")
            }
        }
    }

    @MainActor
    private func seed() {
        do {
            let created = try RoutineSeeder.seedDemoRoutinesIfEmpty(context: modelContext)
            if created.isEmpty {
                seedResultText = "You already have routines — nothing was added."
            } else {
                seedResultText = "Created \(created.count) demo routine(s). You can now attach one to a Workout activity."
            }
        } catch {
            seedResultText = "Seeding failed: \(error)"
            assertionFailure("Seeding failed: \(error)")
        }
    }
}

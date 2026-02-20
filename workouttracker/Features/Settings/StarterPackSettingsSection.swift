import SwiftUI
import SwiftData

// File: workouttracker/Features/Settings/StarterPackSettingsSection.swift
//
// Lets users re-import the curated Starter Pack if they deleted everything.
// Idempotent: importing won't duplicate routines/exercises by name.

@MainActor
struct StarterPackSettingsSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showConfirm = false
    @State private var showResult = false
    @State private var resultMessage: String = ""

    var body: some View {
        Section("Starter Pack") {
            Text("Import a curated set of common exercises and a few starter routines. Safe to run multiple times.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                showConfirm = true
            } label: {
                Label("Import Starter Pack", systemImage: "square.and.arrow.down")
            }
            .confirmationDialog("Import Starter Pack?", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("Import") {
                    do {
                        resultMessage = try RoutineSeeder.importStarterPack(context: modelContext)
                    } catch {
                        resultMessage = "Import failed: \(error.localizedDescription)"
                    }
                    showResult = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Starter Pack", isPresented: $showResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resultMessage)
            }
        }
    }
}

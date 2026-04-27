import SwiftUI
import SwiftData

struct ProgramAssignmentScreen: View {
    let program: TrainingProgram

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var anchorStrategy: ProgramScheduleAnchorStrategy = .calendarAligned
    @State private var savedAssignment: ProgramAssignment?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        List {
            Section(String(localized: "Assignment", defaultValue: "Assignment")) {
                DatePicker(
                    String(localized: "Start date", defaultValue: "Start date"),
                    selection: $startDate,
                    displayedComponents: .date
                )

                Picker(String(localized: "Schedule anchor", defaultValue: "Schedule anchor"), selection: $anchorStrategy) {
                    Text(String(localized: "Calendar aligned", defaultValue: "Calendar aligned"))
                        .tag(ProgramScheduleAnchorStrategy.calendarAligned)
                    Text(String(localized: "Sequential", defaultValue: "Sequential"))
                        .tag(ProgramScheduleAnchorStrategy.sequential)
                }
            }

            Section(String(localized: "What this does", defaultValue: "What this does")) {
                Text(String(localized: "Assigning a program tracks runtime progress and recommendations. Scheduled workout follow-up still happens from Calendar.", defaultValue: "Assigning a program tracks runtime progress and recommendations. Scheduled workout follow-up still happens from Calendar."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let savedAssignment {
                Section {
                    NavigationLink {
                        ProgramProgressScreen(program: program, assignmentID: savedAssignment.id)
                    } label: {
                        Label(String(localized: "Open program progress", defaultValue: "Open program progress"), systemImage: "chart.bar.doc.horizontal")
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Assign Program", defaultValue: "Assign Program"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Close", defaultValue: "Close")) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Assign", defaultValue: "Assign")) {
                    assignProgram()
                }
            }
        }
        .alert(String(localized: "Error", defaultValue: "Error"), isPresented: $showError) {
            Button(String(localized: "OK", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "Unknown error.", defaultValue: "Unknown error."))
        }
    }

    private func assignProgram() {
        do {
            let assignment = try ProgramAssignmentService.activateProgram(
                program,
                startDate: startDate,
                anchorStrategy: anchorStrategy,
                context: modelContext
            )
            savedAssignment = assignment
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }
}

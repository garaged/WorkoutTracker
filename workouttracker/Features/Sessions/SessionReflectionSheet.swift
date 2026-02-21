import SwiftUI
import SwiftData

struct SessionReflectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable private var session: WorkoutSession
    private let service: SessionReflectionService

    @State private var selectedMood: SessionReflectionMood?
    @State private var noteText: String

    @State private var showError = false
    @State private var errorMessage = ""

    init(
        session: WorkoutSession,
        service: SessionReflectionService = SessionReflectionService()
    ) {
        self._session = Bindable(session)
        self.service = service
        _selectedMood = State(initialValue: session.reflectionMood)
        _noteText = State(initialValue: session.reflectionNote ?? "")
    }

    private var canSave: Bool {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedMood != nil || !trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    moodCard
                    noteCard

                    if session.reflectionMood != nil || (session.reflectionNote?.isEmpty == false) {
                        clearCard
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }   // <- key to “never blocks logging flow”
                        .accessibilityIdentifier("SessionReflection.NotNow")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("SessionReflection.Save")
                        .disabled(!canSave)
                }
            }
            .alert("Couldn’t Save", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("How did it go?")
                    .font(.title3.weight(.semibold))
                Text("Optional. A quick mood + note makes it fun to look back later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var moodCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(SessionReflectionMood.allCases) { mood in
                        MoodChip(
                            title: mood.title,
                            emoji: mood.emoji,
                            isSelected: selectedMood == mood
                        ) {
                            if selectedMood == mood {
                                selectedMood = nil
                            } else {
                                selectedMood = mood
                            }
                        }
                        .accessibilityIdentifier("SessionReflection.Mood.\(mood.rawValue)")
                    }
                }
            }
        }
    }

    private var noteCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(.headline)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $noteText)
                        .accessibilityIdentifier("SessionReflection.Note")
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Sleep, energy, what felt strong, what to fix next time…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var clearCard: some View {
        Card {
            Button(role: .destructive) {
                clear()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Reflection")
                    Spacer()
                }
                .font(.headline)
            }
        }
    }

    // MARK: - Actions

    private func save() {
        do {
            try service.saveReflection(
                for: session,
                mood: selectedMood,
                note: noteText,
                in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = String(describing: error)
            showError = true
        }
    }

    private func clear() {
        do {
            try service.clearReflection(for: session, in: modelContext)
            selectedMood = nil
            noteText = ""
        } catch {
            errorMessage = String(describing: error)
            showError = true
        }
    }
}

// MARK: - UI Helpers

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1)
            }
    }
}

private struct MoodChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.ultraThinMaterial))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) mood")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

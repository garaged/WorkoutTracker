import SwiftUI
import SwiftData

struct TrackedActivityHistoryRow: View {
    let session: TrackedActivitySession

    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDeleteConfirmation = false
    @State private var deleteFailureMessage: String?

    private let summaryBuilder = TrackedActivitySummaryBuilder()
    private let recorder = TrackedActivityRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Label(session.activityKind.displayName, systemImage: session.activityKind.systemImage)
                    .font(.headline)

                Spacer(minLength: 8)

                Text(session.lifecycleState.badgeText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(badgeColor)
            }

            HStack(spacing: 8) {
                if let startedAt = session.startedAt {
                    Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if session.healthKitExportState == .failed {
                    Label(String(localized: "activities.history.export_failed", defaultValue: "Apple Health save failed"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if session.healthKitExportState == .pending {
                    Label(String(localized: "activities.history.export_pending", defaultValue: "Apple Health save pending"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if session.healthKitExportState == .exported && session.hasLocalChangesSinceHealthKitExport {
                    Label(String(localized: "activities.history.export_local_changes", defaultValue: "Local edits differ from Health"), systemImage: "pencil.and.outline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let metrics = summaryBuilder.metrics(for: session)
                .filter { $0.kind != .state }
                .prefix(3)

            if !metrics.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(metrics)) { metric in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(metric.value)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            } else {
                Text(String(localized: "activities.history.low_data", defaultValue: "No additional metrics were recorded for this activity."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("TrackedActivity.HistoryRow.\(session.id.uuidString)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if session.allowsLocalDeletion {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label(session.localDeleteActionTitle, systemImage: "trash")
                }
                .accessibilityIdentifier("TrackedActivity.HistoryRow.Delete.\(session.id.uuidString)")
            }
        }
        .contextMenu {
            if session.allowsLocalDeletion {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label(session.localDeleteActionTitle, systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            session.localDeleteTitle,
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(session.localDeleteActionTitle, role: .destructive) {
                deleteActivity()
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(session.localDeleteMessage)
        }
        .alert(
            session.localDeleteFailureTitle,
            isPresented: Binding(
                get: { deleteFailureMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteFailureMessage = nil
                    }
                }
            ),
            actions: {
                Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
            },
            message: {
                Text(deleteFailureMessage ?? session.localDeleteFailureMessage)
            }
        )
    }

    private var badgeColor: Color {
        switch session.lifecycleState {
        case .inProgress:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .blue
        case .discarded, .planned:
            return .secondary
        }
    }

    private func deleteActivity() {
        do {
            try recorder.delete(session, context: modelContext)
        } catch {
            deleteFailureMessage = error.localizedDescription
        }
    }
}

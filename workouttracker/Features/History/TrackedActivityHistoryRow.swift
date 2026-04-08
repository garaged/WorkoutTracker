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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(kindTint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: session.activityKind.systemImage)
                        .foregroundStyle(kindTint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(session.activityKind.displayName)
                            .font(.headline)
                        Spacer(minLength: 8)
                        Text(session.lifecycleState.badgeText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(badgeColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(badgeColor)
                    }

                    if let startedAt = session.startedAt {
                        Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    metadataChips
                }
                VStack(alignment: .leading, spacing: 8) {
                    metadataChips
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
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            } else {
                Text(lowDataMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }
        }
        .padding(.vertical, 6)
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

    @ViewBuilder
    private var metadataChips: some View {
        chip(title: session.environment.displayName, systemImage: session.environment == .outdoor ? "sun.max" : "house")

        if session.hasRecordedRoute {
            chip(
                title: String(localized: "activities.history.route_recorded", defaultValue: "Route recorded"),
                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
            )
        }

        if let exportChip {
            chip(title: exportChip.title, systemImage: exportChip.systemImage, tint: exportChip.tint)
        }
    }

    private var exportChip: (title: String, systemImage: String, tint: Color)? {
        if session.healthKitExportState == .failed {
            return (
                String(localized: "activities.history.export_failed", defaultValue: "Apple Health save failed"),
                "exclamationmark.triangle.fill",
                .orange
            )
        }

        if session.healthKitExportState == .pending {
            return (
                String(localized: "activities.history.export_pending", defaultValue: "Apple Health save pending"),
                "arrow.triangle.2.circlepath",
                .secondary
            )
        }

        if session.healthKitExportState == .exported && session.hasLocalChangesSinceHealthKitExport {
            return (
                String(localized: "activities.history.export_local_changes", defaultValue: "Local edits differ from Health"),
                "pencil.and.outline",
                .secondary
            )
        }

        return nil
    }

    private func chip(title: String, systemImage: String, tint: Color = .secondary) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
    }

    private var lowDataMessage: String {
        if session.activityKind.supportsDistance {
            return String(
                localized: "activities.history.low_data.distance_capable",
                defaultValue: "Only time was recorded for this activity. Distance and route details were not available."
            )
        }

        return String(
            localized: "activities.history.low_data",
            defaultValue: "No additional metrics were recorded for this activity."
        )
    }

    private var kindTint: Color {
        switch session.activityKind {
        case .walking: return .green
        case .running: return .orange
        case .hiking: return .brown
        case .yoga: return .purple
        }
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

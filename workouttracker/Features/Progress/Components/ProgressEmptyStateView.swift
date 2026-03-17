import SwiftUI

struct ProgressEmptyStateView: View {
    enum Kind: Equatable {
        case noWorkouts
        case lowData(message: String)
        case sectionUnavailable(title: String, message: String)
    }

    let kind: Kind
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
            }
            .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary)
        )
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch kind {
        case .noWorkouts:
            return "No completed workouts yet"
        case .lowData:
            return "Progress is starting to build"
        case .sectionUnavailable(let title, _):
            return title
        }
    }

    private var message: String {
        switch kind {
        case .noWorkouts:
            return "Finish a few workouts and this dashboard will start showing strength, volume, consistency, and efficiency trends."
        case .lowData(let message):
            return message
        case .sectionUnavailable(_, let message):
            return message
        }
    }

    private var systemImage: String {
        switch kind {
        case .noWorkouts:
            return "chart.line.downtrend.xyaxis"
        case .lowData:
            return "chart.bar.xaxis"
        case .sectionUnavailable:
            return "exclamationmark.circle"
        }
    }
}

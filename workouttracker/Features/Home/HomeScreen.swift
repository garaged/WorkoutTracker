import SwiftUI

/// Simple model describing a Home tile.
/// We store the destination as `AnyView` so AppRoot can wire whatever screens you already have.
struct HomeTile: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let destination: () -> AnyView
}

struct HomeScreen: View {
    let tiles: [HomeTile]
    var onResumeSession: (WorkoutSession) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: AdaptiveLayoutMetrics.shouldUseSingleColumnHomeTiles(dynamicTypeSize: dynamicTypeSize) ? 260 : 160), spacing: 14)]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    ActiveSessionsSection(onResume: onResumeSession)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(tiles) { tile in
                            NavigationLink {
                                tile.destination()
                            } label: {
                                HomeTileCard(tile: tile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)

                    Text(AppFormatting.localized("Tip: Long-press tiles later for quick actions (e.g., “Start workout”, “Add exercise”)."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .padding(16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppFormatting.localized("Workout Tracker"))
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                settingsLink
            }
        }
    }

    private var settingsLink: some View {
        NavigationLink {
            SettingsScreen()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIconControl(
            label: AccessibilityLabels.Buttons.settings,
            hint: AccessibilityLabels.Buttons.settingsHint,
            identifier: UIAccessibilityIdentifiers.Settings.toolbarLink
        )
    }
}

private struct HomeTileCard: View {
    let tile: HomeTile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: tile.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tile.tint)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Text(tile.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(tile.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 156 : 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
        .shadow(radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tile.title). \(tile.subtitle)")
    }
}

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

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 160), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background that looks good in light/dark mode.
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

                        Text("Tip: Long-press tiles later for quick actions (e.g., “Start workout”, “Add exercise”).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Workout Tracker")
                .font(.largeTitle.bold())

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HomeTileCard: View {
    let tile: HomeTile

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

            Text(tile.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(height: 130)
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

import SwiftUI

struct EventDetailView: View {
    let event: PoGoEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image
                if let imageURL = event.image {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 200)
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // Title + type
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.name)
                        .font(Theme.Fonts.manrope(22, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    HStack(spacing: 8) {
                        Text(event.eventType)
                            .font(Theme.Fonts.manrope(11, weight: .bold))
                            .foregroundStyle(Theme.Colors.cardRose)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.cardRose.opacity(0.15), in: .capsule)

                        if let start = event.start, let end = event.end {
                            Text("\(start) → \(end)")
                                .font(Theme.Fonts.manrope(12))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                }

                // Heading
                if let heading = event.heading {
                    Text(heading)
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Source link
                if let link = event.link, let url = URL(string: link) {
                    Link(destination: url) {
                        HStack {
                            Text("View on LeekDuck")
                                .font(Theme.Fonts.manrope(13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundStyle(Theme.Colors.cardRose)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.cardRose.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: PoGoEvent(
            eventID: "1",
            name: "Pokémon GO Fest 2026",
            eventType: "Global Event",
            heading: "Catch rare Pokémon worldwide!",
            link: "https://leekduck.com",
            image: nil,
            start: "2026-09-15",
            end: "2026-09-17"
        ))
    }
}

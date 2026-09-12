import SwiftUI

struct EventDetailView: View {
    let event: PoGoEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image
                if let imageURL = event.image {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 220)
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Theme.Colors.surface1, .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 80),
                        alignment: .bottom
                    )
                } else {
                    Rectangle()
                        .fill(Theme.Colors.surface1)
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            Text(event.eventType)
                                .font(Theme.Fonts.manrope(14, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textMuted)
                        )
                }

                // Event name
                Text(event.name)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Meta row
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.eventType)
                        .font(Theme.Fonts.manrope(11, weight: .bold))
                        .foregroundStyle(Theme.Colors.cardRose)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.cardRose.opacity(0.15), in: .capsule)

                    if let start = event.start, let end = event.end {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("\(start)  →  \(end)")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted)
                    }
                }

                // Description
                if let heading = event.heading {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .foregroundStyle(Theme.Colors.borderSubtle)

                        Text(heading)
                            .font(Theme.Fonts.manrope(17, weight: .regular))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 20)
                    }
                }

                // CTA
                if let link = event.link, let url = URL(string: link) {
                    Link(destination: url) {
                        HStack {
                            Text("View on LeekDuck")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardRose)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.cardRose.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .glanceBackground()
        .navigationTitle(event.eventType)
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

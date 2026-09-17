import SwiftUI

struct EventDetailView: View {
    let event: PoGoEvent
    @State private var eventDescription = ""
    @State private var isLoadingDescription = false

    private var intelligenceContent: String {
        var parts = [event.name, event.eventType]
        if let heading = event.heading { parts.append(heading) }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image
                if let imageURL = event.image {
                    CachedAsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Theme.Colors.surface2)
                            .frame(height: 220)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                            .shimmer()
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))
                    .overlay(
                        LinearGradient(
                            colors: [Theme.Colors.surface1.opacity(0.8), .clear],
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
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))
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

                // Meta card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(event.eventTypeLabel)
                            .font(Theme.Fonts.manrope(11, weight: .bold))
                            .foregroundStyle(Theme.Colors.cardRose)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.cardRose.opacity(0.15), in: .capsule)

                        if let start = event.start, let end = event.end {
                            let countdown = TimeFormat.smartCountdown(start: start, end: end)
                            if !countdown.isEmpty {
                                Text(countdown)
                                    .font(Theme.Fonts.manrope(11, weight: .medium))
                                    .foregroundStyle(Theme.Colors.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Theme.Colors.success.opacity(0.15), in: .capsule)
                            }
                        }
                    }

                    if let start = event.start, let end = event.end {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(TimeFormat.localTimeRange(start: start, end: end))
                        }
                        .font(Theme.Fonts.manrope(14, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted)
                    }

                    if event.status == .ongoing, let start = event.start, let end = event.end {
                        let progress = TimeFormat.eventProgress(start: start, end: end)
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.Colors.textMuted.opacity(0.2))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.Colors.success)
                                        .frame(width: geo.size.width * progress, height: 4)
                                }
                            }
                            .frame(height: 4)
                            Text("\(Int(progress * 100))% elapsed")
                                .font(Theme.Fonts.manrope(10))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                }
                .padding(Theme.cardPadding)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

                // Description card
                if isLoadingDescription {
                    ProgressView()
                        .padding(Theme.cardPadding)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                } else if !eventDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)
                        Text(eventDescription)
                            .font(Theme.Fonts.manrope(14, weight: .regular))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                // AI Intelligence Card
                ArticleIntelligenceCard(
                    content: intelligenceContent,
                    type: .poGoEvent,
                    accentColor: Theme.Colors.cardRose
                )

                // Raw content card
                if let heading = event.heading {
                    RawArticleCard(headerTitle: "FULL DETAILS") {
                        Text(heading)
                            .font(Theme.Fonts.manrope(17, weight: .regular))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
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
                        .background(Theme.Colors.cardRose.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .glanceBackground()
        .navigationTitle(event.eventType)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard eventDescription.isEmpty, let link = event.link else { return }
            isLoadingDescription = true
            eventDescription = (try? await ScrapedDuckClient().fetchEventDescription(from: link)) ?? ""
            isLoadingDescription = false
        }
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

import SwiftUI

struct MatchTimelineView: View {
    let items: [MatchTimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MATCH TIMELINE")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.cardAmber)
                .tracking(1.2)
                .padding(.bottom, 16)

            HStack(alignment: .top, spacing: 16) {
                // Connector line + dots
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Circle()
                            .fill(dotColor(for: item))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .fill(Theme.Colors.surface1)
                                    .frame(width: 6, height: 6)
                            )

                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Theme.Colors.textMuted.opacity(0.3))
                                .frame(width: 2)
                                .frame(minHeight: 80)
                        }
                    }
                }

                // Match cards
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        matchCard(item)
                            .padding(.bottom, index < items.count - 1 ? 16 : 0)
                    }
                }
            }
        }
    }

    // MARK: - Match Card

    private func matchCard(_ item: MatchTimelineItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 4) {
                    teamBadge(url: item.rmBadge, fallback: "RM", size: 40)
                    Text("Real Madrid")
                        .font(Theme.Fonts.manrope(9))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                if item.isFinished, let h = item.homeScore, let a = item.awayScore {
                    VStack(spacing: 2) {
                        Text("\(h) - \(a)")
                            .font(Theme.Fonts.manrope(20, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                } else {
                    Text("vs")
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                VStack(spacing: 4) {
                    teamBadge(url: item.opponentBadge, fallback: String(item.opponent.prefix(3)).uppercased(), size: 40)
                    Text(item.opponent)
                        .font(Theme.Fonts.manrope(9))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.competition)
                    if let round = item.round {
                        Text("·")
                        Text(round)
                    }
                }
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)

                if let date = MadridPipeline.looseDateParse(item.datetime) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(TimeFormat.istDate(date))
                    }
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                if !item.venue.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns")
                        Text(item.venue)
                    }
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                }
            }

            if item.isFinished, let result = item.result {
                resultBadge(result)
            } else if let date = MadridPipeline.looseDateParse(item.datetime) {
                let countdown = TimeFormat.countdownTo(date)
                if !countdown.isEmpty {
                    Text(countdown)
                        .font(Theme.Fonts.manrope(11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.cardAmber.opacity(0.15), in: .capsule)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func teamBadge(url: String?, fallback: String, size: CGFloat) -> some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(fallback)
                        .font(Theme.Fonts.manrope(14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            } else {
                Text(fallback)
                    .font(Theme.Fonts.manrope(14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: size, height: size)
                    .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: size, height: size)
    }

    private func resultBadge(_ result: String) -> some View {
        Text(result)
            .font(Theme.Fonts.manrope(11, weight: .bold))
            .foregroundStyle(resultColor(result))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(resultColor(result).opacity(0.15), in: .capsule)
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "W": return Theme.Colors.success
        case "D": return Theme.Colors.warning
        case "L": return Theme.Colors.error
        default: return Theme.Colors.textMuted
        }
    }

    private func dotColor(for item: MatchTimelineItem) -> Color {
        if item.isFinished {
            switch item.result {
            case "W": return Theme.Colors.success
            case "D": return Theme.Colors.warning
            case "L": return Theme.Colors.error
            default: return Theme.Colors.textMuted
            }
        }
        return Theme.Colors.cardAmber
    }
}

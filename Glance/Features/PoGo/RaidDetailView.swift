import SwiftUI

struct RaidDetailView: View {
    let raid: PoGoRaid

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero
                VStack(alignment: .leading, spacing: 12) {
                    AsyncImage(url: URL(string: raid.image ?? "")) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text(String(raid.name.prefix(2)))
                            .font(Theme.Fonts.manrope(32, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))

                    HStack {
                        Text(raid.name)
                            .font(Theme.Fonts.manrope(22, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if raid.canBeShiny {
                            Text("✨ Shiny")
                                .font(Theme.Fonts.manrope(11, weight: .medium))
                                .foregroundStyle(Theme.Colors.cardRose)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.cardRose.opacity(0.15), in: .capsule)
                        }
                    }

                    // Tier badge
                    Text(tierText)
                        .font(Theme.Fonts.manrope(12, weight: .bold))
                        .foregroundStyle(tierColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tierColor.opacity(0.15), in: .capsule)
                }

                // Types
                if !raid.types.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TYPES")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        HStack(spacing: 8) {
                            ForEach(raid.types, id: \.name) { type in
                                HStack(spacing: 4) {
                                    AsyncImage(url: URL(string: type.image)) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Circle().fill(Theme.Colors.surface3)
                                    }
                                    .frame(width: 20, height: 20)

                                    Text(type.name)
                                        .font(Theme.Fonts.manrope(12))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.surface2, in: .capsule)
                            }
                        }
                    }
                }

                // Combat Power
                if let cp = raid.combatPower {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COMBAT POWER")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        HStack(spacing: 20) {
                            if let normal = cp.normal {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Normal")
                                        .font(Theme.Fonts.manrope(12))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text("\(normal.min ?? 0) – \(normal.max ?? 0)")
                                        .font(Theme.Fonts.manrope(18, weight: .bold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                            }

                            if let boosted = cp.boosted {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Weather Boosted")
                                        .font(Theme.Fonts.manrope(12))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                    Text("\(boosted.min ?? 0) – \(boosted.max ?? 0)")
                                        .font(Theme.Fonts.manrope(18, weight: .bold))
                                        .foregroundStyle(Theme.Colors.cardRose)
                                }
                            }
                        }
                    }
                }

                // Weather Boost
                if let weather = raid.boostedWeather, !weather.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WEATHER BOOST")
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        HStack(spacing: 8) {
                            ForEach(weather, id: \.name) { w in
                                HStack(spacing: 4) {
                                    AsyncImage(url: URL(string: w.image)) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Circle().fill(Theme.Colors.surface3)
                                    }
                                    .frame(width: 16, height: 16)

                                    Text(w.name)
                                        .font(Theme.Fonts.manrope(12))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle(raid.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tierText: String {
        if raid.isMega { return "MEGA RAID" }
        if raid.isShadow { return "SHADOW 5★ RAID" }
        if raid.tier.contains("5-Star") { return "5-STAR RAID" }
        if raid.tier.contains("3-Star") { return "3-STAR RAID" }
        if raid.tier.contains("1-Star") { return "1-STAR RAID" }
        return raid.tier.uppercased()
    }

    private var tierColor: Color {
        if raid.isMega { return Theme.Colors.tierPurple }
        if raid.isShadow { return Theme.Colors.error }
        if raid.isFiveStar { return Theme.Colors.cardRose }
        return Theme.Colors.textMuted
    }
}

#Preview {
    NavigationStack {
        RaidDetailView(raid: PoGoRaid(
            name: "Dialga",
            tier: "5-Star Raids",
            canBeShiny: true,
            types: [.init(name: "Dragon", image: ""), .init(name: "Steel", image: "")],
            combatPower: .init(normal: .init(min: 1974, max: 2062), boosted: .init(min: 2468, max: 2578)),
            boostedWeather: [.init(name: "Snow", image: "")],
            image: nil
        ))
    }
}

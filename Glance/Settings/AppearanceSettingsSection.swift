import SwiftUI

struct AppearanceSettingsSection: View {
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage("colorScheme") private var colorScheme = "dark"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("APPEARANCE")

            HStack(spacing: 8) {
                appearanceOption("Dark", value: "dark", icon: "moon.fill")
                appearanceOption("Light", value: "light", icon: "sun.max.fill")
                appearanceOption("System", value: "system", icon: "circle.lefthalf.filled")
            }

            themePickerSection
        }
        .padding(.top, 4)
    }

    private var themePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("THEME")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(ThemeRegistry.all) { theme in
                    themeCard(theme)
                }
            }
        }
    }

    private func themeCard(_ theme: ThemeDefinition) -> some View {
        let selected = themeManager.selectedID == theme.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                themeManager.select(id: theme.id)
            }
        } label: {
            VStack(spacing: 8) {
                Text(theme.name)
                    .font(Theme.Fonts.manrope(11, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    ForEach(Array(theme.previewSwatches.enumerated()), id: \.offset) { _, swatch in
                        Circle()
                            .fill(swatch)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().stroke(Theme.Colors.borderSubtle, lineWidth: 0.5)
                            )
                    }
                }

                if theme.colorSchemeOverride == .light {
                    Text("Light")
                        .font(Theme.Fonts.manrope(9, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.surface3, in: .capsule)
                } else {
                    Text(" ")
                        .font(Theme.Fonts.manrope(9))
                        .frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                selected ? Theme.Colors.accent.opacity(0.12) : Theme.Colors.surface1,
                in: RoundedRectangle(cornerRadius: Theme.Radius.small)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(selected ? Theme.Colors.accent : Theme.Colors.borderSubtle, lineWidth: selected ? 1.5 : 1)
            )
        }
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func appearanceOption(_ label: String, value: String, icon: String) -> some View {
        Button {
            withAnimation { colorScheme = value }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(Theme.Fonts.manrope(11, weight: .medium))
            }
            .foregroundStyle(colorScheme == value ? Theme.Colors.accent : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                colorScheme == value ? Theme.Colors.accent.opacity(0.15) : Theme.Colors.surface1,
                in: RoundedRectangle(cornerRadius: Theme.Radius.small)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(colorScheme == value ? Theme.Colors.accent : .clear, lineWidth: 1.5)
            )
        }
        .accessibilityLabel("\(label) mode")
        .accessibilityAddTraits(colorScheme == value ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            AppearanceSettingsSection()
        }
    }
    .environment(ThemeManager.shared)
}

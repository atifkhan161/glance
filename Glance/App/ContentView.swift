import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var store = PulseStore()

    var body: some View {
        @Bindable var bindable = appState
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $bindable.selectedTab) {
                Tab(value: GlanceTab.pulse) {
                    NavigationStack {
                        PulseView(store: store)
                    }
                }

                Tab(value: GlanceTab.madrid) {
                    NavigationStack {
                        MadridHubView(store: store)
                    }
                }

                Tab(value: GlanceTab.pogo) {
                    NavigationStack {
                        PoGoHubView(store: store)
                    }
                }

                Tab(value: GlanceTab.github) {
                    NavigationStack {
                        GitHubHubView(store: store)
                    }
                }

                Tab(value: GlanceTab.sources) {
                    NavigationStack {
                        SourcesView()
                    }
                }

                Tab(value: GlanceTab.settings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
            }

            // Floating pill dock
            floatingDock(selection: $bindable.selectedTab)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Floating Pill Dock

    private func floatingDock(selection: Binding<GlanceTab>) -> some View {
        HStack(spacing: 4) {
            ForEach(GlanceTab.allCases, id: \.self) { tab in
                dockButton(tab, selection: selection)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.Colors.borderSubtle.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.cardEmerald.opacity(selection.wrappedValue == .pulse ? 0.3 : 0), radius: 12, y: 4)
        .padding(.horizontal, 40)
    }

    private func dockButton(_ tab: GlanceTab, selection: Binding<GlanceTab>) -> some View {
        let isSelected = selection.wrappedValue == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection.wrappedValue = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? tab.accentColor : Theme.Colors.textMuted)
                    .frame(width: 44, height: 28)
                    .background(
                        isSelected ? tab.accentColor.opacity(0.15) : .clear,
                        in: Capsule()
                    )

                Text(tab.shortLabel)
                    .font(Theme.Fonts.manrope(9, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? tab.accentColor : Theme.Colors.textMuted)
            }
        }
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - GlanceTab Extensions

extension GlanceTab {
    var icon: String {
        switch self {
        case .pulse: "bolt.fill"
        case .madrid: "sportscourt"
        case .pogo: "gamecontroller.fill"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .sources: "key"
        case .settings: "gearshape.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .pulse: "Feed"
        case .madrid: "Madrid"
        case .pogo: "PoGo"
        case .github: "GitHub"
        case .sources: "Keys"
        case .settings: "Settings"
        }
    }

    var accentColor: Color {
        switch self {
        case .pulse: Theme.Colors.cardEmerald
        case .madrid: Theme.Colors.cardAmber
        case .pogo: Theme.Colors.cardRose
        case .github: Theme.Colors.cardEmerald
        case .sources: Theme.Colors.textMuted
        case .settings: Theme.Colors.textMuted
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .pulse: "Pulse feed"
        case .madrid: "Real Madrid"
        case .pogo: "Pokemon Go"
        case .github: "GitHub trending"
        case .sources: "API sources"
        case .settings: "Settings"
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}

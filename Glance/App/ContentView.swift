import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var store = PulseStore()
    @State private var scrollCoordinator = ScrollCoordinator()
    @Namespace private var dockNamespace

    var body: some View {
        @Bindable var bindable = appState
        ZStack(alignment: .bottom) {
            // Tab content (no TabView — avoids system tab bar)
            Group {
                switch bindable.selectedTab {
                case .pulse:
                    NavigationStack(path: $bindable.pulsePath) { PulseView(store: store) }
                        .tint(Theme.Colors.accent)
                case .madrid:
                    NavigationStack(path: $bindable.madridPath) { MadridHubView(store: store) }
                        .tint(Theme.Colors.accent)
                case .pogo:
                    NavigationStack(path: $bindable.pogoPath) { PoGoHubView(store: store) }
                        .tint(Theme.Colors.accent)
                case .github:
                    NavigationStack(path: $bindable.githubPath) { GitHubHubView(store: store) }
                        .tint(Theme.Colors.accent)
                case .sources:
                    NavigationStack(path: $bindable.sourcesPath) { SourcesView() }
                        .tint(Theme.Colors.accent)
                case .settings:
                    NavigationStack(path: $bindable.settingsPath) { SettingsView() }
                        .tint(Theme.Colors.accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating pill dock
            floatingDock(selection: $bindable.selectedTab)
                .padding(.bottom, 8)
                .offset(y: scrollCoordinator.dockHidden ? 80 : 0)
                .opacity(scrollCoordinator.dockHidden ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: scrollCoordinator.dockHidden)
        }
        .ignoresSafeArea(.keyboard)
        .environment(scrollCoordinator)
    }

    // MARK: - Floating Pill Dock

    private func floatingDock(selection: Binding<GlanceTab>) -> some View {
        HStack(spacing: 4) {
            ForEach(GlanceTab.allCases, id: \.self) { tab in
                dockButton(tab, selection: selection)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Group {
                if #available(iOS 26, *) {
                    Capsule()
                        .glassEffect()
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            Capsule()
                .stroke(Theme.Colors.borderSubtle.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: selection.wrappedValue.accentColor.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, 40)
    }

    private func dockButton(_ tab: GlanceTab, selection: Binding<GlanceTab>) -> some View {
        let isSelected = selection.wrappedValue == tab

        return Button {
            scrollCoordinator.onDockTapped()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.selectTab(tab)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? tab.accentColor : Theme.Colors.textSecondary)
                    .frame(width: 48, height: 32)
                    .background(
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(tab.accentColor.opacity(0.15))
                                    .matchedGeometryEffect(id: "dockPill", in: dockNamespace)
                            }
                        }
                    )

                Text(tab.shortLabel)
                    .font(Theme.Fonts.manrope(isSelected ? 11 : 9, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? tab.accentColor : Theme.Colors.textSecondary)
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

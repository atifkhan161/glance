import SwiftUI

struct CardOrderListView: View {
    let settingsStore: SettingsStore

    private struct CardOrderItem: Identifiable {
        let id: String
        let title: String
        let icon: String
        let accent: Color
    }

    private var items: [CardOrderItem] {
        settingsStore.normalizeCardOrder(settingsStore.cardOrder).compactMap { key in
            if let card = CardID(rawValue: key) {
                return CardOrderItem(id: key, title: card.badgeLabel, icon: card.icon, accent: card.accentColor)
            }
            if key.hasPrefix(SettingsStore.customOrderPrefix) {
                let feedID = String(key.dropFirst(SettingsStore.customOrderPrefix.count))
                guard let feed = settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID }) else {
                    return nil
                }
                return CardOrderItem(id: key, title: feed.name, icon: "dot.rss", accent: Theme.Colors.cardAmber)
            }
            return nil
        }
    }

    var body: some View {
        List {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(item.accent)
                        .frame(width: 24)

                    Text(item.title)
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()
                }
                .padding(.vertical, 4)
                .listRowBackground(Theme.Colors.surface1)
            }
            .onMove(perform: move)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .scrollDisabled(true)
        .frame(height: CGFloat(max(items.count, 1)) * 52 + 8)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func move(from source: IndexSet, to destination: Int) {
        var order = settingsStore.normalizeCardOrder(settingsStore.cardOrder)
        order.move(fromOffsets: source, toOffset: destination)
        settingsStore.cardOrder = order
    }
}

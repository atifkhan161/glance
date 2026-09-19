import SwiftUI

struct SmartSearchView: View {
    @State private var selectedTab: SmartSearchTab = .quickSearch
    @State private var showResearchList = false

    var body: some View {
        VStack(spacing: 0) {
            researchListLink

            Picker("Mode", selection: $selectedTab) {
                ForEach(SmartSearchTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 8)

            switch selectedTab {
            case .quickSearch:
                QuickSearchView()
            case .deepResearch:
                DeepResearchView()
            }
        }
        .glanceBackground()
        .navigationDestination(isPresented: $showResearchList) {
            ResearchListView()
        }
        .navigationDestination(for: ExaResult.self) { result in
            SearchResultDetailView(result: result)
        }
    }

    private var researchListLink: some View {
        Button {
            showResearchList = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(Theme.Colors.cardCyan)
                Text("Saved Research")
                    .font(Theme.Fonts.manrope(14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(12)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, 8)
    }
}

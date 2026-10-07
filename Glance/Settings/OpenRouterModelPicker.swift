import SwiftUI

struct OpenRouterModelPicker: View {
    @State private var loader = OpenRouterModelsLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPENROUTER MODEL")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            VStack(alignment: .leading, spacing: 8) {
                if let missing = loader.unavailableModelID {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(missing) is no longer available — using the free router.")
                    }
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.cardAmber)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.Colors.cardAmber.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small)
                    )
                }

                NavigationLink {
                    OpenRouterModelListView(loader: loader)
                } label: {
                    HStack(spacing: 10) {
                        Text(selectionLabel)
                            .font(Theme.Fonts.manrope(14))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(selectionBadge)
                            .font(Theme.Fonts.manrope(10, weight: .medium))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(badgeColor.opacity(0.15), in: .capsule)
                        Image(systemName: "chevron.right")
                            .font(Theme.Fonts.manrope(11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .padding(12)
                    .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Text("OpenRouter picks the fastest available free model per request. Free models cost nothing.")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .task { await loader.load() }
    }

    private var selectionLabel: String {
        let selected = OpenRouterModelPreference.selected
        guard !OpenRouterModelPreference.isPinnedRouter else { return "Auto (Free Router)" }
        return loader.models.first { $0.id == selected }?.name ?? selected
    }

    private var selectedModel: OpenRouterModel? {
        loader.models.first { $0.id == OpenRouterModelPreference.selected }
    }

    private var selectionBadge: String {
        if OpenRouterModelPreference.isPinnedRouter { return "FREE" }
        guard let selectedModel else { return "—" }
        return selectedModel.priceLabel
    }

    private var badgeColor: Color {
        if OpenRouterModelPreference.isPinnedRouter { return Theme.Colors.success }
        return selectedModel?.isFree == true ? Theme.Colors.success : Theme.Colors.cardAmber
    }
}

struct OpenRouterModelListView: View {
    @Bindable var loader: OpenRouterModelsLoader
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            if !filteredFree.isEmpty || query.isEmpty {
                Section("Free") {
                    routerRow
                    ForEach(filteredFree) { model in
                        row(model)
                    }
                }
            }

            if !filteredPaid.isEmpty {
                Section("All Models") {
                    ForEach(filteredPaid) { model in
                        row(model)
                    }
                }
            }

            if filteredFree.isEmpty && filteredPaid.isEmpty && !loader.isLoading {
                Section {
                    if let error = loader.loadError {
                        VStack(spacing: 8) {
                            Text("Couldn't load models")
                                .font(Theme.Fonts.manrope(13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(error)
                                .font(Theme.Fonts.manrope(11))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .multilineTextAlignment(.center)
                            Button("Retry") { Task { await loader.load(force: true) } }
                                .font(Theme.Fonts.manrope(12, weight: .medium))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        Text("No models match “\(query)”")
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("OpenRouter Model")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search models")
        .overlay {
            if loader.isLoading && loader.models.isEmpty {
                ProgressView()
            }
        }
        .refreshable { await loader.load(force: true) }
        .task { await loader.load() }
    }

    private var routerRow: some View {
        Button {
            loader.selectPinnedRouter()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto (Free Router)")
                        .font(Theme.Fonts.manrope(14, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("OpenRouter picks the fastest available free model")
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Spacer()
                badge("FREE", color: Theme.Colors.success)
                checkmark(matching: OpenRouterModelPreference.legacyDefaultID)
            }
        }
    }

    private func row(_ model: OpenRouterModel) -> some View {
        Button {
            loader.select(model)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(Theme.Fonts.manrope(14, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(model.id)
                            .font(Theme.Fonts.manrope(10))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(model.contextLabel)
                            .font(Theme.Fonts.manrope(10))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                Spacer()
                badge(
                    model.priceLabel,
                    color: model.isFree ? Theme.Colors.success : Theme.Colors.cardAmber
                )
                if model.thinksByDefault {
                    badge("THINKS", color: Theme.Colors.textMuted)
                }
                checkmark(matching: model.id)
            }
        }
    }

    @ViewBuilder
    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.Fonts.manrope(10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: .capsule)
            .fixedSize()
    }

    @ViewBuilder
    private func checkmark(matching id: String) -> some View {
        if OpenRouterModelPreference.selected == id {
            Image(systemName: "checkmark")
                .font(Theme.Fonts.manrope(12, weight: .bold))
                .foregroundStyle(Theme.Colors.accent)
        }
    }

    private var filteredFree: [OpenRouterModel] {
        guard !query.isEmpty else { return loader.freeModels }
        return loader.freeModels.filter(matches)
    }

    private var filteredPaid: [OpenRouterModel] {
        guard !query.isEmpty else { return loader.paidModels }
        return loader.paidModels.filter(matches)
    }

    private func matches(_ model: OpenRouterModel) -> Bool {
        let needle = query.lowercased()
        return model.name.lowercased().contains(needle) || model.id.lowercased().contains(needle)
    }
}

#Preview {
    NavigationStack {
        OpenRouterModelListView(loader: OpenRouterModelsLoader())
    }
}

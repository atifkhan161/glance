import SwiftUI

struct ApiKeysSection: View {
    @Bindable var settingsStore: SettingsStore

    @State private var isSaving = false
    @State private var saveSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("API KEYS")

            VStack(alignment: .leading, spacing: 8) {
                apiKeyField(
                    title: "EXA SEARCH",
                    placeholder: "Enter Exa API key",
                    text: $settingsStore.exaAPIKey
                )

                apiKeyField(
                    title: "GEMINI",
                    placeholder: "Enter Gemini API key",
                    text: $settingsStore.geminiAPIKey
                )

                geminiModelPicker

                apiKeyField(
                    title: "OPENROUTER",
                    placeholder: "Enter OpenRouter API key",
                    text: $settingsStore.openrouterAPIKey
                )

                footballDataRow
                saveButton
            }
        }
    }

    private func apiKeyField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                Text(text.wrappedValue.isEmpty ? "Missing" : "Configured ✓")
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(text.wrappedValue.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (text.wrappedValue.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success).opacity(0.15),
                        in: .capsule
                    )
            }

            SecureField(placeholder, text: text)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(12)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        }
    }

    private var geminiModelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GEMINI MODEL")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            Picker("Gemini Model", selection: $settingsStore.selectedModel) {
                Text("3.6 Flash").tag("gemini-3.6-flash")
                Text("3.7 Flash").tag("gemini-3.7-flash")
                Text("3.8 Flash").tag("gemini-3.8-flash")
            }
            .pickerStyle(.segmented)
        }
    }

    private var footballDataRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FOOTBALL DATA")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                Text("Configured ✓")
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(Theme.Colors.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.success.opacity(0.15), in: .capsule)
            }

            Text("Powered by thesportsdb.com free tier — no key required")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
    }

    private var saveButton: some View {
        VStack(spacing: 8) {
            Button {
                saveKeys()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSaving ? "Saving..." : "Save Keys")
                        .font(Theme.Fonts.scale(.callout).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Colors.cardEmerald, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .disabled(isSaving)

            if saveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Keys saved successfully")
                }
                .font(Theme.Fonts.scale(.caption2))
                .foregroundStyle(Theme.Colors.success)
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
            }
        }
        .padding(.top, 8)
    }

    private func saveKeys() {
        isSaving = true
        saveSuccess = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            settingsStore.saveToKeychain()
            isSaving = false
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                saveSuccess = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            ApiKeysSection(settingsStore: SettingsStore())
        }
    }
}

import SwiftUI

struct ApiKeysSection: View {
    @Bindable var settingsStore: SettingsStore

    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var failureMessage: String?
    @State private var keyToClear: ApiKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("API KEYS")

            VStack(alignment: .leading, spacing: 8) {
                apiKeyCard(.exa, title: "EXA SEARCH", placeholder: "Enter Exa API key")
                apiKeyCard(.gemini, title: "GEMINI", placeholder: "Enter Gemini API key")

                geminiModelPicker

                apiKeyCard(.openRouter, title: "OPENROUTER", placeholder: "Enter OpenRouter API key")

                footballDataBlock
                saveBlock
            }
        }
        .confirmationDialog(
            "Remove stored key?",
            isPresented: Binding(
                get: { keyToClear != nil },
                set: { if !$0 { keyToClear = nil } }
            ),
            presenting: keyToClear
        ) { key in
            Button("Remove \(key.displayName) key", role: .destructive) {
                settingsStore.clearStoredKey(key)
                keyToClear = nil
            }
            Button("Cancel", role: .cancel) { keyToClear = nil }
        } message: { key in
            Text("This deletes the saved \(key.displayName) key from the Keychain. Pipelines using it will fail until you enter a new one.")
        }
    }

    private func apiKeyCard(_ key: ApiKey, title: String, placeholder: String) -> some View {
        let stored = settingsStore.isStored(key)
        let binding = Binding(
            get: { settingsStore.draftValue(for: key) },
            set: { settingsStore.setDraftValue($0, for: key) }
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                Text(stored ? "Configured ✓" : "Missing")
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(stored ? Theme.Colors.success : Theme.Colors.cardAmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (stored ? Theme.Colors.success : Theme.Colors.cardAmber).opacity(0.15),
                        in: .capsule
                    )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(stored ? "configured" : "missing")")

            if let masked = settingsStore.maskedKey(key) {
                HStack(spacing: 6) {
                    Text("Stored: \(masked)")
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Spacer()
                    Button("Clear") { keyToClear = key }
                        .font(Theme.Fonts.manrope(11, weight: .medium))
                        .foregroundStyle(Theme.Colors.error)
                        .accessibilityLabel("Clear stored \(key.displayName) key")
                }
            }

            SecureField(stored ? "Enter new key to replace" : placeholder, text: binding)
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

    private var footballDataBlock: some View {
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

    private var saveBlock: some View {
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

            if let failureMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(failureMessage)
                }
                .font(Theme.Fonts.scale(.caption2))
                .foregroundStyle(Theme.Colors.error)
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
            } else if saveSuccess {
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
        failureMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let failures = settingsStore.saveToKeychain()
            isSaving = false

            if failures.isEmpty {
                saveSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    saveSuccess = false
                }
            } else {
                let detail = failures
                    .sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { "\($0.key.displayName) \($0.value.statusDescription)" }
                    .joined(separator: ", ")
                failureMessage = "Save failed: \(detail)"
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

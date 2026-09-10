import SwiftUI

struct SourcesView: View {
    @State private var store = SettingsStore()
    @State private var showExaKey = false
    @State private var showGeminiKey = false
    @State private var saveSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Exa API Key
                keySection(
                    title: "EXA API KEY",
                    key: "Exa",
                    value: $store.exaAPIKey,
                    isSecure: !showExaKey,
                    toggle: { showExaKey.toggle() },
                    status: exaStatus,
                    link: "https://exa.ai"
                )

                // Gemini API Key
                keySection(
                    title: "GEMINI API KEY",
                    key: "Gemini",
                    value: $store.geminiAPIKey,
                    isSecure: !showGeminiKey,
                    toggle: { showGeminiKey.toggle() },
                    status: geminiStatus,
                    link: "https://aistudio.google.com/apikey"
                )

                // Gemini Model Picker
                modelPickerSection

                // On-device AI Status
                aiStatusSection

                // Save button
                Button {
                    saveKeys()
                } label: {
                    Text("Save Keys")
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.canvas)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: 12))
                }

                if saveSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Keys saved successfully")
                    }
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                // Footer
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keys are stored locally on your device. Never committed to git.")
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)

                    HStack(spacing: 16) {
                        if let exaURL = URL(string: "https://exa.ai") {
                            Link("Get Exa key →", destination: exaURL)
                        }
                        if let geminiURL = URL(string: "https://aistudio.google.com/apikey") {
                            Link("Get Gemini key →", destination: geminiURL)
                        }
                    }
                    .font(Theme.Fonts.manrope(12))
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .background(Theme.canvas)
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            store.loadFromKeychain()
        }
    }

    // MARK: - Key Section

    private func keySection(
        title: String,
        key: String,
        value: Binding<String>,
        isSecure: Bool,
        toggle: @escaping () -> Void,
        status: KeyStatus,
        link: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                statusBadge(status)
            }

            HStack {
                if isSecure {
                    SecureField("Enter \(key) API key", text: value)
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                } else {
                    TextField("Enter \(key) API key", text: value)
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                Button { toggle() } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .accessibilityLabel(isSecure ? "Show \(key) key" : "Hide \(key) key")
            }
            .padding(12)
            .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
            )

            // Masked existing key
            if let existing = store.existingKey(for: key) {
                Text("Current: \(existing)")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
    }

    private func statusBadge(_ status: KeyStatus) -> some View {
        Text(status.text)
            .font(Theme.Fonts.manrope(10, weight: .medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.15), in: .capsule)
    }

    enum KeyStatus {
        case missing, configured, fromEnv

        var text: String {
            switch self {
            case .missing: "Missing"
            case .configured: "Configured ✓"
            case .fromEnv: "From .env"
            }
        }

        var color: Color {
            switch self {
            case .missing: Theme.Colors.cardAmber
            case .configured: .green
            case .fromEnv: Theme.Colors.textMuted
            }
        }
    }

    private var exaStatus: KeyStatus {
        if store.exaAPIKey.isEmpty {
            return store.existingKey(for: "Exa") != nil ? .fromEnv : .missing
        }
        return .configured
    }

    private var geminiStatus: KeyStatus {
        if store.geminiAPIKey.isEmpty {
            return store.existingKey(for: "Gemini") != nil ? .fromEnv : .missing
        }
        return .configured
    }

    // MARK: - Model Picker

    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GEMINI MODEL")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            VStack(spacing: 8) {
                modelOption(
                    id: "gemini-3.6-flash",
                    title: "Gemini 3.6 Flash",
                    subtitle: "Stable, free tier"
                )
                modelOption(
                    id: "gemini-3.7-flash",
                    title: "Gemini 3.7 Flash",
                    subtitle: "Stable, newer"
                )
                modelOption(
                    id: "gemini-3.8-flash",
                    title: "Gemini 3.8 Flash",
                    subtitle: "Latest (intro pricing)"
                )
            }
        }
    }

    private func modelOption(id: String, title: String, subtitle: String) -> some View {
        Button {
            store.selectedModel = id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.manrope(14, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.manrope(12))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Spacer()
                if store.selectedModel == id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.accent)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            .padding(12)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(store.selectedModel == id ? Theme.Colors.accent : Theme.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .accessibilityLabel("\(title), \(subtitle)")
    }

    // MARK: - AI Status

    private var aiStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ON-DEVICE AI")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            HStack {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Active")
                    .font(Theme.Fonts.manrope(13, weight: .medium))
                    .foregroundStyle(.green)
                Spacer()
                Button("Re-check") {
                    // Re-check availability
                }
                .font(Theme.Fonts.manrope(12))
                .foregroundStyle(Theme.Colors.accent)
            }
            .padding(12)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 10))

            Text("Apple Foundation Models — zero cost, offline, private")
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    // MARK: - Save

    private func saveKeys() {
        store.saveToKeychain()
        saveSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            saveSuccess = false
        }
    }
}

#Preview {
    NavigationStack { SourcesView() }
}

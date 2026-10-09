import SwiftUI
import UIKit

@MainActor
@Observable
final class LogViewerModel {
    private let log: AppLog
    private(set) var entries: [LogEntry] = []
    private(set) var isLoading = false
    var query = ""
    var minimumLevel: LogLevel = .error {
        didSet {
            let level = minimumLevel
            Task { await log.setMinimumLevel(level) }
        }
    }

    init(log: AppLog = .shared) {
        self.log = log
    }

    var filteredEntries: [LogEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return entries }
        return entries.filter {
            $0.message.localizedCaseInsensitiveContains(trimmed)
                || $0.subsystem.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var errorCount: Int {
        entries.filter { $0.level == .error }.count
    }

    func load() async {
        isLoading = true
        entries = await log.snapshot()
        isLoading = false
    }

    func clear() async {
        await log.clear()
        await load()
    }

    func exportText() -> String {
        LogExport.markdown(
            entries: entries,
            appVersion: .current,
            device: LogExport.currentDevice
        )
    }
}

struct LogViewerView: View {
    @Bindable var model: LogViewerModel
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if model.isLoading && model.entries.isEmpty {
                ProgressView()
            } else if model.filteredEntries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Error Logs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, prompt: "Search logs")
        .task { await model.load() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                levelMenu
                copyButton
                if model.entries.isEmpty == false {
                    ShareLink(item: model.exportText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .alert("Clear error logs?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                Task { await model.clear() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every recorded entry.")
        }
    }

    private var list: some View {
        List {
            ForEach(model.filteredEntries) { entry in
                row(entry)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await model.load() }
    }

    private func row(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(entry.level.label)
                    .font(Theme.Fonts.manrope(9, weight: .bold))
                    .foregroundStyle(color(for: entry.level))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(color(for: entry.level).opacity(0.15), in: .capsule)
                Text(entry.subsystem)
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
                Spacer()
                Text(TimeFormat.formatDate(entry.displayTimestamp))
                    .font(Theme.Fonts.manrope(10))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Text(entry.message)
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail = entry.detail, detail.isEmpty == false {
                Text(detail)
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private var levelMenu: some View {
        Menu {
            Picker("Level", selection: $model.minimumLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
    }

    private var copyButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            UIPasteboard.general.string = model.exportText()
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .accessibilityLabel("Copy log report")
    }

    private var emptyState: some View {
        GlanceEmptyView(
            icon: "checkmark.circle",
            title: model.entries.isEmpty ? "No errors recorded" : "No matching logs",
            message: model.entries.isEmpty
                ? "Failures appear here automatically. Pull to refresh after one happens."
                : "No entry matches your search.",
            accentColor: Theme.Colors.cardEmerald
        )
    }

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .error: Theme.Colors.cardEmerald
        case .warning: Theme.Colors.cardAmber
        case .info: Theme.Colors.textMuted
        }
    }
}
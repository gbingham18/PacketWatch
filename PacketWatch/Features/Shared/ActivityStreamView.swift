// Features/Shared/ActivityStreamView.swift
//
// Reusable component for displaying activity streams.

import SwiftUI

struct ActivityStreamView: View {
    let entries: [ActivityEntry]
    let isLoading: Bool
    let onRefresh: (() -> Void)?

    init(
        entries: [ActivityEntry],
        isLoading: Bool = false,
        onRefresh: (() -> Void)? = nil
    ) {
        self.entries = entries
        self.isLoading = isLoading
        self.onRefresh = onRefresh
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if entries.isEmpty {
                EmptyActivityView()
            } else {
                List(entries) { entry in
                    ActivityEntryRow(entry: entry)
                }
                .listStyle(.plain)
                .refreshable {
                    onRefresh?()
                }
            }
        }
    }
}

// MARK: - Activity Entry Row

private struct ActivityEntryRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LeadingIcon(entry: entry)

            VStack(alignment: .leading, spacing: 4) {
                DomainText(entry: entry)
                TagsRow(entry: entry)
                if let app = entry.inferredApp {
                    AppContextText(app: app)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(entry.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct LeadingIcon: View {
    let entry: ActivityEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 18))
        }
    }

    private var backgroundColor: Color {
        if entry.isFlagged {
            return Color.red.opacity(0.1)
        }
        switch entry.source {
        case .dns:
            return Color.blue.opacity(0.1)
        case .sni:
            return Color.green.opacity(0.1)
        case .safariExtension:
            return Color.purple.opacity(0.1)
        }
    }

    private var iconColor: Color {
        if entry.isFlagged {
            return .red
        }
        switch entry.source {
        case .dns:
            return .blue
        case .sni:
            return .green
        case .safariExtension:
            return .purple
        }
    }

    private var iconName: String {
        if entry.isFlagged {
            return "exclamationmark.triangle.fill"
        }
        switch entry.source {
        case .dns:
            return "globe"
        case .sni:
            return "lock.shield"
        case .safariExtension:
            return "safari"
        }
    }
}

private struct DomainText: View {
    let entry: ActivityEntry

    var body: some View {
        Text(entry.domain)
            .font(.system(.body, design: .monospaced))
            .fontWeight(entry.isFlagged ? .semibold : .regular)
            .foregroundColor(entry.isFlagged ? .red : .primary)
            .lineLimit(2)
    }
}

private struct TagsRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 6) {
            SourceTag(source: entry.source)

            if let category = entry.category, entry.isFlagged {
                CategoryTag(category: category)
            }

            if let level = entry.monitoringLevel {
                MonitoringLevelTag(level: level)
            }
        }
    }
}

private struct SourceTag: View {
    let source: ActivityEntry.DetectionSource

    var body: some View {
        Text(sourceLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(4)
    }

    private var sourceLabel: String {
        switch source {
        case .dns: return "DNS"
        case .sni: return "SNI"
        case .safariExtension: return "Safari"
        }
    }

    private var backgroundColor: Color {
        switch source {
        case .dns: return Color.blue.opacity(0.15)
        case .sni: return Color.green.opacity(0.15)
        case .safariExtension: return Color.purple.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch source {
        case .dns: return .blue
        case .sni: return .green
        case .safariExtension: return .purple
        }
    }
}

private struct CategoryTag: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .cornerRadius(4)
    }
}

private struct MonitoringLevelTag: View {
    let level: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "eye.fill")
                .font(.system(size: 8))
            Text(level)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

private struct AppContextText: View {
    let app: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.caption2)
            Text("Detected in \(app)")
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading activity...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State

private struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Activity Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Activity will appear here once monitoring begins")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Entries") {
    ActivityStreamView(
        entries: [
            ActivityEntry(dataOwnerId: "preview-user-id", domain: "example.com", source: .dns),
            ActivityEntry(dataOwnerId: "preview-user-id", domain: "test.com", source: .safariExtension)
        ]
    )
}

#Preview("Empty") {
    ActivityStreamView(entries: [])
}

#Preview("Loading") {
    ActivityStreamView(entries: [], isLoading: true)
}

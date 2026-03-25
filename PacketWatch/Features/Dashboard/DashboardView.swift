// Features/Dashboard/DashboardView.swift
//
// Main dashboard view for PacketWatch.
// Displays tunnel status, detected browsers, and domain entries.
// All business logic is delegated to DashboardViewModel.

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonitoringStatusHeader(
                    isActive: viewModel.tunnelState.isRunning,
                    onToggle: viewModel.toggleTunnel
                )

                if viewModel.hasDetectedBrowsers {
                    BrowserWarningView(browsers: viewModel.detectedBrowsersList)
                }

                Divider()

                ActivityStreamView(
                    entries: viewModel.entries,
                    isLoading: viewModel.isLoading,
                    onRefresh: { viewModel.refreshEntries() }
                )
            }
            .navigationTitle("My Activity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    MenuView(
                        onRunTests: viewModel.runParserTests,
                        onClear: viewModel.clearAll
                    )
                }
            }
        }
        .task {
            await viewModel.loadActivity(for: authViewModel.currentUser?.accountabilityNetworkId)
        }
        .onAppear { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }
}

// MARK: - Monitoring Status Header

private struct MonitoringStatusHeader: View {
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: isActive ? "eye.fill" : "eye.slash.fill")
                    .font(.title2)
                    .foregroundColor(isActive ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Monitoring")
                    .font(.headline)
                Text(isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onToggle) {
                Text(isActive ? "Stop" : "Start")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(isActive ? Color.red : Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

// MARK: - Browser Warning

private struct BrowserWarningView: View {
    let browsers: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Alternate Browsers Detected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(browsers)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Screen monitoring unavailable in these browsers")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Menu

private struct MenuView: View {
    let onRunTests: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onRunTests) {
                Label("Run Parser Tests", systemImage: "checkmark.circle")
            }
            
            Divider()
            
            Button(role: .destructive, action: onClear) {
                Label("Clear Log", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}

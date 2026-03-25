// Features/Networks/NetworksListView.swift
//
// Tab 1: Shows list of accountability networks where user is an ally.

import SwiftUI

struct NetworksListView: View {
    @StateObject private var viewModel = NetworksListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.networks.isEmpty {
                    EmptyNetworksView()
                } else {
                    NetworksList(networks: viewModel.networks)
                }
            }
            .navigationTitle("My Networks")
            .task {
                await viewModel.loadNetworks(for: authViewModel.currentUser)
            }
            .refreshable {
                await viewModel.loadNetworks(for: authViewModel.currentUser)
            }
        }
    }
}

// MARK: - Networks List

private struct NetworksList: View {
    let networks: [NetworkInfo]

    var body: some View {
        List(networks) { network in
            NavigationLink(destination: NetworkDetailView(network: network)) {
                NetworkRow(network: network)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Network Row

private struct NetworkRow: View {
    let network: NetworkInfo

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(network.monitoredUserName)
                    .font(.headline)
            }

            Spacer()

            if network.isAdministrator {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

private struct EmptyNetworksView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Networks")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You're not monitoring anyone yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Accept an invitation to start monitoring someone's activity")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }
}

// MARK: - View Model

@MainActor
final class NetworksListViewModel: ObservableObject {
    @Published var networks: [NetworkInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let networkService: AccountabilityNetworkService
    private let userService: UserService

    init(
        networkService: AccountabilityNetworkService = FirebaseAccountabilityNetworkService.shared,
        userService: UserService = FirebaseUserService.shared
    ) {
        self.networkService = networkService
        self.userService = userService
    }

    func loadNetworks(for user: User?) async {
        guard let user = user else {
            print("[NetworksListVM] loadNetworks: no user, aborting")
            return
        }

        print("[NetworksListVM] loadNetworks: user.id=\(user.id)")
        isLoading = true
        errorMessage = nil

        do {
            print("[NetworksListVM] fetching active networks for ally user.id=\(user.id)")
            let fetchedNetworks = try await networkService.fetchNetworksForAlly(userId: user.id)
            print("[NetworksListVM] query returned \(fetchedNetworks.count) network(s)")

            var networkInfos: [NetworkInfo] = []

            for network in fetchedNetworks {
                print("[NetworksListVM] fetching user document for monitoredUserId=\(network.monitoredUserId)")
                guard let monitoredUser = try await userService.fetchUser(id: network.monitoredUserId) else {
                    print("[NetworksListVM] failed to fetch/parse monitored user \(network.monitoredUserId)")
                    continue
                }
                print("[NetworksListVM] monitored user=\(monitoredUser.displayName)")

                networkInfos.append(NetworkInfo(
                    id: network.id,
                    monitoredUserId: network.monitoredUserId,
                    monitoredUserName: monitoredUser.displayName,
                    isAdministrator: network.isFilterAdministrator(user.id)
                ))
            }

            print("[NetworksListVM] built \(networkInfos.count) NetworkInfo(s), assigning to networks")
            networks = networkInfos.sorted { $0.monitoredUserName < $1.monitoredUserName }

        } catch {
            print("[NetworksListVM] error: \(error.localizedDescription) fullError=\(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Network Info Model

struct NetworkInfo: Identifiable {
    let id: String
    let monitoredUserId: String
    let monitoredUserName: String
    let isAdministrator: Bool
}

// MARK: - Network Detail View

struct NetworkDetailView: View {
    let network: NetworkInfo
    @StateObject private var viewModel = NetworkDetailViewModel()

    var body: some View {
        ActivityStreamView(
            entries: viewModel.entries,
            isLoading: viewModel.isLoading
        )
        .navigationTitle(network.monitoredUserName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadActivity(forNetwork: network.id)
        }
    }
}

@MainActor
final class NetworkDetailViewModel: ObservableObject {
    @Published var entries: [ActivityEntry] = []
    @Published var isLoading = false

    private let activityStreamService: ActivityStreamService = FirebaseActivityStreamService.shared

    func loadActivity(forNetwork networkId: String) async {
        isLoading = true

        do {
            let stream = try await activityStreamService.fetchStream(forNetwork: networkId, limit: 500)
            entries = stream.entries.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Error loading activity: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NetworksListView()
            .environmentObject(AuthViewModel())
    }
}

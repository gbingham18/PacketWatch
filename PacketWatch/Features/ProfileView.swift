// Features/ProfileView.swift
//
// User profile screen with settings, account info, and sign out.

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    if let user = authViewModel.currentUser {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(user.displayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("User ID: \(user.id)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospaced()
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }

                // Invitations Section
                Section("Invitations") {
                    NavigationLink {
                        InvitationsView()
                    } label: {
                        Label("Invitations", systemImage: "envelope.fill")
                    }
                }

                // Accountability Network Section
                Section {
                    if let user = authViewModel.currentUser, user.accountabilityNetworkId != nil {
                        NavigationLink {
                            AccountabilityNetworkView()
                        } label: {
                            Label("My Accountability Network", systemImage: "person.2.fill")
                        }
                    } else {
                        NavigationLink {
                            SetupNetworkView()
                        } label: {
                            HStack {
                                Label("Setup Accountability Network", systemImage: "person.2.badge.gearshape")
                                Spacer()
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                } header: {
                    Text("Accountability")
                } footer: {
                    if let user = authViewModel.currentUser, user.accountabilityNetworkId == nil {
                        Text("An accountability network allows trusted allies to view your reports and a filter administrator to manage your settings.")
                    }
                }

                // Account Settings Section
                Section("Account") {
                    NavigationLink {
                        FilterSettingsView()
                    } label: {
                        Label("Filter Settings", systemImage: "shield.fill")
                    }
                }

                // Support Section
                Section("Support & Legal") {
                    Link(destination: URL(string: "https://packetwatch.app/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                    }

                    Link(destination: URL(string: "https://packetwatch.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.doc.fill")
                    }

                    Link(destination: URL(string: "https://packetwatch.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showDeleteAccountConfirmation = true
                    } label: {
                        if isDeleting {
                            HStack {
                                Label("Deleting Account...", systemImage: "trash")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Delete Account", systemImage: "trash.fill")
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Account Actions")
                } footer: {
                    Text("Deleting your account will permanently remove all your data and cannot be undone.")
                }

                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                try await authViewModel.deleteAccount()
            } catch {
                print("Error deleting account: \(error)")
            }

            await MainActor.run {
                isDeleting = false
            }
        }
    }
}

// MARK: - Placeholder Views

struct AccountabilityNetworkView: View {
    var body: some View {
        List {
            Section("Filter Administrator") {
                Text("Manages your filter settings")
                    .foregroundColor(.secondary)
            }

            Section("Allies") {
                Text("Can view your accountability reports")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("My Network")
    }
}

struct SetupNetworkView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Setup Accountability Network")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("An accountability network includes:\n\n• One Filter Administrator who manages your settings\n• Multiple Allies who can view your reports")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                // TODO: Implement network setup
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Setup Network")
    }
}

struct FilterSettingsView: View {
    var body: some View {
        List {
            Section {
                Text("Filter settings managed by your Filter Administrator")
                    .foregroundColor(.secondary)
            } footer: {
                Text("Only your designated Filter Administrator can modify these settings.")
            }
        }
        .navigationTitle("Filter Settings")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

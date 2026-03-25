// Features/Onboarding/InvitationsView.swift
//
// Shows pending invitations for the signed-in user and allows accept/decline.

import SwiftUI

@MainActor
final class InvitationsViewModel: ObservableObject {
    @Published var invitations: [Invitation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let invitationService: InvitationService = FirebaseInvitationService.shared

    func loadInvitations(forEmail email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            invitations = try await invitationService.fetchPendingInvitations(forEmail: email)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func accept(_ invitation: Invitation, as user: User) async {
        do {
            try await invitationService.acceptInvitation(invitation.id, byUser: user)
            invitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func decline(_ invitation: Invitation) async {
        do {
            try await invitationService.declineInvitation(invitation.id)
            invitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - View

struct InvitationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = InvitationsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.invitations.isEmpty {
                ContentUnavailableView(
                    "No Pending Invitations",
                    systemImage: "envelope.open",
                    description: Text("Invitations sent to your email will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.invitations, id: \.id) { invitation in
                        InvitationRow(
                            invitation: invitation,
                            onAccept: {
                                guard let user = authViewModel.currentUser else { return }
                                Task { await viewModel.accept(invitation, as: user) }
                            },
                            onDecline: {
                                Task { await viewModel.decline(invitation) }
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Invitations")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .task {
            guard let email = authViewModel.currentUser?.email else { return }
            await viewModel.loadInvitations(forEmail: email)
        }
    }
}

// MARK: - Invitation Row

private struct InvitationRow: View {
    let invitation: Invitation
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: invitation.role == .administrator ? "person.badge.shield.checkmark" : "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.fromUserName)
                        .font(.headline)

                    Text(invitation.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Expires \(invitation.expiresAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Text("Accept")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: onDecline) {
                    Text("Decline")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

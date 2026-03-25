// Features/Onboarding/OnboardingViewModel.swift
//
// View model for onboarding flow.

import Foundation
import FirebaseFirestore

enum UserRole {
    case monitored
    case supporter
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .roleSelection
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    // Step 2: Administrator
    @Published var administratorEmail = ""

    // Step 3: Settings
    @Published var selectedSensitivity: SensitivityLevel = .moderate

    // Step 5: Allies
    @Published var allyEmails: [String] = [""]

    private var currentUser: User?
    private var accountabilityNetwork: AccountabilityNetwork?
    private var pendingProposal: ProposedFilterSettings?
    private var selectedRole: UserRole?

    private let networkService: AccountabilityNetworkService
    private let userService: UserService
    private let activityStreamService: ActivityStreamService
    private let invitationService: InvitationService
    private let filterSettingsService: FilterSettingsService

    init(
        networkService: AccountabilityNetworkService = FirebaseAccountabilityNetworkService.shared,
        userService: UserService = FirebaseUserService.shared,
        activityStreamService: ActivityStreamService = FirebaseActivityStreamService.shared,
        invitationService: InvitationService = FirebaseInvitationService.shared,
        filterSettingsService: FilterSettingsService = FirebaseFilterSettingsService.shared
    ) {
        self.networkService = networkService
        self.userService = userService
        self.activityStreamService = activityStreamService
        self.invitationService = invitationService
        self.filterSettingsService = filterSettingsService
    }

    func initialize(user: User?) async {
        self.currentUser = user
    }

    // MARK: - Step 1: Role Selection

    func selectRole(_ role: UserRole) {
        selectedRole = role
        switch role {
        case .monitored:
            currentStep = .assignAdministrator
        case .supporter:
            // For supporters, just mark onboarding complete
            // They'll wait for invitations
            completeOnboarding()
        }
    }

    // MARK: - Step 2: Assign Administrator

    func sendAdministratorInvitation() async {
        guard let user = currentUser else {
            print("[Onboarding] sendAdministratorInvitation: no currentUser, aborting")
            return
        }

        print("[Onboarding] sendAdministratorInvitation: starting, user.id=\(user.id)")
        isLoading = true
        errorMessage = nil

        do {
            // Create accountability network with user as initial admin
            let network = AccountabilityNetwork(
                monitoredUserId: user.id,
                filterAdministratorUserId: user.id,
                allyUserIds: [],
                status: .pending
            )

            print("[Onboarding] writing accountability_networks/\(network.id)")
            try await networkService.create(network)
            print("[Onboarding] accountability_networks write succeeded")

            self.accountabilityNetwork = network

            // Update user's accountabilityNetworkId
            print("[Onboarding] updating users/\(user.id) accountabilityNetworkId")
            try await userService.updateFields(["accountabilityNetworkId": network.id], forUser: user.id)
            print("[Onboarding] users update succeeded")

            // Update local user object
            var updatedUser = user
            updatedUser.accountabilityNetworkId = network.id
            self.currentUser = updatedUser

            // Create activityStreams document keyed by networkId
            print("[Onboarding] creating activityStreams/\(network.id) document")
            try await activityStreamService.createStream(networkId: network.id, monitoredUserId: user.id)
            print("[Onboarding] activityStreams document created")

            // Send invitation if email provided
            if !administratorEmail.trimmingCharacters(in: .whitespaces).isEmpty {
                print("[Onboarding] sending admin invitation to \(administratorEmail)")
                _ = try await invitationService.sendInvitation(
                    fromUser: user,
                    toEmail: administratorEmail,
                    networkId: network.id,
                    role: .administrator
                )
                print("[Onboarding] invitation sent successfully")
            } else {
                print("[Onboarding] no admin email provided, skipping invitation")
            }

            currentStep = .defineSettings
            print("[Onboarding] sendAdministratorInvitation: complete")

        } catch {
            print("[Onboarding] sendAdministratorInvitation: error=\(error.localizedDescription) fullError=\(error)")
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Step 3: Define Settings

    func updateSettings() async {
        guard let user = currentUser else { return }

        isLoading = true
        errorMessage = nil

        do {
            // During onboarding, user is their own admin so they can directly update settings
            let settings = FilterSettings(
                dataOwnerId: user.id,
                lastModifiedBy: user.id,
                sensitivityLevel: selectedSensitivity
            )

            try await filterSettingsService.updateSettings(settings)

            currentStep = .addAllies

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    // MARK: - Step 5: Add Allies

    func addAllyField() {
        allyEmails.append("")
    }

    func removeAlly(at index: Int) {
        allyEmails.remove(at: index)
    }

    func sendAllyInvitations() async {
        guard let user = currentUser,
              let network = accountabilityNetwork else { return }

        isLoading = true
        errorMessage = nil

        let validEmails = allyEmails.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        do {
            for email in validEmails {
                _ = try await invitationService.sendInvitation(
                    fromUser: user,
                    toEmail: email,
                    networkId: network.id,
                    role: .ally
                )
            }

            currentStep = .permissions

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func skipAllies() {
        currentStep = .permissions
    }

    // MARK: - Step 6: Permissions

    func requestPermissions() {
        // In production, this would request Network Extension + Safari Extension permissions
        // For now, just move to complete
        currentStep = .complete
    }

    // MARK: - Step 7: Complete

    func completeOnboarding() {
        guard let user = currentUser else { return }

        Task {
            isLoading = true

            do {
                // Mark onboarding as complete
                var updates: [String: Any] = ["onboardingComplete": true]
                if selectedRole == .monitored {
                    updates["featureIds"] = FieldValue.arrayUnion([WellKnownFeatureIds.monitoredFeatureId])
                }
                try await userService.updateFields(updates, forUser: user.id)

                // Update the network status to active
                if let network = accountabilityNetwork {
                    try await networkService.updateStatus(network.id, status: .active)
                }

                // Notify the app that onboarding is complete
                NotificationCenter.default.post(name: .onboardingComplete, object: nil)

            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isLoading = false
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let onboardingComplete = Notification.Name("onboardingComplete")
}

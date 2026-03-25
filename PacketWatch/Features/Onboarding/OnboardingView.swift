// Features/Onboarding/OnboardingView.swift
//
// Multi-step onboarding flow for new users.

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.currentStep {
                case .roleSelection:
                    RoleSelectionStep(viewModel: viewModel)
                case .assignAdministrator:
                    AssignAdministratorStep(viewModel: viewModel)
                case .defineSettings:
                    DefineSettingsStep(viewModel: viewModel)
                case .addAllies:
                    AddAlliesStep(viewModel: viewModel)
                case .permissions:
                    PermissionsStep(viewModel: viewModel)
                case .complete:
                    CompleteStep(viewModel: viewModel)
                }

                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationBarBackButtonHidden(true)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .task {
                await viewModel.initialize(user: authViewModel.currentUser)
            }
        }
    }
}

// MARK: - Onboarding Steps

enum OnboardingStep {
    case roleSelection
    case assignAdministrator
    case defineSettings
    case addAllies
    case permissions
    case complete
}

// MARK: - Step 1: Role Selection

private struct RoleSelectionStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 72))
                    .foregroundColor(.blue)

                Text("Welcome to ZoomerProof")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose how you want to use the app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                RoleButton(
                    title: "I want to be monitored",
                    subtitle: "Set up accountability for myself",
                    icon: "person.fill.checkmark",
                    action: { viewModel.selectRole(.monitored) }
                )

                RoleButton(
                    title: "I'm here to support someone",
                    subtitle: "Help monitor someone else's activity",
                    icon: "person.2.fill",
                    action: { viewModel.selectRole(.supporter) }
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

private struct RoleButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Step 2: Assign Administrator

private struct AssignAdministratorStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            ProgressHeader(step: 1, total: 5, title: "Assign Filter Administrator")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Who will manage your filter settings?")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This person will approve changes to what content gets flagged. Choose someone you trust.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Administrator's email", text: $viewModel.administratorEmail)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding()
            }

            Spacer()

            ActionButtons(
                primaryTitle: "Continue",
                primaryAction: { await viewModel.sendAdministratorInvitation() }
            )
        }
    }
}

// MARK: - Step 3: Define Settings

private struct DefineSettingsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            ProgressHeader(step: 2, total: 5, title: "Define Filter Settings")

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Choose your monitoring level")
                        .font(.title2)
                        .fontWeight(.semibold)

                    ForEach(SensitivityLevel.allCases, id: \.self) { level in
                        SensitivityButton(
                            level: level,
                            isSelected: viewModel.selectedSensitivity == level,
                            action: { viewModel.selectedSensitivity = level }
                        )
                    }

                    Text("You can adjust these settings anytime. Once your administrator accepts your invitation, they'll need to approve future changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            ActionButtons(
                primaryTitle: "Continue",
                primaryAction: { await viewModel.updateSettings() }
            )
        }
    }
}

private struct SensitivityButton: View {
    let level: SensitivityLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Step 4: Add Allies (Optional)

private struct AddAlliesStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            ProgressHeader(step: 3, total: 4, title: "Add Allies")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Who else should see your reports?")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Allies can view your activity stream. You can add more later.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(viewModel.allyEmails.indices, id: \.self) { index in
                        HStack {
                            TextField("Ally's email", text: $viewModel.allyEmails[index])
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)

                            Button(action: { viewModel.removeAlly(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button(action: { viewModel.addAllyField() }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Another Ally")
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding()
            }

            ActionButtons(
                primaryTitle: "Continue",
                primaryAction: { await viewModel.sendAllyInvitations() },
                secondaryTitle: "Skip",
                secondaryAction: { viewModel.skipAllies() }
            )
        }
    }
}

// MARK: - Step 5: Permissions

private struct PermissionsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            ProgressHeader(step: 4, total: 4, title: "Enable Monitoring")

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Grant Permissions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    PermissionItem(
                        icon: "network",
                        title: "Network Extension",
                        description: "Monitors network traffic (pending Apple approval)",
                        isEnabled: false
                    )

                    PermissionItem(
                        icon: "safari",
                        title: "Safari Extension",
                        description: "Captures activity in Safari browser",
                        isEnabled: false
                    )

                    Text("Tap 'Enable Monitoring' to configure these permissions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            ActionButtons(
                primaryTitle: "Enable Monitoring",
                primaryAction: { viewModel.requestPermissions() }
            )
        }
    }
}

private struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Step 6: Complete

private struct CompleteStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Monitoring is now active. Your activity will be shared with your allies.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { viewModel.completeOnboarding() }) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Helper Components

private struct ProgressHeader: View {
    let step: Int
    let total: Int
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(1...total, id: \.self) { index in
                    Rectangle()
                        .fill(index <= step ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }

            Text("Step \(step) of \(total): \(title)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

private struct ActionButtons: View {
    let primaryTitle: String
    let primaryAction: () async -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await primaryAction() } }) {
                Text(primaryTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isDisabled ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isDisabled)

            if let secondaryTitle = secondaryTitle, let secondaryAction = secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AuthViewModel())
}

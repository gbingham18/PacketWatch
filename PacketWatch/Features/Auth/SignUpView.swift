// Features/Auth/SignUpView.swift
//
// Account creation screen.

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Start your accountability journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                
                // Form
                VStack(spacing: 16) {
                    AuthTextField(
                        title: "Display Name",
                        text: $authViewModel.displayName,
                        placeholder: "How should we call you?",
                        contentType: .name,
                        keyboardType: .default
                    )
                    
                    AuthTextField(
                        title: "Email",
                        text: $authViewModel.email,
                        placeholder: "your@email.com",
                        contentType: .emailAddress,
                        keyboardType: .emailAddress
                    )
                    
                    AuthSecureField(
                        title: "Password",
                        text: $authViewModel.password,
                        placeholder: "At least 6 characters",
                        contentType: .newPassword
                    )
                    
                    AuthSecureField(
                        title: "Confirm Password",
                        text: $authViewModel.confirmPassword,
                        placeholder: "Re-enter password",
                        contentType: .newPassword
                    )
                }
                .padding(.horizontal)
                
                // Error
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Sign Up Button
                Button {
                    Task { await authViewModel.signUp() }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(authViewModel.canSignUp ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!authViewModel.canSignUp || authViewModel.isLoading)
                .padding(.horizontal)
                
                // Terms
                Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: authViewModel.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
}

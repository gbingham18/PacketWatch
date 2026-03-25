// Features/Auth/SignInView.swift
//
// Sign in screen.

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome Back")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                
                // Form
                VStack(spacing: 16) {
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
                        placeholder: "Enter password",
                        contentType: .password
                    )
                }
                .padding(.horizontal)
                
                // Forgot Password
                NavigationLink(destination: ForgotPasswordView()) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                // Error
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Sign In Button
                Button {
                    Task { await authViewModel.signIn() }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(authViewModel.canSignIn ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!authViewModel.canSignIn || authViewModel.isLoading)
                .padding(.horizontal)
                
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
        SignInView()
            .environmentObject(AuthViewModel())
    }
}

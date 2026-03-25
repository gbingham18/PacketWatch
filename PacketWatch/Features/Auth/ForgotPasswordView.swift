// Features/Auth/ForgotPasswordView.swift
//
// Password reset request screen.

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var emailSent = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: emailSent ? "checkmark.circle.fill" : "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(emailSent ? .green : .blue)
                
                Text(emailSent ? "Check Your Email" : "Reset Password")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(emailSent
                     ? "We've sent password reset instructions to your email"
                     : "Enter your email and we'll send you a reset link")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 32)
            
            if !emailSent {
                // Form
                VStack(spacing: 16) {
                    AuthTextField(
                        title: "Email",
                        text: $authViewModel.email,
                        placeholder: "your@email.com",
                        contentType: .emailAddress,
                        keyboardType: .emailAddress
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
                
                // Reset Button
                Button {
                    Task {
                        await authViewModel.sendPasswordReset()
                        if authViewModel.errorMessage == nil {
                            emailSent = true
                        }
                    }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(authViewModel.email.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(authViewModel.email.isEmpty || authViewModel.isLoading)
                .padding(.horizontal)
            } else {
                // Success state
                Button {
                    dismiss()
                } label: {
                    Text("Back to Sign In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}

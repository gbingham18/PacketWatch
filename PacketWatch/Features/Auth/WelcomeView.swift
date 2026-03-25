// Features/Auth/WelcomeView.swift
//
// Initial welcome screen with sign in / sign up options.

import SwiftUI

struct WelcomeView: View {
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    HStack(alignment: .bottom, spacing: 2) {
                        Image("ZoomerZ")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 52)

                        Text("oomerProof")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Text("Unblock your ascension")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    NavigationLink(destination: SignUpView()) {
                        Text("Create Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: SignInView()) {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}

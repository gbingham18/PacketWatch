// Features/Auth/AuthComponents.swift
//
// Reusable components for auth forms.

import SwiftUI

// MARK: - Text Field

struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

// MARK: - Secure Field

struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var contentType: UITextContentType?
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textContentType(contentType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                
                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// MARK: - Previews

#Preview("Text Field") {
    VStack {
        AuthTextField(
            title: "Email",
            text: .constant(""),
            placeholder: "your@email.com",
            contentType: .emailAddress,
            keyboardType: .emailAddress
        )
        
        AuthSecureField(
            title: "Password",
            text: .constant(""),
            placeholder: "Enter password",
            contentType: .password
        )
    }
    .padding()
}

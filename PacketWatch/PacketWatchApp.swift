// PacketWatch/PacketWatchApp.swift

import SwiftUI
import FirebaseCore

// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        ServiceContainer.configure(for: .production)
        return true
    }
}

// MARK: - App Entry Point

@main
struct ZoomerProofApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isSignedIn {
                    if let user = authViewModel.currentUser, !user.onboardingComplete {
                        OnboardingView()
                    } else {
                        MainTabView()
                    }
                } else {
                    WelcomeView()
                }
            }
            .environmentObject(authViewModel)
            .task {
                await authViewModel.restoreSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingComplete)) { _ in
                Task { await authViewModel.restoreSession() }
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        let user = authViewModel.currentUser
        let hasNetworkList = user?.featureIds.contains(WellKnownFeatureIds.networkListFeatureId) ?? false
        let hasMonitored = user?.featureIds.contains(WellKnownFeatureIds.monitoredFeatureId) ?? false

        TabView(selection: $selectedTab) {
            if hasNetworkList {
                NetworksListView()
                    .tabItem {
                        Label("Networks", systemImage: "person.2")
                    }
                    .tag(0)
            }

            if hasMonitored {
                DashboardView()
                    .tabItem {
                        Label("My Activity", systemImage: "list.bullet")
                    }
                    .tag(1)
            }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(2)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}

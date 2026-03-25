//
//  ServiceContainer.swift
//  PacketWatch
//
//  Created by Grant Bingham on 3/3/26.
//

final class ServiceContainer {
    static private(set) var shared = ServiceContainer(configuration: .production)

    let authService: AuthService
    let storageService: BaseModelStorageService

    static func configure(for configuration: AppConfiguration) {
        shared = ServiceContainer(configuration: configuration)
    }

    private init(configuration: AppConfiguration) {
        switch configuration {
        case .production:
            self.authService = FirebaseAuthService.shared
            self.storageService = FirebaseBaseModelStorageService.shared
        case .mockAuth:
            self.authService = MockAuthService()
            self.storageService = UserDefaultsBaseModelStorageService.shared
        }
    }
}

enum AppConfiguration {
    case production
    case mockAuth
}

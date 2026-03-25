// Core/Features/WellKnownFeatureIds.swift
//
// Static feature IDs used to gate UI visibility.
// These are not user-facing and are not a substitute for Firestore security rules.

enum WellKnownFeatureIds {
    /// Unlocked when a user is part of at least one active accountability network as an ally.
    static let networkListFeatureId = "E3E3E3E3-0000-0000-0000-000000000001"

    /// Unlocked when a user selects the monitored role during onboarding.
    static let monitoredFeatureId = "E3E3E3E3-0000-0000-0000-000000000002"
}

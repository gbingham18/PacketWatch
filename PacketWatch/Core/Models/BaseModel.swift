// Core/Models/BaseModel.swift
//
// Base protocol for all archivable/persistable models.
// Ensures every stored entity has an identifier and is associated with a user.

import Foundation

/// Protocol that all persistable models must conform to.
/// Provides automatic user-scoped data management.
protocol BaseModel: Codable, Identifiable {
    /// Unique identifier for this model instance (Firebase UID or document ID)
    var id: String { get }

    /// The Firebase UID of the user who owns this data
    var dataOwnerId: String { get }
}

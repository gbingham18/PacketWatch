// Services/BaseModelStorageService.swift
//
// Generic storage service for persisting BaseModel types.
// Handles type-to-table mapping and provides CRUD operations.

import Foundation
import FirebaseFirestore

// MARK: - Search Filter

enum FilterOperation {
    // String comparisons
    case isEqualTo(String)
    case isNotEqualTo(String)
    case isGreaterThan(String)
    case isGreaterThanOrEqualTo(String)
    case isLessThan(String)
    case isLessThanOrEqualTo(String)
    // Array operations
    case arrayContains(String)
    case arrayContainsAny([String])
    case isIn([String])
    case isNotIn([String])
    // Date comparisons
    case isGreaterThanDate(Date)
    case isGreaterThanOrEqualToDate(Date)
    case isLessThanDate(Date)
    case isLessThanOrEqualToDate(Date)
}

struct FieldFilter {
    let fieldName: String
    let operation: FilterOperation
}

struct SearchFilter {
    let filters: [FieldFilter]
    let orderBy: String?
    let descending: Bool
    let limit: Int?

    init(filters: [FieldFilter] = [], orderBy: String? = nil, descending: Bool = true, limit: Int? = nil) {
        self.filters = filters
        self.orderBy = orderBy
        self.descending = descending
        self.limit = limit
    }
}

// MARK: - Protocol

/// Generic storage service for BaseModel types
protocol BaseModelStorageService {
    func save<T: BaseModel>(_ item: T) async throws
    func save<T: BaseModel>(_ item: T, toSubcollection subcollection: String, ofDocument documentId: String, inCollection collection: String) async throws
    func fetch<T: BaseModel>(id: String, type: T.Type) async throws -> T?
    func fetchAll<T: BaseModel>(matching filter: SearchFilter, type: T.Type) async throws -> [T]
    func fetchFromSubcollection<T: BaseModel>(subcollection: String, ofDocument documentId: String, inCollection collection: String, matching filter: SearchFilter, type: T.Type) async throws -> [T]
    func updateFields<T: BaseModel>(_ fields: [String: Any], id: String, type: T.Type) async throws
    func addSnapshotListener<T: BaseModel>(id: String, type: T.Type, onChange: @escaping (T) -> Void) -> ListenerRegistration
    func delete<T: BaseModel>(id: String, type: T.Type) async throws
    func deleteAll<T: BaseModel>(forOwner ownerId: String, type: T.Type) async throws
    func deleteFromSubcollection<T: BaseModel>(subcollection: String, ofDocument documentId: String, inCollection collection: String, matching filter: SearchFilter, type: T.Type) async throws
}

// MARK: - Type Registry

/// Maps model types to their Firestore collection names
class ModelTypeRegistry {
    static let shared = ModelTypeRegistry()

    private init() {}

    func collectionName<T: BaseModel>(for type: T.Type) -> String {
        let typeName = String(describing: type)
        switch typeName {
        case "ActivityEntry":           return "activity_entries"
        case "User":                    return "users"
        case "FilterSettings":          return "filter_settings"
        case "AccountabilityNetwork":   return "accountability_networks"
        case "ActivityReport":          return "activity_reports"
        case "Invitation":              return "invitations"
        case "ProposedFilterSettings":  return "proposed_filter_settings"
        case "ActivityStream":          return "activityStreams"
        default:                        return typeName.camelCaseToSnakeCase()
        }
    }
}

// MARK: - String Extensions

private extension String {
    func camelCaseToSnakeCase() -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.count)
        let snakeCase = regex?.stringByReplacingMatches(in: self, range: range, withTemplate: "$1_$2")
        return (snakeCase ?? self).lowercased()
    }
}

// MARK: - UserDefaults Implementation (mock/testing)

final class UserDefaultsBaseModelStorageService: BaseModelStorageService {

    static let shared = UserDefaultsBaseModelStorageService()

    private let userDefaults: UserDefaults
    private let registry = ModelTypeRegistry.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save<T: BaseModel>(_ item: T) async throws {
        let key = storageKey(collection: registry.collectionName(for: T.self), ownerId: item.dataOwnerId)
        var items = try fetchAllFromKey(key, type: T.self)
        items.removeAll { $0.id == item.id }
        items.append(item)
        userDefaults.set(try encoder.encode(items), forKey: key)
    }

    func save<T: BaseModel>(_ item: T, toSubcollection subcollection: String, ofDocument documentId: String, inCollection collection: String) async throws {
        // UserDefaults doesn't model subcollections — fall back to flat save keyed by parent path
        let key = storageKey(collection: "\(collection)_\(documentId)_\(subcollection)", ownerId: item.dataOwnerId)
        var items = try fetchAllFromKey(key, type: T.self)
        items.removeAll { $0.id == item.id }
        items.append(item)
        userDefaults.set(try encoder.encode(items), forKey: key)
    }

    func fetch<T: BaseModel>(id: String, type: T.Type) async throws -> T? {
        let collectionName = registry.collectionName(for: type)
        let prefix = "\(collectionName)_"
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            guard let data = userDefaults.data(forKey: key),
                  let items = try? decoder.decode([T].self, from: data) else { continue }
            if let item = items.first(where: { $0.id == id }) { return item }
        }
        return nil
    }

    func fetchAll<T: BaseModel>(matching filter: SearchFilter, type: T.Type) async throws -> [T] {
        // UserDefaults has no query support — scan all keys for this collection and return all
        // Filter application is not supported in this test-only implementation
        let collectionName = registry.collectionName(for: type)
        let prefix = "\(collectionName)_"
        var results: [T] = []
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            guard let data = userDefaults.data(forKey: key),
                  let items = try? decoder.decode([T].self, from: data) else { continue }
            results.append(contentsOf: items)
        }
        if let limit = filter.limit { results = Array(results.prefix(limit)) }
        return results
    }

    func fetchFromSubcollection<T: BaseModel>(subcollection: String, ofDocument documentId: String, inCollection collection: String, matching filter: SearchFilter, type: T.Type) async throws -> [T] {
        let key = storageKey(collection: "\(collection)_\(documentId)_\(subcollection)", ownerId: "")
        guard let data = userDefaults.data(forKey: key) else { return [] }
        var items = try decoder.decode([T].self, from: data)
        if let limit = filter.limit { items = Array(items.prefix(limit)) }
        return items
    }

    func updateFields<T: BaseModel>(_ fields: [String: Any], id: String, type: T.Type) async throws {
        // UserDefaults cannot do partial updates — no-op in test context
    }

    func addSnapshotListener<T: BaseModel>(id: String, type: T.Type, onChange: @escaping (T) -> Void) -> ListenerRegistration {
        MockListenerRegistration()
    }

    func delete<T: BaseModel>(id: String, type: T.Type) async throws {
        let collectionName = registry.collectionName(for: type)
        let prefix = "\(collectionName)_"
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            guard let data = userDefaults.data(forKey: key),
                  var items = try? decoder.decode([T].self, from: data) else { continue }
            let original = items.count
            items.removeAll { $0.id == id }
            if items.count != original {
                if items.isEmpty { userDefaults.removeObject(forKey: key) }
                else { userDefaults.set(try encoder.encode(items), forKey: key) }
                return
            }
        }
    }

    func deleteAll<T: BaseModel>(forOwner ownerId: String, type: T.Type) async throws {
        let key = storageKey(collection: registry.collectionName(for: type), ownerId: ownerId)
        userDefaults.removeObject(forKey: key)
    }

    func deleteFromSubcollection<T: BaseModel>(subcollection: String, ofDocument documentId: String, inCollection collection: String, matching filter: SearchFilter, type: T.Type) async throws {
        // UserDefaults has no query or batch delete support — no-op in test context
    }

    private func storageKey(collection: String, ownerId: String) -> String {
        "\(collection)_\(ownerId)"
    }

    private func fetchAllFromKey<T: Codable>(_ key: String, type: T.Type) throws -> [T] {
        guard let data = userDefaults.data(forKey: key) else { return [] }
        return (try? decoder.decode([T].self, from: data)) ?? []
    }
}

// MARK: - Firestore Serializable Protocol

/// Protocol for types that can serialize to/from a Firestore dictionary
protocol FirestoreSerializable {
    var asDictionary: [String: Any] { get }
    static func from(_ data: [String: Any]) -> Self?
}

// MARK: - Firestore Implementation

final class FirebaseBaseModelStorageService: BaseModelStorageService {

    static let shared = FirebaseBaseModelStorageService()

    private let db = Firestore.firestore()
    private let registry = ModelTypeRegistry.shared

    private init() {}

    func save<T: BaseModel>(_ item: T) async throws {
        guard let serializable = item as? FirestoreSerializable else {
            throw StorageError.serializationFailed("Type \(T.self) does not conform to FirestoreSerializable")
        }
        let collectionName = registry.collectionName(for: T.self)
        try await db.collection(collectionName).document(item.id).setData(serializable.asDictionary)
    }

    func save<T: BaseModel>(_ item: T, toSubcollection subcollection: String, ofDocument documentId: String, inCollection collection: String) async throws {
        guard let serializable = item as? FirestoreSerializable else {
            throw StorageError.serializationFailed("Type \(T.self) does not conform to FirestoreSerializable")
        }
        try await db.collection(collection).document(documentId).collection(subcollection).document(item.id).setData(serializable.asDictionary)
    }

    func fetch<T: BaseModel>(id: String, type: T.Type) async throws -> T? {
        guard type is FirestoreSerializable.Type else {
            throw StorageError.serializationFailed("Type \(T.self) does not conform to FirestoreSerializable")
        }
        let collectionName = registry.collectionName(for: type)
        let document = try await db.collection(collectionName).document(id).getDocument()
        guard let data = document.data() else { return nil }
        return (type as! FirestoreSerializable.Type).from(data) as? T
    }

    func fetchAll<T: BaseModel>(matching filter: SearchFilter, type: T.Type) async throws -> [T] {
        guard type is FirestoreSerializable.Type else {
            throw StorageError.serializationFailed("Type \(T.self) does not conform to FirestoreSerializable")
        }
        let collectionName = registry.collectionName(for: type)
        let query = applyFilter(filter, to: db.collection(collectionName))
        let snapshot = try await query.getDocuments()
        let serializableType = type as! FirestoreSerializable.Type
        return snapshot.documents.compactMap { serializableType.from($0.data()) as? T }
    }

    func fetchFromSubcollection<T: BaseModel>(subcollection: String, ofDocument documentId: String, inCollection collection: String, matching filter: SearchFilter, type: T.Type) async throws -> [T] {
        guard type is FirestoreSerializable.Type else {
            throw StorageError.serializationFailed("Type \(T.self) does not conform to FirestoreSerializable")
        }
        let ref = db.collection(collection).document(documentId).collection(subcollection)
        let query = applyFilter(filter, to: ref)
        let snapshot = try await query.getDocuments()
        let serializableType = type as! FirestoreSerializable.Type
        return snapshot.documents.compactMap { serializableType.from($0.data()) as? T }
    }

    private func applyFilter(_ filter: SearchFilter, to ref: CollectionReference) -> Query {
        var query: Query = ref
        for fieldFilter in filter.filters {
            query = applyFieldFilter(fieldFilter, to: query)
        }
        if let orderBy = filter.orderBy { query = query.order(by: orderBy, descending: filter.descending) }
        if let limit = filter.limit { query = query.limit(to: limit) }
        return query
    }

    private func applyFieldFilter(_ fieldFilter: FieldFilter, to query: Query) -> Query {
        switch fieldFilter.operation {
        case .isEqualTo(let value):                         return query.whereField(fieldFilter.fieldName, isEqualTo: value)
        case .isNotEqualTo(let value):                      return query.whereField(fieldFilter.fieldName, isNotEqualTo: value)
        case .isGreaterThan(let value):                     return query.whereField(fieldFilter.fieldName, isGreaterThan: value)
        case .isGreaterThanOrEqualTo(let value):            return query.whereField(fieldFilter.fieldName, isGreaterThanOrEqualTo: value)
        case .isLessThan(let value):                        return query.whereField(fieldFilter.fieldName, isLessThan: value)
        case .isLessThanOrEqualTo(let value):               return query.whereField(fieldFilter.fieldName, isLessThanOrEqualTo: value)
        case .arrayContains(let value):                     return query.whereField(fieldFilter.fieldName, arrayContains: value)
        case .arrayContainsAny(let values):                 return query.whereField(fieldFilter.fieldName, arrayContainsAny: values)
        case .isIn(let values):                             return query.whereField(fieldFilter.fieldName, in: values)
        case .isNotIn(let values):                          return query.whereField(fieldFilter.fieldName, notIn: values)
        case .isGreaterThanDate(let date):                  return query.whereField(fieldFilter.fieldName, isGreaterThan: date)
        case .isGreaterThanOrEqualToDate(let date):         return query.whereField(fieldFilter.fieldName, isGreaterThanOrEqualTo: date)
        case .isLessThanDate(let date):                     return query.whereField(fieldFilter.fieldName, isLessThan: date)
        case .isLessThanOrEqualToDate(let date):            return query.whereField(fieldFilter.fieldName, isLessThanOrEqualTo: date)
        }
    }

    func updateFields<T: BaseModel>(_ fields: [String: Any], id: String, type: T.Type) async throws {
        let collectionName = registry.collectionName(for: type)
        try await db.collection(collectionName).document(id).updateData(fields)
    }

    func addSnapshotListener<T: BaseModel>(id: String, type: T.Type, onChange: @escaping (T) -> Void) -> ListenerRegistration {
        guard type is FirestoreSerializable.Type else {
            return db.collection(registry.collectionName(for: type)).document(id).addSnapshotListener { _, _ in }
        }
        let collectionName = registry.collectionName(for: type)
        let serializableType = type as! FirestoreSerializable.Type
        return db.collection(collectionName).document(id).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data(), let item = serializableType.from(data) as? T else { return }
            onChange(item)
        }
    }

    func delete<T: BaseModel>(id: String, type: T.Type) async throws {
        let collectionName = registry.collectionName(for: type)
        try await db.collection(collectionName).document(id).delete()
    }

    func deleteAll<T: BaseModel>(forOwner ownerId: String, type: T.Type) async throws {
        let collectionName = registry.collectionName(for: type)
        let snapshot = try await db.collection(collectionName)
            .whereField("dataOwnerId", isEqualTo: ownerId)
            .getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }

    func deleteFromSubcollection<T: BaseModel>(subcollection: String, ofDocument documentId: String, inCollection collection: String, matching filter: SearchFilter, type: T.Type) async throws {
        let ref = db.collection(collection).document(documentId).collection(subcollection)
        let query = applyFilter(filter, to: ref)
        let snapshot = try await query.getDocuments()
        let batch = db.batch()
        for document in snapshot.documents { batch.deleteDocument(document.reference) }
        try await batch.commit()
    }
}

// MARK: - Mock Listener Registration

final class MockListenerRegistration: NSObject, ListenerRegistration {
    func remove() {}
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case serializationFailed(String)

    var errorDescription: String? {
        switch self {
        case .serializationFailed(let message):
            return "Serialization failed: \(message)"
        }
    }
}

// MARK: - FirestoreSerializable Conformances

extension User: FirestoreSerializable {}
extension FilterSettings: FirestoreSerializable {}
extension AccountabilityNetwork: FirestoreSerializable {}
extension Invitation: FirestoreSerializable {}
extension ActivityStream: FirestoreSerializable {}

extension ActivityEntry: FirestoreSerializable {
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "dataOwnerId": dataOwnerId,
            "domain": domain,
            "timestamp": Timestamp(date: timestamp),
            "source": source.rawValue,
            "isFlagged": isFlagged
        ]
        if let category { dict["category"] = category }
        if let inferredApp { dict["inferredApp"] = inferredApp }
        if let appConfidence { dict["appConfidence"] = appConfidence }
        if let monitoringLevel { dict["monitoringLevel"] = monitoringLevel }
        return dict
    }

    static func from(_ data: [String: Any]) -> ActivityEntry? {
        guard let id = data["id"] as? String,
              let dataOwnerId = data["dataOwnerId"] as? String,
              let domain = data["domain"] as? String,
              let sourceRaw = data["source"] as? String,
              let source = DetectionSource(rawValue: sourceRaw) else {
            return nil
        }

        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let isFlagged = data["isFlagged"] as? Bool ?? false

        return ActivityEntry(
            id: id,
            dataOwnerId: dataOwnerId,
            domain: domain,
            timestamp: timestamp,
            source: source,
            category: data["category"] as? String,
            isFlagged: isFlagged,
            inferredApp: data["inferredApp"] as? String,
            appConfidence: data["appConfidence"] as? String,
            monitoringLevel: data["monitoringLevel"] as? String
        )
    }
}

//
//  CoreDataStack.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 15/07/26.
//

import Foundation
import CoreData

protocol CoreDataStoreProtocol {
    /// Checks if we have any events saved locally on disk
    func hasSavedEvents() async -> Bool

    /// Fetches all cached events from our local database
    func fetchCachedEvents() async throws -> [Event]

    /// Save a fresh network payload with disk (clears old events, keeps bookmarks)
    func saveEvents(_ remoteEvents: [Event]) async throws

    /// Returns a Set of all bookmarked event IDs
    func fetchBookmarkedIds() async -> Set<Int>

    /// Toggles the bookmark state for a specific event ID and returns the new state
    func toggleBookmark(eventId: Int) async throws -> Bool
}

/// Centralized registry for all Core Data entity names.
enum CoreDataEntities {
    // 1. Fetch names dynamically from the class type
    static let cdEvent = CDEvent.entity().name ?? "CDEvent"
    static let cdBookmark = CDBookmark.entity().name ?? "CDBookmark"
}

final class CoreDataStack: CoreDataStoreProtocol {

    static let shared = CoreDataStack()
    private let modelName = "LocalEventsExplorer"

    private init() {}

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data Store failed to load: \(error), \(error.userInfo)")
            }
        }
        // Automatically merge changes written in background context to view context (UI)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    func hasSavedEvents() async -> Bool {
            let context = viewContext
            return await context.perform {
                let request: NSFetchRequest<CDEvent> = CDEvent.fetchRequest()
                request.includesSubentities = false // Performance tweak
                do {
                    let count = try context.count(for: request)
                    return count > 0
                } catch {
                    return false
                }
            }
        }

    // MARK: - Safe Asynchronous Database Writing
    func saveEvents(_ events: [Event]) async throws {
        // Create a dedicated background context for heavy writing
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // perform(_:) executes the block on the background context's private queue
        try await backgroundContext.perform {
            // 1. Clear old cached events (Truncate table for clean sync)
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: CoreDataEntities.cdEvent)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try backgroundContext.execute(deleteRequest)

            // 2. Insert fresh events
            for event in events {
                let cdEvent = NSEntityDescription.insertNewObject(forEntityName: CoreDataEntities.cdEvent, into: backgroundContext)
                cdEvent.setValue(event.id, forKey: "id")
                cdEvent.setValue(event.title, forKey: "title")
                cdEvent.setValue(event.locationName, forKey: "locationName")
                cdEvent.setValue(event.latitude, forKey: "latitude")
                cdEvent.setValue(event.longitude, forKey: "longitude")
                cdEvent.setValue(event.timestamp, forKey: "timestamp")
                cdEvent.setValue(event.imageUrlString, forKey: "imageUrlString")
            }

            // 3. Persist the background context.
            // Because automaticallyMergesChangesFromParent is true, viewContext is notified immediately.
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
        }

        // Save execution time to check TTL cache freshness
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_fetch_time")
    }

    // MARK: - Synchronous Safe Local Reads

    func fetchCachedEvents() throws -> [Event] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: CoreDataEntities.cdEvent)

        var events: [Event] = []
        try viewContext.performAndWait {
            let results = try viewContext.fetch(fetchRequest)
            events = results.map { cdEvent in
                Event(
                    id: cdEvent.value(forKey: "id") as? Int ?? 0,
                    title: cdEvent.value(forKey: "title") as? String ?? "",
                    locationName: cdEvent.value(forKey: "locationName") as? String ?? "",
                    latitude: cdEvent.value(forKey: "latitude") as? Double ?? 0.0,
                    longitude: cdEvent.value(forKey: "longitude") as? Double ?? 0.0,
                    timestamp: cdEvent.value(forKey: "timestamp") as? Date ?? Date(),
                    imageUrlString: cdEvent.value(forKey: "imageUrlString") as? String ?? "",
                )
            }
        }
        return events
    }

    func toggleBookmark(eventId: Int) throws -> Bool {
        var isBookmarked = false
        try viewContext.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: CoreDataEntities.cdBookmark)
            fetchRequest.predicate = NSPredicate(format: "id == %lld", eventId)
            let results = try viewContext.fetch(fetchRequest)

            if let existing = results.first {
                viewContext.delete(existing)
                isBookmarked = false
            } else {
                let bookmark = NSEntityDescription.insertNewObject(forEntityName: CoreDataEntities.cdBookmark, into: viewContext)
                bookmark.setValue(eventId, forKey: "id")
                isBookmarked = true
            }
            try viewContext.save()
        }
        return isBookmarked
    }

    func fetchBookmarkedIds() -> Set<Int> {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: CoreDataEntities.cdBookmark)
        var ids = Set<Int>()
        viewContext.performAndWait {
            guard let results = try? viewContext.fetch(fetchRequest) else { return }
            let list = results.compactMap { $0.value(forKey: "id") as? Int }
            ids = Set(list)
        }
        return ids
    }

    func isCacheExpired(ttl: TimeInterval) -> Bool {
        let lastFetch = UserDefaults.standard.double(forKey: "last_fetch_time")
        guard lastFetch > 0 else { return true }
        return (Date().timeIntervalSince1970 - lastFetch) > ttl
    }
}

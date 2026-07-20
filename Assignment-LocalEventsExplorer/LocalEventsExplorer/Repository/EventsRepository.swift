//
//  EventsRepository.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 15/07/26.
//

import Foundation

protocol EventsRepositoryProtocol {
    /// Get All Events
    func getEvents(forceRefresh: Bool) async throws -> [Event]

    /// Get Bookmark Ids saved
    func getBookmarkedIds() async -> Set<Int>

    /// Toggle Bookmarks for specifc ID
    func toggleBookmark(id: Int) async throws -> Bool
}

final class EventsRepository: EventsRepositoryProtocol {
    private let network: NetworkManagerProtocol // NetworkManager
    private let localStore: CoreDataStoreProtocol // Core Data helper

    init(
        network: NetworkManagerProtocol = NetworkManager.shared,
        localStore: CoreDataStoreProtocol = CoreDataStack.shared
    ) {
        self.network = network
        self.localStore = localStore
    }

    func getEvents(forceRefresh: Bool = false) async throws -> [Event] {
        // Check if we should use cached data
        let hasCachedEvents = await localStore.hasSavedEvents()

        if hasCachedEvents && !forceRefresh && !CacheConfiguration.isCacheExpired {
            print("TTL Active: Fetching events cleanly from Core Data cache.")
            return try await localStore.fetchCachedEvents()
        }

        // Cache is expired or forceRefresh is true -> Fetch from Network
        print("Cache expired or refresh requested. Querying network API...")
        do {
            let remoteEvents = try await network.fetchEventsJSON()

            // Update the persistent disk cache & update the TTL timer
            try await localStore.saveEvents(remoteEvents)
            CacheConfiguration.updateLastSyncTimestamp()

            return remoteEvents
        } catch {
            // Graceful Network Failure Fallback
            if hasCachedEvents {
                print(" Network call failed. Falling back gracefully to expired cache.")
                return try await localStore.fetchCachedEvents()
            } else {
                // If there is absolutely no cache and the network is down, propagate the error
                throw error
            }
        }
    }

    func getBookmarkedIds() async -> Set<Int> {
        return await localStore.fetchBookmarkedIds()
    }

    func toggleBookmark(id: Int) async throws -> Bool {
        return try await localStore.toggleBookmark(eventId: id)
    }
}

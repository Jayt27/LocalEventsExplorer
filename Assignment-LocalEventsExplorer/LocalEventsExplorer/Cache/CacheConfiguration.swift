//
//  CacheConfiguration.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 16/07/26.
//

import Foundation

struct CacheConfiguration {
    /// Time-to-live threshold (e.g., 10 minutes)
    static let ttlInterval: TimeInterval = 10 * 60
    private static let lastSyncKey = "com.rogerevents.lastSyncTimestamp"

    /// Determines if the local cache has expired
    static var isCacheExpired: Bool {
        guard let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date else {
            return true // No prior sync exists, cache is expired
        }
        let elapsed = Date().timeIntervalSince(lastSync)
        return elapsed > ttlInterval
    }

    /// Updates the sync timestamp to the current time
    static func updateLastSyncTimestamp() {
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
    }
}

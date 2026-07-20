//
//  EventsViewModel.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 15/07/26.
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class EventsViewModel {

    // MARK: - Published States (Bound to UI)
    // Core state holding all available events fetched from the repository
    private var allEvents: [Event] = []
    @Published private(set) var events: [Event] = []
    @Published private(set) var bookmarkedIds: Set<Int> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private(set) var repository: EventsRepositoryProtocol
    private var userLocation: CLLocation?
    // Tracks whether the bookmark filter is currently turned on
    private(set) var isFilteringBookmarks: Bool = false

    init(repository: EventsRepositoryProtocol? = nil) {
        self.repository = repository ?? EventsRepository()
    }

    // MARK: - Intent/Actions

    func fetchEvents(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            self.allEvents = try await repository.getEvents(forceRefresh: forceRefresh)
            self.bookmarkedIds = await repository.getBookmarkedIds()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleBookmark(for eventId: Int) async {
        do {
            let isNowBookmarked = try await repository.toggleBookmark(id: eventId)
            if isNowBookmarked {
                bookmarkedIds.insert(eventId)
            } else {
                bookmarkedIds.remove(eventId)
            }
        } catch {
            self.errorMessage = "Could not update bookmark."
        }
    }

    /// Refreshes bookmark state without making unnecessary network calls
        func updateBookmarkStateOnly() async {
            self.bookmarkedIds = await repository.getBookmarkedIds()
            applyCurrentFilter()
        }

        /// Toggles the filter state flag and pushes the correct dataset to the view
        func toggleBookmarkFilter() {
            isFilteringBookmarks.toggle()
            applyCurrentFilter()
        }

    /// Internal filter engine mapping raw data to presentation streams
        func applyCurrentFilter() {
            if isFilteringBookmarks {
                // Show only the events whose IDs exist inside the bookmark database set
                events = allEvents.filter { bookmarkedIds.contains($0.id) }
            } else {
                // Fallback to presenting everything
                events = allEvents
            }
        }
        func isEventBookmarked(_ eventId: Int) -> Bool {
            return bookmarkedIds.contains(eventId)
        }
}

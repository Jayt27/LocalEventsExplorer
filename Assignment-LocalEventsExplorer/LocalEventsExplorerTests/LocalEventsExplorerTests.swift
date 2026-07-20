//
//  LocalEventsExplorerTests.swift
//  LocalEventsExplorerTests
//
//  Created by Jay Thakkar on 15/07/26.
//

import XCTest
@testable import LocalEventsExplorer
import _LocationEssentials

final class LocalEventsExplorerTests: XCTestCase {

    var repository: EventsRepository!
    var mockNetwork: MockNetworkManager!
    var mockLocal: MockLocalStore!

    override func setUp() {
        super.setUp()
        mockNetwork = MockNetworkManager()
        mockLocal = MockLocalStore()
        repository = EventsRepository(network: mockNetwork, localStore: mockLocal)
    }

    func testGetEvents_WhenCacheValid_ReturnsLocalData() async throws {
        // Arrange
        let cachedEvent = Event(id: 1,
                                title: "Swift Local Meetup",
                                locationName: "Calgary",
                                latitude: 0,
                                longitude: 0,
                                timestamp: Date(),
                                imageUrlString: "")
        mockLocal.cachedEvents = [cachedEvent]
        mockLocal.isExpired = false

        // Act
        let result = try await repository.getEvents(forceRefresh: false)

        // Assert
        XCTAssertEqual(result.count, 1)
        let title = await result.first?.title
        XCTAssertEqual(title, "Swift Local Meetup")
    }

    func testGetEvents_WhenNetworkThrows_FallsbackToCache() async throws {
        // Arrange
        let cachedEvent = Event(id: 1,
                                title: "Offline Backup Event",
                                locationName: "Toronto",
                                latitude: 0,
                                longitude: 0,
                                timestamp: Date(),
                                imageUrlString: "")
        mockLocal.cachedEvents = [cachedEvent]
        mockLocal.isExpired = true

        // Setup mock network to simulate connection failure
        mockNetwork.shouldFail = true

        // Act
        let result = try await repository.getEvents(forceRefresh: false)

        // Assert
        XCTAssertEqual(result.count, 1)

        let title = await result.first?.title
        XCTAssertEqual(title, "Offline Backup Event")
    }

    @MainActor
    func test_listViewModel_toggleBookmarkFilter_filtersInMemory() async {
        // Arrange
        let mockRepo = MockEventsRepository()

        let event1 =  Event(id: 1,
                            title: "A",
                            locationName: "Toronto - A",
                            latitude: 0,
                            longitude: 0,
                            timestamp: Date(),
                            imageUrlString: "")
        let event2 =  Event(id: 2,
                            title: "B",
                            locationName: "Toronto - B",
                            latitude: 0,
                            longitude: 0,
                            timestamp: Date(),
                            imageUrlString: "")

        mockRepo.mockEvents = [event1, event2]
        mockRepo.mockBookmarkedIds = [1] // Only event 1 is saved in the bookmark index

        let viewModel = EventsViewModel(repository: mockRepo)
        await viewModel.fetchEvents(forceRefresh: true)

        // Act
        viewModel.toggleBookmarkFilter() // Turn filter ON

        // Assert
        XCTAssertTrue(viewModel.isFilteringBookmarks)
        XCTAssertEqual(viewModel.events.count, 1)
        XCTAssertEqual(viewModel.events.first?.id, 1, "Only the bookmarked element should be visible.")
    }

    @MainActor
    func test_detailViewModel_computesCorrectDistanceInKilometers() {
        // Arrange
        // Toronto Coordinates (Event Location)
        let event =  Event(id: 9,
                            title: "oronto Show",
                            locationName: "Center",
                            latitude: 43.6532,
                            longitude: -79.3832,
                            timestamp: Date(),
                            imageUrlString: "")

        let viewModel = EventDetailViewModel(event: event, isBookmarked: false)

        // Montreal Coordinates (Simulated User Location)
        let userLocation = CLLocation(latitude: 45.5017, longitude: -73.5673)

        viewModel.updateUserLocation(userLocation)
        // Act
        let computedDistance = viewModel.calculateDistance() // Extracted core math utility

        // Assert
        // Physical distance from Toronto to Montreal is ~500km
        XCTAssertEqual(computedDistance, 504.0, accuracy: 5.0, "The spatial distance logic should compute correctly within a reasonable margin.")
    }

    @MainActor
    func test_detailViewModel_DistanceWithoutUserLocation() {
        // Arrange
        // Toronto Coordinates (Event Location)
        let event =  Event(id: 9,
                            title: "oronto Show",
                            locationName: "Center",
                            latitude: 43.6532,
                            longitude: -79.3832,
                            timestamp: Date(),
                            imageUrlString: "")
        let viewModel = EventDetailViewModel(event: event, isBookmarked: false)

        // Act
        let computedDistance = viewModel.calculateDistance() // Extracted core math utility

        // Assert
        XCTAssertEqual(computedDistance, 0)
    }
}

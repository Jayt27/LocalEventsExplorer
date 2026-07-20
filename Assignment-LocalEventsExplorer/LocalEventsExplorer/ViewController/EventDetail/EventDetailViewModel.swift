//
//  EventDetailViewModel.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 16/07/26.
//

import Foundation
import CoreLocation

@MainActor
final class EventDetailViewModel {

    let title: String
    let imageUrlString: String
    let locationName: String

    private let event: Event
    private var userLocation: CLLocation?

    /// Tracks the live bookmark state
    private(set) var isBookmarked: Bool

    /// Simple callback to notify the ViewController to refresh its labels
    var onLocationUpdated: ((String) -> Void)?

    init(event: Event, isBookmarked: Bool) {
        self.isBookmarked = isBookmarked

        self.event = event
        self.title = event.title
        self.imageUrlString = event.imageUrlString
        self.locationName = event.locationName

    }

    /// Updates the user's location and triggers the update UI callback
    func updateUserLocation(_ location: CLLocation) {
        self.userLocation = location
        onLocationUpdated?(distanceAndLocationText)
    }

    /*
     /// Computes user distance or falls back to just the location name
     var distanceAndLocationText: String {
     guard let userLoc = userLocation else {
     return locationName
     }
     let eventLoc = CLLocation(latitude: event.latitude, longitude: event.longitude)
     let distanceInKm = userLoc.distance(from: eventLoc) / 1000.0
     return String(format: "%@\n(%.1f km away)", event.locationName, distanceInKm)
     }
     */

    var distanceAndLocationText: String {
        if calculateDistance() == 0 {
            return "Sorry, We are not able to find distance. Please check your location settings."
        } else {
            return String(format: "%@\n(%.1f km away)", event.locationName, calculateDistance())
        }
    }

    func calculateDistance() -> Double {
        guard let userLoc = userLocation else {
            return 0
        }
        let eventLoc = CLLocation(latitude: event.latitude, longitude: event.longitude)
        return userLoc.distance(from: eventLoc) / 1000.0
    }

    var coordinates: (latitude: Double, longitude: Double) {
        return (event.latitude, event.longitude)
    }
}

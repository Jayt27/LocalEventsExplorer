//
//  Event.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 15/07/26.
//

import Foundation
import CoreLocation

struct Event: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let imageUrlString: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case locationName = "location"
        case latitude, longitude
        case timestamp = "time"
        case imageUrlString = "image_url"
    }
}

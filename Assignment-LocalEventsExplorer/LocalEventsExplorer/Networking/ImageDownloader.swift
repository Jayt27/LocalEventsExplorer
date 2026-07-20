//
//  ImageDownloader.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 15/07/26.
//

import UIKit

actor ImageDownloader {
    static let shared = ImageDownloader()

    private let cache = NSCache<NSString, UIImage>()
    private let noImage = UIImage(named: "no-image")

    private init() {
        cache.totalCostLimit = 1024 * 1024 * 50 // 50MB Memory Limit
    }

    func downloadImage(from urlString: String) async -> UIImage? {
        if urlString.isEmpty { return noImage }
        let cacheKey = NSString(string: urlString)

        // Actor isolation guarantees safe access to the NSCache
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let url = URL(string: urlString) else { return noImage }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return noImage }

            cache.setObject(image, forKey: cacheKey, cost: data.count)
            return image
        } catch {
            return noImage
        }
    }
}

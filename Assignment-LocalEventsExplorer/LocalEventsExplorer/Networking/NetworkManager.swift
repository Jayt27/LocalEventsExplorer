import Foundation

protocol NetworkManagerProtocol {
//    func fetchEvents() async throws -> [Event]
    func fetchEventsJSON() async throws -> [Event]
}

final class NetworkManager: NetworkManagerProtocol {
    static let shared = NetworkManager()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

  /*  func fetchEvents() async throws -> [Event] {
        guard let url = URL(string: "https://api.mockevents.com/v1/nearby") else {
            throw URLError(.badURL)
        }

        // Native async network fetch
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Event].self, from: data)
    }*/

    func fetchEventsJSON() async throws -> [Event] {
            // Simulating network latency (0.5 seconds) so the UI shows a loading state
            try await Task.sleep(nanoseconds: 500_000_000)

            // Locate the file in the Main App Bundle
            guard let fileURL = Bundle.main.url(forResource: "MockEvents", withExtension: "json") else {
                throw URLError(.fileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "MockEvents.json not found"])
            }

            do {
                // Load the data asynchronously
                let data = try Data(contentsOf: fileURL)

                // Decode the data
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                return try decoder.decode([Event].self, from: data)
            } catch {
                print("Decoding Error: \(error)")
                throw error
            }
        }
}

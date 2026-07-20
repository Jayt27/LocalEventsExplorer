//
//  BackgroundRefreshManager.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 15/07/26.
//

import Foundation
import BackgroundTasks

final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()

    /// The unique identifier matching your Info.plist 'Permitted background task scheduler identifiers'
    private let taskIdentifier = "com.rogerevents.refresh"
    private let repository: EventsRepositoryProtocol

    /// Inject dependency to allow easy mocking during testing
    init(repository: EventsRepositoryProtocol = EventsRepository()) {
        self.repository = repository
    }

    /// Registers the background task. Must be called before application finished launching.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
            guard let self = self else { return }
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: appRefreshTask)
        }
    }

    /// Schedules a low-frequency refresh task (e.g., to run no earlier than 4 hours from now)
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hours

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Successfully scheduled background refresh.")
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }

    /// Coordinates asynchronous execution of data syncing
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Reschedule immediately for the next interval cycle
        scheduleAppRefresh()

        // Define a cooperative cancellation pathway if iOS cuts the background time short
        let fetchTask = Task {
            do {
                // Fetch and update cache off-main-thread
                _ = try await repository.getEvents(forceRefresh: true)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            fetchTask.cancel() // Cancel the Swift asynchronous task cooperatively
        }
    }
}

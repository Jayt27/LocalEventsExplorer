//
//  EventsListViewController.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 16/07/26.
//

import UIKit
import Combine
import CoreLocation

@MainActor
final class EventsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    private var filterBarButtonItem: UIBarButtonItem?

    private let viewModel: EventsViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependency Injection Initializer
    init(viewModel: EventsViewModel? = nil) {
        self.viewModel = viewModel ?? EventsViewModel()
        // Explicitly load the nib file sharing the same class name
        super.init(nibName: "EventsListViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nearby Events"

        setupTableView()
        setupNavigationBarFilter()
        bindViewModel()

        Task {
            await viewModel.fetchEvents()
        }
    }
    private func setupNavigationBarFilter() {
        title = "Local Events"
        // Define the button layout natively in code
        filterBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "bookmark"),
            style: .plain,
            target: self,
            action: #selector(filterButtonTapped)
        )
        navigationItem.rightBarButtonItem = filterBarButtonItem
    }

    @objc private func filterButtonTapped() {
        // Toggle the flag in the ViewModel layer
        viewModel.toggleBookmarkFilter()

        // Instantly alter the icon state visually
        updateFilterButtonIcon()
    }

    private func updateFilterButtonIcon() {
        let isFiltering = viewModel.isFilteringBookmarks

        // Use filled icon when filtering is actively turned on
        let imageName = isFiltering ? "bookmark.fill" : "bookmark"
        filterBarButtonItem?.image = UIImage(systemName: imageName)

        // Optional: Update title text contextually to guide the user
        title = isFiltering ? "Bookmarked" : "Local Events"
    }

    // MARK: - MVVM Combine Bindings
    private func bindViewModel() {
        // 1. Bind Events list changes to table reload
        viewModel.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        // 2. Bind Bookmark state changes
        viewModel.$bookmarkedIds
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
                self?.viewModel.applyCurrentFilter()
            }
            .store(in: &cancellables)

        // 3. Bind Loading Indicator
        viewModel.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                if isLoading, self?.loadingIndicator.isHidden ?? true {
                    self?.loadingIndicator.isHidden = false
                    self?.loadingIndicator.startAnimating()
                } else {

                    self?.loadingIndicator.stopAnimating()
                    self?.loadingIndicator.isHidden = true
                }
            }
            .store(in: &cancellables)

        // 4. Bind Error Messages
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.showErrorAlert(message: message)
            }
            .store(in: &cancellables)
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self

        // Register the custom XIB cell
        let nib = UINib(nibName: "EventsListCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "EventsListCell")
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default))
        present(alert, animated: true)
    }

    // MARK: - TableView Methods

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.events.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "EventsListCell", for: indexPath) as? EventsListCell else {
            return UITableViewCell()
        }

        let event = viewModel.events[indexPath.row]
        let isBookmarked = viewModel.isEventBookmarked(event.id)

        // 1. Configure the visual elements of the cell
        cell.configure(event: event, isBookmarked: isBookmarked)

        // 2. Handle the bookmark button tap safely without creating a retain cycle
        cell.onBookmarkTapped = { [weak self] in
            guard let self = self else { return }
            Task {
                await self.viewModel.toggleBookmark(for: event.id)
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedEvent = viewModel.events[indexPath.row]
        let isBookmarked = viewModel.isEventBookmarked(selectedEvent.id)

        // 1. Initialize ViewModel with just the event
        let detailViewModel = EventDetailViewModel(event: selectedEvent, isBookmarked: isBookmarked)

        // 2. Initialize XIB-backed Detail View Controller
        let detailViewController = EventDetailViewController(viewModel: detailViewModel)

        // 3. Push cleanly
        navigationController?.pushViewController(detailViewController, animated: true)
    }

    @objc private func bookmarkTapped(_ sender: UIButton) {
        let index = sender.tag
        let event = viewModel.events[index]

        Task {
            await viewModel.toggleBookmark(for: event.id)
        }
    }
}

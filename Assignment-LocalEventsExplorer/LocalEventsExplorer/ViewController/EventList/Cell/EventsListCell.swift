//
//  EventsListCell.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 16/07/26.
//

import UIKit

final class EventsListCell: UITableViewCell {

    // MARK: - IBOutlets 
    @IBOutlet weak var eventImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var bookmarkButton: UIButton!

    // Callback closure to notify the View Controller when bookmarked
    var onBookmarkTapped: (() -> Void)?

    private var imageDownloadTask: Task<Void, Never>?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 1. Cancel any active image downloads to save bandwidth on fast scrolling
        imageDownloadTask?.cancel()
        imageDownloadTask = nil

        // 2. Reset visual states to avoid cell "ghosting"
        eventImageView.image = nil
        onBookmarkTapped = nil
    }

    private func setupUI() {
        selectionStyle = .none
        eventImageView.layer.cornerRadius = 8
        eventImageView.clipsToBounds = true
    }

    // MARK: - Configuration
    func configure(event: Event, isBookmarked: Bool, ) {
        titleLabel.text = event.title
        locationLabel.text = event.locationName

        // Update bookmark icon state
        let bookmarkImage = UIImage(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
        bookmarkButton.setImage(bookmarkImage, for: .normal)

        // Fetch image asynchronously using our thread-safe actor
        imageDownloadTask = Task {
            if let image = await ImageDownloader.shared.downloadImage(from: event.imageUrlString) {
                // Ensure the task wasn't cancelled while downloading before setting the image
                if !Task.isCancelled {
                    self.eventImageView.image = image
                }
            }
        }
    }

    // MARK: - IBActions
    @IBAction private func bookmarkButtonTapped(_ sender: UIButton) {
        onBookmarkTapped?()
    }
}

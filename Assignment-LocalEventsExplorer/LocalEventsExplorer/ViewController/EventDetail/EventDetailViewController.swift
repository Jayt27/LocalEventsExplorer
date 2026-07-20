//
//  EventDetailViewController.swift
//  LocalEventsExplorer
//
//  Created by Jay Thakkar on 16/07/26.
//

import UIKit
import CoreLocation
import MapKit

final class EventDetailViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailBookmarkButton: UIButton!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var navigationButton: UIButton!

    private let viewModel: EventDetailViewModel
    private let locationManager = CLLocationManager()

    // MARK: - Custom Init
    init(viewModel: EventDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "EventDetailViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocationManager()
    }

    private func setupUI() {
        title = "Event Details"

        titleLabel.text = viewModel.title
        locationLabel.text = viewModel.locationName

        let imageName = viewModel.isBookmarked ? "bookmark.fill" : "bookmark"
        self.detailBookmarkButton.setImage(UIImage(systemName: imageName), for: .normal)

        // Load image asynchronously
        Task {
            if let image = await ImageDownloader.shared.downloadImage(from: viewModel.imageUrlString) {
                self.imageView.image = image
            }
        }

        // Setup navigation button tap action
        navigationButton.addTarget(self, action: #selector(navigationButtonTapped), for: .touchUpInside)
    }

    // MARK: - Native Feature 1: Request Location Permission
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // This natively triggers the iOS location permission alert dialog
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Request a single high-accuracy update to save battery life
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Location access denied by user.")
        @unknown default:
            break
        }
    }

    // MARK: - OPEN direction in Apple Maps
    @objc private func navigationButtonTapped() {
        let coords = viewModel.coordinates
        let destinationCoordinates = CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)

        let placemark = MKPlacemark(coordinate: destinationCoordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = viewModel.title

        // Force Apple Maps to open in Driving Directions mode
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
}

// MARK: - CLLocationManagerDelegate (Native Feature : Show Distance)
extension EventDetailViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }

        // Calculate distance
        let eventLocation = CLLocation(latitude: viewModel.coordinates.latitude, longitude: viewModel.coordinates.longitude)

        // distance(from:) returns meters -> convert to kilometers
        let distanceInKilometers = userLocation.distance(from: eventLocation) / 1000.0

        // Update the UI label to show the calculated distance
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.distanceLabel.text = String(format: "%.1f km away", distanceInKilometers)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location retrieval failed: \(error.localizedDescription)")
    }
}

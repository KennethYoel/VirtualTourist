//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Kenneth Gutierrez on 6/21/22.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import CoreData

class LocationMapViewController: UIViewController, CLLocationManagerDelegate {
    // MARK: Properties
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let manager = CLLocationManager()
    let locationView = TravelLocationView()
    let longPress: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
    let regionKey: String = "mapRegionLastState"
    var locationPins : [MKPointAnnotation] = []
    var lat: Double!
    var long: Double!
    
    // MARK: Outlets
    
    @IBOutlet weak var locationMapView: MKMapView!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get users current location
        manager.requestAlwaysAuthorization()
        manager.delegate = self
        
        locationView.delegate = self
        locationView.addCachedPins()
    
        // retrieve last center coordinate of the mapView
        if let savedMapState = UserDefaults.standard.value(forKey: "hasLaunchedBefore") {
            if savedMapState as! Bool {
                userDefaultMapState()
            } else {
                // set the starting coordinates of the map view to the user current location
                manager.requestLocation()
            }
        } else {
            // first time launching app
            UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")
            manager.requestLocation()
        }
        
        // tapping and holding the map drops a new pin. Users can place numerous number of pins on the map
        longPress.addTarget(self, action: #selector(registeredLongPress(_:)))
        locationMapView.addGestureRecognizer(longPress)
    }
    
    // MARK: Persistent Map Location
    
    // if the app is turned off, the map should return to the same state when it is turned on again
    func userDefaultMapState() {
        if let mapRegion = UserDefaults.standard.dictionary(forKey: regionKey) {
            let location = mapRegion as! [String: CLLocationDegrees]
            let center = CLLocationCoordinate2D(latitude: location["latitude"]!, longitude: location["longitude"]!)
            let span = MKCoordinateSpan(latitudeDelta: location["latitudeDelta"]!, longitudeDelta: location["longitudeDelta"]!)
            
            locationView.centerToLocation(location: center, span: span)
        }
    }
    
    // receiving location updates using standard location service
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.first {
            // do something with the location
            lat = lastLocation.coordinate.latitude
            long = lastLocation.coordinate.longitude
            
            // set the starting coordinates of the map view to the user current location
            let initialLocation = CLLocationCoordinate2D(latitude: lat, longitude: long)
            let initialsSpan = MKCoordinateSpan(latitudeDelta: locationMapView.region.span.latitudeDelta, longitudeDelta: locationMapView.region.span.longitudeDelta)
            
            // calls the helper method to zoom into usersLocation on startup
            locationView.centerToLocation(location: initialLocation, span: initialsSpan)
        }
    }
    
    // handling location-related errors when the location manager is unable to deliver location updates
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
       if let error = error as? CLError, error.code == .denied {
          // location updates are not authorized
          manager.stopUpdatingLocation()
          return
       }
        // notify the user of any errors
        self.handleFailureAlert(title: "Location Issue", message: "Failed to find user's location: \(error.localizedDescription)")
    }

    // MARK: Helper Methods
    
    func getAnnotations(){
        if !locationView.pinDrops.isEmpty {
            for location in locationView.pinDrops {
                let lat = CLLocationDegrees(location.latitude)
                let long = CLLocationDegrees(location.longitude)
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                addPinAnnotation(coordinate: coordinate)
                let annotation = MapAnnotation()
                annotation.coordinate = coordinate
                annotation.identifier = "\(location.id)"
                self.locationPins.append(annotation)
            }
            DispatchQueue.main.async {
                self.locationMapView.addAnnotations(self.locationPins)
            }
        }
    }
    
    func addPinAnnotation(coordinate: CLLocationCoordinate2D) {
        let newAnnotation = MKPointAnnotation()
        newAnnotation.coordinate = coordinate
        locationMapView.addAnnotation(newAnnotation)
    }
    
    @objc func registeredLongPress(_ sender: UILongPressGestureRecognizer) {
        // for not generate multiple pins during long press
        if sender.state != UIGestureRecognizer.State.began {
            return
        }

        // getting the coordinates of where user long pressed
        let mapView = sender.view as! MKMapView
        let touchPoint = sender.location(in: mapView)
        
        // convert location to CLLocationCoordinate2D
        let mapCoordinate: CLLocationCoordinate2D = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        // pin object plotting the long pressed location
        let pinLocation = PinAnnotated(coordinate: CLLocationCoordinate2D(latitude: mapCoordinate.latitude, longitude: mapCoordinate.longitude))

        // add pinLocation as an annotation to the map view
        mapView.addAnnotation(pinLocation)
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = appDelegate.persistentContainer.viewContext
        
        let pin = Pin(context: context)
        pin.latitude = pinLocation.coordinate.latitude
        pin.longitude = pinLocation.coordinate.longitude
        try? context.save()
        locationView.addCachedPins()
    }
    
    func handleFailureAlert(title: String, message: String) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertVC, animated: true, completion: nil)
    }
    
    func requestTestEcho() {
        FlickrAPIClient.requestFlickrTestEcho { data, error in
            guard let data = data else {
                // notify the admin of any errors
                print((String(describing: error?.localizedDescription)))
//                handleFailureAlert(title: "Test Echo", message: error?.localizedDescription ?? "Error With Test Echo")
                return
            }
            print("Here are the results of the Flickr test echo service: \(data[0])")
        }
    }
}

// MARK: MKMapViewDelegate

extension LocationMapViewController: MKMapViewDelegate {
    // saves last state of the map region when mapViewDidChangeVisibleRegion()
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        let mapRegion = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        UserDefaults.standard.set(mapRegion, forKey: regionKey)
    }

    // here we create a pin view
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if let pinView = pinView {
            pinView.annotation = annotation
        } else {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.animatesDrop = true
            pinView!.pinTintColor = .green
        }
        
        return pinView
    }
    
    // when a pin is tapped, the app will navigate to the Photo Album view associated with the pin
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let coordinate = view.annotation?.coordinate {
            if let PhotoAlbumVC = self.storyboard?.instantiateViewController(withIdentifier: "showPhotoAlbum") as? PhotoAlbumViewController {
                if let pinSelected = locationView.pinDrops.first(where: {$0.latitude == coordinate.latitude && $0.longitude == coordinate.longitude}) {
                    PhotoAlbumVC.albumView.pinSelected = pinSelected
                    
                    navigationController?.pushViewController(PhotoAlbumVC, animated: true)
                }
            }
        }
    }
}

// MARK: TravelLocationsMapViewModelDelegate

extension LocationMapViewController: TravelLocationViewDelegate {
    func pinsInserted() {
        getAnnotations()
    }
    
    func zoomToVisibleArea(region: MKCoordinateRegion) {
        locationMapView.setRegion(region, animated: true)
    }
}

//
//  MapViewController.swift
//  Pigeon
//
//  Created by Pei Yun Sun on 2017/9/5.
//  Copyright © 2017 El Root. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase

class MapViewController: UIViewController {
    
    var manager: CLLocationManager!
    
    var currentLocation: CLLocation?
    var targetLocation: CLLocation?
    
    var currentUserAnnotation: MKPointAnnotation?
    var targetUserAnnotation: MKPointAnnotation?
    
    var centerMapOnUserLocation: Bool = true
    
    var updateUserLocationTimer: Timer?
    
    var user: User?
    
    var footprints: [Footprint]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigation()
        setupViews()
        setupLocationManager()
        setupMapView()
    }
    
    fileprivate func setupNavigation() {
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .black
        navigationItem.title = "Map"
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(handleCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "AR", style: .plain, target: self, action: #selector(handleAR))
    }
    
    fileprivate func setupViews() {
        view.backgroundColor = .groupTableViewBackground
    }
    
    fileprivate func setupLocationManager() {
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    fileprivate func setupMapView() {
        view.addSubview(mapView)
        
        mapView.addSubview(myLocationButton)
        myLocationButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24).isActive = true
        myLocationButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -24).isActive = true
        myLocationButton.widthAnchor.constraint(equalToConstant: 128).isActive = true
        myLocationButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        updateUserLocationTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(updateUserLocation),
            userInfo: nil,
            repeats: true)
    }
    
    @objc func updateUserLocation() {
        if let currentLocation = currentLocation {
            DispatchQueue.main.async {
                if self.currentUserAnnotation == nil {
                    self.currentUserAnnotation = MKPointAnnotation()
                    self.mapView.addAnnotation(self.currentUserAnnotation!)
                }
                
                UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                    self.currentUserAnnotation?.coordinate = currentLocation.coordinate
                }, completion: nil)
                
                if self.centerMapOnUserLocation {
                    UIView.animate(withDuration: 0.45, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                        self.mapView.setCenter(self.currentUserAnnotation!.coordinate, animated: false)
                    }, completion: {
                        _ in
                        self.mapView.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    })
                }
            }
        }
        
        if let targetLocation = targetLocation {
            DispatchQueue.main.async {
                if self.targetUserAnnotation == nil {
                    self.targetUserAnnotation = MKPointAnnotation()
                    self.mapView.addAnnotation(self.targetUserAnnotation!)
                }
                
                UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                    self.targetUserAnnotation?.coordinate = targetLocation.coordinate
                }, completion: nil)
            }
        }
        
        if let currentUser = Auth.auth().currentUser, let targetUser = user {
            Database.database().reference().child("locations").observeSingleEvent(of: .value, with: { (dataSnapshot) in
                guard let dictionary = dataSnapshot.childSnapshot(forPath: targetUser.uid!).childSnapshot(forPath: currentUser.uid).childSnapshot(forPath: "location").value as? [String: CLLocationDegrees] else { return }
                self.targetLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: dictionary["latitude"]!, longitude: dictionary["longitude"]!), altitude: dictionary["altitude"]!)
            })
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            if touch.view != nil {
                if (mapView == touch.view! ||
                    mapView.recursiveSubviews().contains(touch.view!)) {
                    centerMapOnUserLocation = false
                }
            }
        }
    }
    
    @objc fileprivate func handleAR() {
        let arVC = ARViewController()
        arVC.delegate = self
        arVC.targetLocation = targetLocation
        let vc = UINavigationController(rootViewController: arVC)
        present(vc, animated: false, completion: nil)
    }
    
    @objc fileprivate func handleMyLocation() {
        centerMapOnUserLocation = false
        guard let location = currentLocation else { return }
        let span = MKCoordinateSpanMake(0.01, 0.01)
        let myCoordinate = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
        let region = MKCoordinateRegionMake(myCoordinate, span)
        mapView.setRegion(region, animated: true)
    }
    
    lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.frame = self.view.frame
        mapView.delegate = self
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsUserLocation = true
        mapView.showsScale = true
        mapView.showsCompass = true
        mapView.showsBuildings = true
        return mapView
    }()
    
    let myLocationButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.setTitle("myLocation", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.layer.borderColor = lineColor.cgColor
        button.layer.borderWidth = linePixel
        button.addTarget(self, action: #selector(handleMyLocation), for: .touchUpInside)
        return button
    }()
    
}

extension MapViewController: MKMapViewDelegate, CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first ?? nil
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        if let pointAnnotation = annotation as? MKPointAnnotation {
            let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            
            if pointAnnotation == self.currentUserAnnotation {
                marker.displayPriority = .required
                marker.glyphImage = UIImage(named: "user")
            } else if pointAnnotation == self.targetUserAnnotation {
                marker.displayPriority = .required
                marker.markerTintColor = UIColor(hue: 0.267, saturation: 0.67, brightness: 0.77, alpha: 1.0)
                marker.glyphImage = UIImage(named: "compass")
            } else {
                // footprints maybe...
            }
            
            return marker
        }
        
        return nil
    }
    
}

extension MapViewController: ARViewControllerDelegate {
    
    func updateLocation() -> CLLocation? {
        return targetLocation
    }
    
    @objc func handleCancel() {
        dismiss(animated: true, completion: nil)
    }
    
}

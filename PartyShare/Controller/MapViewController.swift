//
//  MapViewController.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/24/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import GooglePlaces

class MapEvent: NSObject, MKAnnotation {
    var title: String?
    var coordinate: CLLocationCoordinate2D
    var info: String?
    var subtitle: String?
    var eventObj: Event?
    
    init(title: String?, coordinate: CLLocationCoordinate2D, info: String?, subtitle: String?, eventObj: Event?) {
        self.title = title
        self.coordinate = coordinate
        self.info = info
        self.subtitle = subtitle
        self.eventObj = eventObj
    }
}


class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    // IBOutlets
    @IBOutlet weak var mMapView: MKMapView!
    
    var placesClient: GMSPlacesClient!
    var ref: DatabaseReference!
    var events: [Event] = [Event]()
    var places: [MapEvent : Event] = [MapEvent : Event]()
    var currUID = Auth.auth().currentUser?.uid
    
    // Member Vars
    var locationManager:CLLocationManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = Database.database().reference()
        placesClient = GMSPlacesClient.shared()
        
        mMapView.delegate = self
        // Do any additional setup after loading the view.
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        queryEvents()
    }
    
    // sets up map view annotations with a button
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MapEvent else {
            return nil
        }

        let identifier = "Annotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = true
            let button = UIButton(type: .detailDisclosure)
            annotationView?.rightCalloutAccessoryView = button
        } else {
            annotationView!.annotation = annotation
        }

        return annotationView
    }
    
    // updates database
    func registerEvent(event: Event?, closure: @escaping () -> Void) {
        guard
            let e = event,
            let eventID = e.eventID,
            let currUID = currUID else {
            return
        }
        ref.child("events").child(eventID).child("attending").updateChildValues([currUID: 1])
        ref.child("users").child(currUID).child("attending").updateChildValues([eventID: 1])
        
        closure()
    }
    
    // called when a user pressed the info button next to annotation
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let mEvent = view.annotation as? MapEvent else { return }
        

        let ac = UIAlertController(title: mEvent.title, message: "Attend event?", preferredStyle: .alert)
        let addAction = UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction) -> Void in
            self.registerEvent(event: mEvent.eventObj) {
                self.queryEvents()
            }
            ac.dismiss(animated: true, completion: nil)
        })
        ac.addAction(addAction)
            
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            ac.dismiss(animated: true, completion: nil)
        }
            
        ac.addAction(cancelAction)
        present(ac, animated: true)
    }
    
    // updates the map with annotations for each event in view
    func updateMap() {
        let fields: GMSPlaceField = GMSPlaceField(rawValue:UInt(GMSPlaceField.name.rawValue) |
                                                        UInt(GMSPlaceField.placeID.rawValue) |
                                                        UInt(GMSPlaceField.coordinate.rawValue) |
                                                        GMSPlaceField.addressComponents.rawValue |
                                                        GMSPlaceField.formattedAddress.rawValue)!
        
        for event in self.events {
            guard
                let locID = event.locationID,
                let date = event.date else {
                    return
            }
            placesClient?.fetchPlace(fromPlaceID: locID, placeFields: fields, sessionToken: nil, callback: { (place: GMSPlace?, error: Error?) in
              if let error = error {
                print("An error occurred: \(error.localizedDescription)")
                return
              }
              if let place = place {
                // now we have the current place object
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                dateFormatter.locale = Locale(identifier: "en_US")

                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .medium
                timeFormatter.dateFormat = "HH:MM"
                
                let annotation = MapEvent(title: event.eventName, coordinate: place.coordinate, info: place.name, subtitle: dateFormatter.string(from: date) + " " + timeFormatter.string(from: date), eventObj: event)
                self.places[annotation] = event
                self.mMapView.addAnnotation(annotation)
              }
            })
        }
    }
    
    // queries events from DB for map view
    func queryEvents() {
        print("QUERYING EVENTS FOR MAP")
        self.events.removeAll()
        var eventsList: [Event] = []
        
        guard let currUID = self.currUID else {
            return
        }
        
        // gets all events from DB, filtering duplicates and attended events
        ref.child("events").queryOrderedByKey().observe(.value, with: { snapshot in
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                    let event = Event(snapshot: snapshot) {
                    // filter out repeated entries?
                    if event.creatorUID != self.currUID {
                        if event.attending?[currUID] == nil {
                            if let date = event.date {
                                if date >= Date() {
                                    eventsList.append(event)
                                }
                            }
                        }
                    }
                }
            }

            self.events = eventsList
            print("FINISHED QUERYING EVENTS FOR MAP")
            self.updateMap()
        })
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    

}

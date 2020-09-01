//
//  NearbyTableViewController.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/30/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//  chakiche@usc.edu
//

import UIKit
import Firebase
import GooglePlaces
import CoreLocation

class NearbyListCell : UITableViewCell {
    @IBOutlet weak var eventNameLabel: UILabel!
    @IBOutlet weak var eventDateLabel: UILabel!
    @IBOutlet weak var eventLocationLabel: UILabel!
}

class NearbyTableViewController: UITableViewController {
    
    var events: [Event] = [Event]()
    var eventsList: [Event] = [Event]()
    var ref: DatabaseReference!
    let currUID = Auth.auth().currentUser?.uid
    var placesClient: GMSPlacesClient!
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = Database.database().reference()
        placesClient = GMSPlacesClient.shared()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        // auto resizing for cells
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 250

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        queryEvents {
            self.filterEvents()
        }
    }
    
    // filters events from query by distance (within range)
    func filterEvents() {
        locationManager.delegate = self
        locationManager.requestLocation()
    }
    
    // queries all relevant events from DB
    func queryEvents(closure: @escaping () -> Void) {
        print("QUERYING EVENTS")
        
        self.events.removeAll()
        self.eventsList.removeAll()
        
        guard let currUID = self.currUID else {
            return
        }
        
        // gets all events from DB, filtering duplicates and attended events
        self.ref.child("events").queryOrderedByKey().observe(.value, with: { snapshot in
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                    let event = Event(snapshot: snapshot) {
                    if event.creatorUID != self.currUID {
                        if event.attending?[currUID] == nil {
                            if let date = event.date,
                                date > Date() {
                                self.eventsList.append(event)
                            }
                        }

                    }

                }
            }
            print("FINISHED QUERYING EVENTS")
            closure()
        })
        
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return events.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }

    // displays events in each cell
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "nearbyCell", for: indexPath) as! NearbyListCell
        if (events.count < 1) {
            return cell
        }
        let event = events[indexPath.section]
                
        let fields: GMSPlaceField = GMSPlaceField(rawValue: UInt(GMSPlaceField.name.rawValue) |
          UInt(GMSPlaceField.placeID.rawValue))!
        
        guard
            let locID = event.locationID,
            let date = event.date,
            let name = event.eventName else {
            return cell
        }
        
        cell.eventNameLabel.text = name

        placesClient?.fetchPlace(fromPlaceID: locID, placeFields: fields, sessionToken: nil, callback: {
          (place: GMSPlace?, error: Error?) in
          if let error = error {
            print("An error occurred: \(error.localizedDescription)")
            return
          }
          if let place = place {
            cell.eventLocationLabel.text = place.name
          }
        })
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "en_US")

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        timeFormatter.dateFormat = "HH:MM"


        cell.eventDateLabel.text = dateFormatter.string(from: date) + "\n" + timeFormatter.string(from: date)

        return cell
    }
    
    // what to do when a cell is selected
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        if events.count < 1 {
            return
        }
        let event = events[indexPath.section]
        promptRegister(event: event)
    }
    
    // prompts user to register for a new event
    func promptRegister(event: Event?) {
        let alert = UIAlertController(title: event?.eventName, message: "Attend event?", preferredStyle: .alert)

        let addAction = UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction) -> Void in
            self.registerEvent(event: event) {
                self.queryEvents() {
                    self.filterEvents()
                    self.tableView.reloadData()
                }
            }
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(addAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    // updates database when registering for new event
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

}

extension NearbyTableViewController : CLLocationManagerDelegate {
    
    // SET OF FUNCTIONS FOR MANAGING LOCATION --> MAKES CALLS AND LISTENS FOR CALLBACK
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        filterEvents()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // .requestLocation will only pass one location to the locations array
        let fields: GMSPlaceField = GMSPlaceField(rawValue:UInt(GMSPlaceField.name.rawValue) |
                                    UInt(GMSPlaceField.placeID.rawValue) |
                                    UInt(GMSPlaceField.coordinate.rawValue) |
                                    GMSPlaceField.addressComponents.rawValue |
                                    GMSPlaceField.formattedAddress.rawValue)!
        let tempList = eventsList
                if let location = locations.first {
                    for event in tempList {
                        if let locID = event.locationID {
                            placesClient?.fetchPlace(fromPlaceID: locID, placeFields: fields, sessionToken: nil, callback: {
                              (place: GMSPlace?, error: Error?) in
                              if let error = error {
                                print("An error occurred: \(error.localizedDescription)")
                                return
                              }
                              if let place = place {
                                let distance = location.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
                                if (distance > 100000) {
                                    // filter out events that are too far away
                                    self.eventsList = self.eventsList.filter {$0.eventID != event.eventID}
                                }
                              }
                            })
                        }
                    }
                }
        self.events = eventsList
        self.tableView.reloadData()
    }
}

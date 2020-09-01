//
//  EventListTableViewController.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/24/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//  chakiche@usc.edu
//

import UIKit
import FirebaseDatabase
import FirebaseAuth
import GooglePlaces


class EventListTableViewCell : UITableViewCell {
    
    @IBOutlet weak var eventNameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var signupLabel: UILabel!

}

// class for listing all registered events
class EventListTableViewController: UITableViewController {
    var placesClient: GMSPlacesClient!
    var ref: DatabaseReference!
    var events: [[Event]] = [[]]
    var attendingList: [String: Int] = [:]
    var currUID = Auth.auth().currentUser?.uid
    var headerTitles: [String] = ["Hosted by Me", "Attending", "Passed"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // auto resizing for cells
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 250
        
        // places SDK and firebase DB
        ref = Database.database().reference()
        placesClient = GMSPlacesClient.shared()
        
        // get all relevant events
        print("viewDidLoad")
    }
    
    // on view appearing (not just on first load)
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear")
        self.queryEvents() {
            print("finished closure vwA")
            self.tableView.reloadData()
        }
        print("finished viewWillAppear")
    }
    
    // function for querying all events from the firebase DB
    func queryEvents(closure: @escaping () -> Void) {
        print("QUERYING EVENTS")
        
        self.events.removeAll()
        self.events.reserveCapacity(3)
        
        var eventsList: [Event] = [Event]()
        var hostedList: [Event] = [Event]()
        var passedList: [Event] = [Event]()
        eventsList.removeAll()
        hostedList.removeAll()
        passedList.removeAll()
        
        guard let currUID = self.currUID else {
            return
        }
        
        // gets all events from DB, filtering duplicates and attended events
            self.ref.child("events").queryOrderedByKey().observe(.value, with: { snapshot in
                hostedList.removeAll()
                eventsList.removeAll()
                for child in snapshot.children {
                    if let snapshot = child as? DataSnapshot,
                        let event = Event(snapshot: snapshot) {
                        if (!hostedList.contains(event) && !eventsList.contains(event)) {
                            // filter out repeated entries
                            guard let date = event.date else {
                                return
                            }
                            
                            if (date < Date()) {
                                passedList.append(event)
                            }
                            else if event.creatorUID == self.currUID {
                                hostedList.append(event)
                            }
                            else if event.attending?[currUID] != nil {
                                eventsList.append(event)
                            }
                        }
                    }
                }
                
                if self.events.count > 1 {
                    self.events[0] = hostedList
                    self.events[1] = eventsList
                    self.events[2] = passedList
                }
                else {
                    self.events.append(hostedList)
                    self.events.append(eventsList)
                    self.events.append(passedList)
                }
                
                print("FINISHED QUERYING EVENTS")
                closure()
            })
            
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        let c = events.count
        if c < 1 {
            return 1
        }
        return c
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if events.count <= section {
            return 0
        }
        else {
            let count = events[section].count
            return count
        }
    }

    // gets info from google places SDK, and prepares cell for display
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "eventCell", for: indexPath) as! EventListTableViewCell
        if events.count <= 1 {
            return cell
        }
        let event = events[indexPath.section][indexPath.row]
        
                
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
            cell.locationLabel.text = place.name
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


        cell.dateLabel.text = dateFormatter.string(from: date) + "\n" + timeFormatter.string(from: date)
        
        guard let signups = event.signups else {
            return cell
        }
        
        var signedUp = false
        var signupItem = ""
        
        for (key, value) in signups {
            if value["userID"] == currUID {
                signedUp = true
                signupItem = key
            }
        }
        
        if signedUp {
            cell.signupLabel.text = "Bringing \(signupItem)"
        } else {
            cell.signupLabel.text = ""
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section < headerTitles.count {
            return headerTitles[section]
        }

        return nil
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        segue.destination.modalPresentationStyle = .fullScreen
        if segue.identifier == "displayEvent" {
            let eventDetailViewController = segue.destination as! EventDetailTableViewController
            guard
                let currRow = self.tableView.indexPathForSelectedRow?.row,
                let currSection = self.tableView.indexPathForSelectedRow?.section else {
                    return
            }
            let currEvent = events[currSection][currRow]
            
            eventDetailViewController.event = currEvent
            
            let completionHandler = {
                self.queryEvents() {
                    self.tableView.reloadData()
                }
            }

            eventDetailViewController.completionHandler = completionHandler
        }
        
        
    }
}

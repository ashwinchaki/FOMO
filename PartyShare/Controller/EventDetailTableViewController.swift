//
//  EventDetailTableViewController.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/24/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//  chakiche@usc.edu
//

import UIKit
import Firebase
import GooglePlaces

class EventDetailCell: UITableViewCell {
    @IBOutlet weak var eventNameText: UILabel!
    @IBOutlet weak var eventAddressText: UILabel!
    @IBOutlet weak var eventDateText: UILabel!
    @IBOutlet weak var eventDescriptionText: UILabel!
    @IBOutlet weak var eventAttendeesText: UILabel!
}

class ItemSignupCell: UITableViewCell {
    @IBOutlet weak var checkmarkImage: UIImageView!
    @IBOutlet weak var itemText: UILabel!
}

class EventDetailTableViewController: UITableViewController {
    var ref: DatabaseReference!
    var event: Event?
    var host = false
    let currUID = Auth.auth().currentUser?.uid
    var dateString: String?
    var placesClient: GMSPlacesClient!
    var headerTitles = ["Event Details", "Item Signups"]
    var completionHandler: (() -> Void)?
    var eventPassed = false

        
    @IBOutlet weak var topRightButton: UIBarButtonItem!
    
    // for alert
    var quantityValid = false
    var itemValid = false
    
    // removes current event from DB (and deregisters each attendee)
    func deleteEvent() {
        guard let eventID = self.event?.eventID else {
            return
        }
        if let attendees = event?.attending {
            for (key, _) in attendees {
                ref.child("users").child(key).child("attending").child(eventID).setValue(nil)
            }
        }
        
        ref.child("events").child(eventID).setValue(nil)
        
        _ = self.navigationController?.popViewController(animated: true)
        if let cH = self.completionHandler {
            cH()
        }
    }
    
    // removes reference to current user attending event from DB
    func leaveEvent() {
        guard
            let eventID = self.event?.eventID,
            let currUID = self.currUID else {
            return
        }
        ref.child("users").child(currUID).child("attending").child(eventID).setValue(nil)
        ref.child("events").child(eventID).child("attending").child(currUID).setValue(nil)
        
        _ = self.navigationController?.popViewController(animated: true)
        if let cH = self.completionHandler {
            cH()
        }
    }
    
    // displays alert for deleting event (HOST ONLY)
    func displayDeletePopup() {
        let alert = UIAlertController(title: "Cancel Event?", message: "Are you sure you want to delete this event?", preferredStyle: .alert)

        let addAction = UIAlertAction(title: "Remove", style: .destructive, handler: { (action: UIAlertAction) -> Void in
            self.deleteEvent()
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(addAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        updateEvent()
        self.tableView.reloadData()
    }
    
    // displays alert for leaving event (USER ONLY)
    func displayLeavePopup() {
        let alert = UIAlertController(title: "Leave Event?", message: "Are you sure you want to leave this event?", preferredStyle: .alert)

        let addAction = UIAlertAction(title: "Remove", style: .destructive, handler: { (action: UIAlertAction) -> Void in
            self.leaveEvent()
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(addAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        updateEvent()
        self.tableView.reloadData()
    }

    // if user pressed the trashcan button, decide what to do
    @IBAction func trashButtonPressed(_ sender: Any) {
        if host {
            self.displayDeletePopup()
        } else {
            self.displayLeavePopup()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        ref = Database.database().reference()
        placesClient = GMSPlacesClient.shared()
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 300
        
        guard
            let currEvent = event,
            let date = currEvent.date else {
            return
        }
        host = (currEvent.creatorUID == currUID)
        
        eventPassed = (date < Date())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateEvent()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        else {
            if eventPassed {
                return 1
            }
            guard let num = event?.signups?.count else {
                if host {
                    return 1
                }
                return 0
            }
            if host {
                return num + 1
            }
            return num
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section < headerTitles.count {
            return headerTitles[section]
        }

        return nil
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // display different cells depending on what section (either event details or item details)
        switch (indexPath.section) {
        case 0:
            // if header section
            let cell = tableView.dequeueReusableCell(withIdentifier: "EventDetailCell", for: indexPath) as! EventDetailCell
            
            let fields: GMSPlaceField = GMSPlaceField(rawValue: UInt(GMSPlaceField.name.rawValue) |
              UInt(GMSPlaceField.placeID.rawValue))!

            guard
                let currEvent = event,
                let locID = currEvent.locationID,
                let date = currEvent.date,
                let name = currEvent.eventName,
                let desc = currEvent.description else {
                return cell
            }

            cell.eventNameText.text = name

            placesClient?.fetchPlace(fromPlaceID: locID, placeFields: fields, sessionToken: nil, callback: {
              (place: GMSPlace?, error: Error?) in
              if let error = error {
                print("An error occurred: \(error.localizedDescription)")
                return
              }
              if let place = place {
                cell.eventAddressText.text = place.name
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


            cell.eventDateText.text = dateFormatter.string(from: date) + " " + timeFormatter.string(from: date)
            
            cell.eventDescriptionText.text = desc
            
            if let attendees = currEvent.attending {
                if attendees.count == 0 {
                    cell.eventAttendeesText.text = "1 person going"

                }
                else {
                    cell.eventAttendeesText.text = "\(attendees.count + 1) people going!"
                }
            }
            
            return cell
        case 1:
            // if item signup section
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath) as! ItemSignupCell
            if eventPassed {
                cell.checkmarkImage.isHidden = true
                cell.itemText.text = "See Photos"
                return cell
            }
            guard let num = event?.signups?.count else {
                cell.checkmarkImage.image = UIImage(named: "plus")
                cell.checkmarkImage.isHidden = false
                cell.itemText.text = "Add Item"
                cell.itemText.center = cell.center
                return cell
            }
            if indexPath.row == num {
                guard let uID = event?.creatorUID else {
                    return cell
                }
                if (currUID == uID) {
                    // if last item, make this the "add item" cell
                    cell.checkmarkImage.image = UIImage(named: "plus")
                    cell.checkmarkImage.isHidden = false
                    cell.itemText.text = "Add Item"
                    cell.itemText.center = cell.center
                }
            }
            else {
                if let signups = event?.signups {
                    let index = signups.index(signups.startIndex, offsetBy: indexPath.row)
                    let itemKey = signups.keys[index]
                    if let item = signups[itemKey] {
                        cell.itemText.text = "\(item["Quantity"] ?? "1") \(itemKey)"
                        cell.checkmarkImage.isHidden = item["userID"] == "null"
                    }
                    
                }
            }
            
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
            return cell
        }
    }
    
    // query DB for new event info (after adding, to update signups map)
    func updateEvent() {
        print("QUERYING UPDATED EVENT INFO")
        let eventRef = ref.child("events").queryOrderedByKey()
        eventRef.observe(.value, with: { snapshot in
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                    let event = Event(snapshot: snapshot) {
                    if event.eventID == self.event?.eventID {
                        self.event = event
                    }
                }
            }
            self.tableView.reloadData()
            print("FINISHED QUERYING EVENT INFO")
        })
    }
    
    

    // if text in alert box changed, check if valid
    @objc func textChanged(_ sender: Any) {
        let tf = sender as! UITextField
        var resp : UIResponder! = tf
        while !(resp is UIAlertController) { resp = resp.next }
        let alert = resp as! UIAlertController
        
        itemValid = (tf.text != "")
        alert.actions[0].isEnabled = itemValid && quantityValid
    }
    
    // if text in quantity box changed, check if valid
    @objc func quantityChanged(_ sender: Any) {
        let tf = sender as! UITextField
        var resp : UIResponder! = tf
        while !(resp is UIAlertController) { resp = resp.next }
        let alert = resp as! UIAlertController
        
        quantityValid = false
        if let text = tf.text {
            if Int(text) != nil {
                quantityValid = true
            }
        }
        alert.actions[0].isEnabled = itemValid && quantityValid
    }
    
    // prompts event host to add a new item and quantity to bring
    func promptAddItem() {
        let alert = UIAlertController(title: "Add Item", message: "Enter Item and Quantity", preferredStyle: .alert)
        
        itemValid = false
        quantityValid = false
        
        alert.addTextField { tf in
            tf.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
            tf.placeholder = "Item"
        }
        
        alert.addTextField { tf in
            tf.addTarget(self, action: #selector(self.quantityChanged), for: .editingChanged)
            tf.placeholder = "Quantity"
        }

        let addAction = UIAlertAction(title: "Add", style: .default, handler: { (action: UIAlertAction) -> Void in
            guard let quantity = alert.textFields![1].text else {
                return
            }
            
            if let q = Int(quantity) {
                if let i = alert.textFields![0].text {
                    self.addItem(item: i, quantity: q)
                }
            }
        })
        
        alert.addAction(addAction)
        alert.actions[0].isEnabled = false
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        updateEvent()
        self.tableView.reloadData()
    }
    
    // adds new item to list in database
    func addItem(item: String, quantity: Int) {
        guard let event = self.event,
            let eventID = event.eventID else {
            return
        }
        let signupsRef = ref.child("events").child(eventID).child("signups")
        let signup : [AnyHashable : Any] = ["Quantity" : String(quantity), "userID" : "null"]
        signupsRef.child(item).updateChildValues(signup)
    }
    
    // removes item from database
    func removeItem(key: String) {
        if let event = self.event {
            if let eventID = event.eventID {
                let itemRef = ref.child("events").child(eventID).child("signups")
                itemRef.child(key).removeValue()
            }
        }
    }
    
    // prompts host to remove given item
    func promptRemoveItem(key: String) {
        let alert = UIAlertController(title: "Remove Item?", message: "Are you sure you want to remove \(key)?", preferredStyle: .alert)

        let addAction = UIAlertAction(title: "Remove", style: .destructive, handler: { (action: UIAlertAction) -> Void in
            self.removeItem(key: key)
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(addAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        updateEvent()
        self.tableView.reloadData()
    }
    
    // explains what to do when a cell is selected
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)

        let row = indexPath.row
        let section = indexPath.section
        
        if eventPassed {
            if section == 0 {
                return
            }
            if section > 0 {
                // go to photos
                performSegue(withIdentifier: "photosPage", sender: self)
                return
            }
        }
        
        // only item cells can be clicked
        if section > 0 {
            guard let itemCount = event?.signups?.count else {
                // default, add item only cell (index 1, 1)
                promptAddItem()
                return
            }
            
            if (row == itemCount) {
                promptAddItem()
            }
            else {
                // otherwise we'll need to prompt removing item?
                if (host) {
                    if let signups = event?.signups {
                        let index = signups.index(signups.startIndex, offsetBy: indexPath.row)
                        let itemKey = signups.keys[index]
                        self.promptRemoveItem(key: itemKey)
                    }
                }
                else {
                    if let signups = event?.signups {
                        let index = signups.index(signups.startIndex, offsetBy: indexPath.row)
                        let itemKey = signups.keys[index]
                        if let currUID = self.currUID {
                            if signups[itemKey]?["userID"] == "null" {
                                self.promptSignUpForItem(key: itemKey)
                            }
                            else if signups[itemKey]?["userID"] == currUID {
                                self.promptUnSignUpForItem(key: itemKey)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    // registers user as bringing given item
    func registerItem(key: String) {
        if let event = self.event {
            if let currUID = self.currUID {
                if let eventID = event.eventID {
                    let dbRef = ref.child("events").child(eventID).child("signups").child(key)
                    dbRef.updateChildValues(["userID": currUID])
                }
            }
        }
    }

    // prompts user to register to bring given item
    func promptSignUpForItem(key: String) {
        let alert = UIAlertController(title: "Sign Up For Item?", message: "Are you sure you want to sign up for \(key)?", preferredStyle: .alert)

        let addAction = UIAlertAction(title: "Sign Up", style: .default, handler: { (action: UIAlertAction) -> Void in
            self.registerItem(key: key)
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(addAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        updateEvent()
        self.tableView.reloadData()
    }
    
    // unregisters user from bringing given item
    func unregisterItem(key: String) {
        if let event = self.event {
            if let eventID = event.eventID {
                let dbRef = ref.child("events").child(eventID).child("signups").child(key)
                dbRef.updateChildValues(["userID": "null"])
            }
        }
    }
    
    // prompts user to unregister for bringing given item
    func promptUnSignUpForItem(key: String) {
        let alert = UIAlertController(title: "Remove Item?", message: "Are you sure you don't want to bring \(key)?", preferredStyle: .alert)

        let addAction = UIAlertAction(title: "Remove", style: .destructive, handler: { (action: UIAlertAction) -> Void in
            self.unregisterItem(key: key)
            alert.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(addAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action: UIAlertAction) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
        updateEvent()
        self.tableView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        segue.destination.modalPresentationStyle = .fullScreen
        if segue.identifier == "editEvent" {
            let createEventViewController = segue.destination as! CreateEventViewController
            if let event = self.event, let eventName = event.eventName, let desc = event.description, let locID = event.locationID, let date = event.date {
                createEventViewController.userIsEditing = true
//                createEventViewController.doneButton.setTitle("Save Changes", for: .normal)
                createEventViewController.eventName = eventName
                createEventViewController.eventDesc = desc
                createEventViewController.locationID = locID
                createEventViewController.eventDate = date
            }

        } else if segue.identifier == "photosPage" {
            let imageCollectionViewController = segue.destination as! ImageCollectionViewController
            imageCollectionViewController.eventID = event?.eventID
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if !eventPassed && identifier == "editEvent" {
            return true
        }
        else if identifier == "photosPage" {
            return true
        }
        return false
    }
}

//
//  CreateEventViewController.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/24/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//  chakiche@usc.edu
//

import UIKit
import GooglePlaces
import FirebaseDatabase
import FirebaseAuth

class CreateEventViewController: UIViewController{

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var eventNameField: UITextField!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet var doneButton: UIButton!
    @IBOutlet weak var eventDescriptionField: UITextField!
    
    var setLocation: Bool = false
    var locationID: String? = nil
    var ref: DatabaseReference!
    var userIsEditing: Bool = false
    var eventID: String? = nil
    var eventLoc: String? = nil
    var eventName: String? = nil
    var eventDesc: String? = nil
    var eventDate: Date? = nil
    let fields: GMSPlaceField = GMSPlaceField(rawValue: UInt(GMSPlaceField.name.rawValue) |
    UInt(GMSPlaceField.placeID.rawValue))!
    var placesClient: GMSPlacesClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        placesClient = GMSPlacesClient.shared()
        doneButton.isEnabled = false
        eventNameField.delegate = self
        eventDescriptionField.delegate = self
        // Do any additional setup after loading the view.
        
        locationButton.backgroundColor = .clear
        locationButton.layer.cornerRadius = 5
        locationButton.layer.borderWidth = 1
        locationButton.layer.borderColor = UIColor.black.cgColor
        
        doneButton.backgroundColor = .clear
        doneButton.layer.cornerRadius = 5
        doneButton.layer.borderWidth = 1
        doneButton.layer.borderColor = UIColor.black.cgColor
        if (userIsEditing) {
            self.doneButton.setTitle("Save Changes", for: .normal)
            self.eventDescriptionField.text = eventDesc
            self.eventNameField.text = eventName
            self.datePicker.setDate(eventDate ?? Date(), animated: true)
            if let id = locationID {
                placesClient?.fetchPlace(fromPlaceID: id, placeFields: fields, sessionToken: nil, callback: {
                  (place: GMSPlace?, error: Error?) in
                  if let error = error {
                    print("An error occurred: \(error.localizedDescription)")
                    return
                  }
                  if let place = place {
                    self.locationButton.setTitle(place.name, for: .normal)
                    self.setLocation = true
                  }
                })
            }
            doneButton.isEnabled = true
        }
    }
    
    
    // check if fields have been completed
    func enableDoneButton() {
        if let name = eventNameField.text {
            if let desc = eventDescriptionField.text {
                doneButton.isEnabled = (name.count > 0 && desc.count > 0 && setLocation) && (datePicker.date > Date())
            }
        }
    }
    
    func updateEvent() {
        if let eventID = self.eventID {
            var values = [String:Any]()
            values.updateValue(eventNameField.text as Any, forKey: "name")
            values.updateValue(eventDescriptionField.text as Any, forKey: "description")
            values.updateValue(locationID as Any, forKey: "location")
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [
                .withYear,
                .withMonth,
                .withDay,
                .withTime
            ]
            
            values.updateValue(dateFormatter.string(from: self.datePicker.date) as Any, forKey: "date")
            
            ref.child("events").child(eventID).updateChildValues(values)
        }
    }
    
    // background press dismisses keyboard
    @IBAction func backgroundPressed(_ sender: UITapGestureRecognizer) {
        eventNameField.resignFirstResponder()
        eventDescriptionField.resignFirstResponder()
    }
    
    // create a new event in firebase database
    @IBAction func doneButtonPressed(_ sender: Any) {
        if userIsEditing {
            updateEvent()
            _ = self.navigationController?.popViewController(animated: true)
            return
        }
        // create event ID string
        let eventID = NSUUID().uuidString
        let dbEntry = ref.child("events").child(eventID)
        var event = [String:Any]()
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [
            .withYear,
            .withMonth,
            .withDay,
            .withTime
        ]

        let date = datePicker.date
        
        event.updateValue(dateFormatter.string(from: date) as Any, forKey: "date")
        
        guard let currUser = Auth.auth().currentUser else {
            return
        }
        event.updateValue(currUser.uid as Any, forKey: "creatorUID")
        
        event.updateValue(locationID as Any, forKey: "location")
        
        event.updateValue(eventNameField.text as Any, forKey: "name")
        
        event.updateValue(eventDescriptionField.text as Any, forKey: "description")
        
        event.updateValue(eventID as Any, forKey: "eventID")
        
        // now add db entry
        dbEntry.setValue(event)
        
        // also need to update user info
        
        let userEntry = ref.child("users").child(currUser.uid)
        let hosting : [AnyHashable:Any] = [eventID : 1]
        userEntry.child("hosting").updateChildValues(hosting)
        _ = self.navigationController?.popViewController(animated: true)

    }
    
    // opens autocomplete view controller for setting location
    @IBAction func autocompleteClicked(_ sender: Any) {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self

        // Specify the place data types to return.
        autocompleteController.placeFields = fields

        // Specify a filter.
        let filter = GMSAutocompleteFilter()
        autocompleteController.autocompleteFilter = filter

        // Display the autocomplete view controller.
        present(autocompleteController, animated: true, completion: nil)
    }

}

extension CreateEventViewController: GMSAutocompleteViewControllerDelegate, UITextFieldDelegate {

  // Handle the user's selection.
  func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
    locationButton.setTitle(place.name, for: .normal)
    locationID = place.placeID
    setLocation = true
    enableDoneButton()
    dismiss(animated: true, completion: nil)

  }

  func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
    // TODO: handle the error.
    print("Error: ", error.localizedDescription)
  }

  // User canceled the operation.
  func wasCancelled(_ viewController: GMSAutocompleteViewController) {
    dismiss(animated: true, completion: nil)
  }
    
    // enable create button after finished editing
    func textFieldDidEndEditing(_ textField: UITextField) {
        enableDoneButton()
    }
    
    // close keyboard on return button
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        enableDoneButton()
        return true
    }

}

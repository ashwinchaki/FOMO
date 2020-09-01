//
//  Event.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/24/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//

import Foundation
import FirebaseDatabase

class Event : Equatable {
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.eventID == rhs.eventID
    }
    
    
    let ref: DatabaseReference?
    let key: String
    var date: Date?
    let creatorUID: String?
    var eventID: String?
    var locationID: String?
    var eventName: String?
    var attending: [String : Int]?
    var signups: [String: [String : String]]?
    var description: String?
    
    
    init(creatorUID: String) {
        self.ref = nil
        self.key = ""
        self.creatorUID = nil
    }
    
    // initializes event object from firebase snapshot (from database)
    init?(snapshot: DataSnapshot) {
        self.ref = snapshot.ref
        self.key = snapshot.key
        
        // check if data is valid
        guard let data = snapshot.value as? [String: Any] else {
            return nil
        }
        
        // check if fields are valid
        guard
            let date = data["date"] as? String,
            let name = data["name"] as? String,
            let creatorUID = data["creatorUID"] as? String,
            let eventID = data["eventID"] as? String,
            let locationID = data["location"] as? String ,
            let description = data["description"] as? String else {
                return nil
        }
        
        // init object
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [
            .withYear,
            .withMonth,
            .withDay,
            .withTime
        ]
        self.date = dateFormatter.date(from: date)
        
        self.creatorUID = creatorUID
        self.eventID = eventID
        self.locationID = locationID
        self.eventName = name
        self.description = description
        
        // TODO:
        // not required, maybe?
        
        if let attending = data["attending"] as? [String : Int] {
            self.attending = attending
        } else {
            self.attending = [String : Int]()
        }

        if let signups = data["signups"] as? [String : [String : String]] {
            self.signups = signups
        } else {
            self.signups = [String : [String : String]]()
        }

    }
}

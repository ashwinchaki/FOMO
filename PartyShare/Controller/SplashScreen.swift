//
//  SplashScreen.swift
//  PartyShare
//
//  Created by Ashwin Chakicherla on 4/24/20.
//  Copyright © 2020 Ashwin Chakicherla. All rights reserved.
//  chakiche@usc.edu
//

import UIKit
import FirebaseUI
import Firebase


class SplashScreen: UIViewController {

    @IBOutlet weak var button: UIButton!
    var ref: DatabaseReference!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .bold, scale: .large)

        let largeBoldDoc = UIImage(systemName: "arrow.right.circle", withConfiguration: largeConfig)

        button.setImage(largeBoldDoc, for: .normal)
        
        // firebase db initialization
        ref = Database.database().reference()

    }

    // if next button pressed
    @IBAction func nextTapped(_ sender: UIButton) {
        let authUI = FUIAuth.defaultAuthUI()
        guard authUI != nil else {
            // log error
            return
        }
        authUI?.delegate = self
        let providers: [FUIAuthProvider] = [
            FUIEmailAuth()
        ]
        authUI?.providers = providers

        let authViewController = authUI!.authViewController()
        
        present(authViewController, animated: true, completion: nil)
    }
    
}

extension SplashScreen : FUIAuthDelegate {
    // after it's done, segue to main controller
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        if error != nil {
            // log error
            return
        }
        
        let dbRef = ref.child("users")
        guard
            let user = Auth.auth().currentUser,
            let email = user.email,
            let displayName = user.displayName else {
            return
        }
        let values: [AnyHashable : Any] = ["email" : email,
                                           "uid" : user.uid,
                                           "displayname" : displayName]
        dbRef.child(user.uid).updateChildValues(values)
        
        performSegue(withIdentifier: "userLoggedIn", sender: self)
    }
}


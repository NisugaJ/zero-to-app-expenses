//
//  ViewController.swift
//  z2a-expenses
//
//  Copyright © 2019 Firebase. All rights reserved.
//

import UIKit
import Firebase
import FirebaseUI

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, FUIAuthDelegate {
    
    private var imagePickerController = UIImagePickerController()
    
    private var authUI: FUIAuth
    private var auth: Auth
    private var storage: Storage
    private var firestore: Firestore
    
    @IBOutlet weak var yourSpendLabel: UILabel!
    @IBOutlet weak var teamSpendLabel: UILabel!
    @IBOutlet weak var lastItemLabel: UILabel!
    
    // Need to configure Firebase here
    // If you do it in AppDelegate.swift, the app will crash
    // Because the view controller is initialized before AppDelegate loads
    // Apparently this is a semi-known issue with storyboard init
    required init?(coder aDecoder: NSCoder) {
        FirebaseApp.configure()
        self.authUI = FUIAuth.defaultAuthUI()!
        self.auth = Auth.auth()
        self.storage = Storage.storage()
        self.firestore = Firestore.firestore()
        super.init(coder: aDecoder)
        return
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize UINavigationController
        self.title = "Zero to Expenses"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(selectPhoto))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: #selector(toggleLogin))
        
        // Initialize UIImagePickerController
        self.imagePickerController.allowsEditing = false
        self.imagePickerController.sourceType = .photoLibrary // change to .camera when using an actual device
        self.imagePickerController.delegate = self
        
        // Update login button text
        self.auth.addStateDidChangeListener { (auth, user) in
            if (user != nil) {
                self.navigationItem.leftBarButtonItem?.title = "Log out"
                self.attachFirestoreListeners()
            } else {
                self.navigationItem.leftBarButtonItem?.title = "Log in"
            }
        }
    }
    
    // Upload a file
    func onImageSelected(data: Data) {
        // TODO 1: Prepare for upload
        let userId = getUserId()
        let expenseId = generateUniqueId()
        let filename = "receipts/\(userId)/\(expenseId)"
        
        let storageRef = storage.reference().child(filename)

        // TODO 2: Upload file
        self.showMessage(message: "Uploading receipt")
        let uploadTask = storageRef.putData(data)

        // TODO 3: Handle success
        uploadTask.observe(.success) { (snapshot) in
            self.showMessage(message: "Uploaded succeeded!")
        }

        // TODO 4: Handle failure
        uploadTask.observe(.failure) { (snapshot) in
            self.showMessage(message: "Uploaded failed due to \(snapshot.error.debugDescription)!")
        }
    }
    
    func onSignInCompleted() {
        // TODO 5: Configure FirebaseUI
        self.authUI = FUIAuth.defaultAuthUI()!
        self.authUI.providers = [
            FUIEmailAuth(),
            FUIGoogleAuth()
        ]
        self.authUI.delegate = self
        let authViewController = self.authUI.authViewController()
        self.present(authViewController, animated: true, completion: nil)
    }
    
    // TODO 6: Login delegate methods
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        if (error != nil) {
            self.showMessage(message: "Login failed due to \(error.debugDescription)!")
        } else {
            self.showMessage(message: "Logged in \(authDataResult?.user.displayName! ?? "")!")
        }
    }

    // Listen for expenses in Firestore
    func attachFirestoreListeners() {
        self.firestore.collection("users").document(getUserId()).collection("expenses")
            .order(by: "created_at", descending: true)
            .limit(to: 1)
            .addSnapshotListener { (querySnapshot, error) in
                // TODO 8: Update the UI
                guard let _ = querySnapshot?.documents else {
                    print("Error fetching documents: \(error!)")
                    return
                }

                self.lastItemLabel?.text = self.formatAmount(amount: querySnapshot?.documents.first?["item_cost"])
        }

        self.firestore.collection("users").document(getUserId())
            .addSnapshotListener { (documentSnapshot, error) in
                // TODO 10: Update the UI
                guard let _ = documentSnapshot else {
                    print("Error fetching document: \(error!)")
                    return
                }

                self.yourSpendLabel?.text = self.formatAmount(amount: documentSnapshot?.get("user_cost"))
                self.teamSpendLabel?.text = self.formatAmount(amount: documentSnapshot?.get("team_cost"))
        }
    }
    
    @objc func toggleLogin() {
        if (self.auth.currentUser != nil) {
            do {
                try self.auth.signOut()
            } catch {
                self.showMessage(message: "Failed to sign user out!")
            }
        } else {
            self.onSignInCompleted()
        }
    }
    
    @objc func selectPhoto() {
        self.present(self.imagePickerController, animated: true, completion: nil)
    }
    
    // UIImagePickerControllerDelegate methods
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { return }
        let imageData = image.jpegData(compressionQuality: 1.0)
        self.onImageSelected(data: imageData!)
        self.dismiss(animated: true, completion: nil)
    }
    
    // Show an alert
    func showMessage(message: String) {
        let alertViewController = UIAlertController(title: "Expense Status",
                                                    message: message,
                                                    preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "Ok",
                                          style: .default,
                                          handler: { (action) in
                                            self.dismiss(animated: true, completion: nil)
        })
        alertViewController.addAction(dismissAction)
        self.present(alertViewController, animated: true, completion: nil)
    }
    
    func getUserId() -> String {
        return self.auth.currentUser?.uid ?? "definitelyNotAnActualUser"
    }
    
    func generateUniqueId() -> String {
        return NSUUID().uuidString
    }
    
    func formatAmount(amount: Any?) -> String {
        return String(format: "%.2f", amount as? Double ?? 0.00)
    }
}


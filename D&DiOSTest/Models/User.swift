//
//  User.swift
//  D&DiOSTest
//
//  Created by Samuel Folledo on 3/10/19.
//  Copyright © 2019 Samuel Folledo. All rights reserved.
//

import Foundation
import Firebase
import FirebaseAuth


class User: NSObject {
	var name: String
	var email: String
	var avatarURL: String
	var userID: String
	
	init(_userID: String, _name: String, _email: String, _avatarURL: String = "") {
		userID = _userID
		name = _name
		email = _email
		avatarURL = _avatarURL
	}
	
	init(_dictionary: [String: Any]) {
		self.name = _dictionary[kNAME] as! String
		self.email = _dictionary[kEMAIL] as! String
		self.avatarURL = _dictionary[kAVATARURL] as! String
		self.userID = _dictionary[kUSERID] as! String
	}
	
	class func currentId() -> String {
		return Auth.auth().currentUser!.uid
	}
	
	class func currentUser() -> User? {
		if Auth.auth().currentUser != nil { //if we have user...
			if let dictionary = UserDefaults.standard.object(forKey: kCURRENTUSER) {
				return User.init(_dictionary: dictionary as! [String: Any])
			}
		}
		return nil //if we dont have user in our UserDefaults, then return nil
	}
	
	
	class func registerUserWith(email: String, password: String, completion: @escaping (_ error: Error?) -> Void) {
		Auth.auth().createUser(withEmail: email, password: password) { (firUser, error) in
			if let error = error {
				completion(error)
				return
			}
			
			completion(error)
		}
	}
	
	class func loginUserWith(email: String, password: String, withBlock: @escaping (_ error: Error?) -> Void) {
		Auth.auth().signIn(withEmail: email, password: password) { (firUser, error) in
			if let error = error {
				withBlock(error)
				return
			}
			//RE ep.110 3mins
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: { //it is important to have some DELAY
				let uid: String = firUser!.user.uid
				fetchUserWith(userId: uid, completion: { (user) in
					guard let user = user else { print("no user"); return }
					saveUserLocally(user: user) //since fetchUserWith already calls saveUserInBackground
					withBlock(error)
				})
			})
		}
	}
	
	
//MARK: Logout
	class func logOutCurrentUser(withBlock: (_ success: Bool) -> Void) {
		print("Logging outttt...")
		UserDefaults.standard.removeObject(forKey: kCURRENTUSER)
		UserDefaults.standard.synchronize() //save the changes
		
		do {
			try Auth.auth().signOut()
			withBlock(true)
		} catch let error as NSError {
			print("error logging out \(error.localizedDescription)")
			withBlock(false)
		}
	}
	
	
	class func deleteUser(completion: @escaping(_ error: Error?) -> Void) { //delete the current user
		let user = Auth.auth().currentUser
		user?.delete(completion: { (error) in
			completion(error)
		})
	}
	
}

//+++++++++++++++++++++++++   MARK: Saving user   ++++++++++++++++++++++++++++++++++
func saveUserInBackground(user: User) {
	let ref = firDatabase.child(kUSER).child(user.userID)
	ref.setValue(userDictionaryFrom(user: user))
	print("Finished saving user \(user.name) in Firebase")
}

//save locally
func saveUserLocally(user: User) {
	UserDefaults.standard.set(userDictionaryFrom(user: user), forKey: kCURRENTUSER)
	UserDefaults.standard.synchronize()
	print("Finished saving user \(user.name) locally...")
}





//MARK: Helper fuctions

func fetchUserWith(userId: String, completion: @escaping (_ user: User?) -> Void) {
	let ref = firDatabase.child(kUSER).queryOrdered(byChild: kUSERID).queryEqual(toValue: userId)
	
	ref.observeSingleEvent(of: .value, with: { (snapshot) in
		if snapshot.exists() {
			let userDictionary = ((snapshot.value as! NSDictionary).allValues as NSArray).firstObject! as! [String: Any]
			let user = User(_dictionary: userDictionary)
			completion(user)
		} else { completion(nil) }
	}, withCancel: nil)
}


func userDictionaryFrom(user: User) -> NSDictionary { //take a user and return an NSDictionary
	
	return NSDictionary(
		objects: [user.userID, user.name, user.email, user.avatarURL],
		forKeys: [kUSERID as NSCopying, kNAME as NSCopying, kEMAIL as NSCopying, kAVATARURL as NSCopying]) //this func create and return an NSDictionary
}


func updateCurrentUser(withValues: [String : Any], withBlock: @escaping(_ success: Bool) -> Void) {
	
	if UserDefaults.standard.object(forKey: kCURRENTUSER) != nil {
		guard let currentUser = User.currentUser() else { return }
		let userObject = userDictionaryFrom(user: currentUser).mutableCopy() as! NSMutableDictionary
		userObject.setValuesForKeys(withValues)
		
		let ref = firDatabase.child(kUSER).child(currentUser.userID)
		ref.updateChildValues(withValues) { (error, ref) in
			if error != nil {
				withBlock(false)
				return
			}
			
			UserDefaults.standard.set(userObject, forKey: kCURRENTUSER)
			UserDefaults.standard.synchronize()
			withBlock(true)
		}
	}
	
}

func isUserLoggedIn() -> Bool {
	if User.currentUser() != nil {
		return true
	} else {
		return false
	}
}

//func isUserLoggedIn(viewController: UIViewController) -> Bool {
//
//	if User.currentUser() != nil {
//		return true
//	} else {
//		let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: kLOGINCONTROLLER) as! LoginViewController
//		viewController.present(vc, animated: true, completion: nil)
//		return false
//	}
//}

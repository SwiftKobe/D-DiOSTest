//
//  ChatViewController.swift
//  D&DiOSTest
//
//  Created by Samuel Folledo on 3/8/19.
//  Copyright © 2019 Samuel Folledo. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAuth

class ChatViewController: UIViewController {
	
	/**
	* =========================================================================================
	* INSTRUCTIONS
	* =========================================================================================
	* 1) Make the UI look like it does in the mock-up.
	*
	* 2) Using the following endpoint, fetch chat data
	*    URL: http://dev.datechnologies.co/Tests/scripts/chat_log.php
	*
	* 3) Parse the chat data using 'Message' model
	*
	**/

	
// MARK: - Outlets
	@IBOutlet weak var chatTable: UITableView!
	@IBOutlet weak var chatTextField: UITextField!
	@IBOutlet weak var sendButton: UIButton!
	@IBOutlet weak var chatTextFieldView_BottomConstraint: NSLayoutConstraint!
	
	
// MARK: - Properties
	private var client: ChatClient?
	private var messages: [Message]?
	var user: User? {
		didSet {
			navigationItem.title = "\(user!.name)'s Chat"
		}
	}
	
	
	
// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		
		messages = [Message]()
		handleKeyboardObservers()
		
		configureTable(tableView: chatTable)
		title = "Chat"
		
		fetchMessages()
		viewFirebaseMessages()
	// TODO: Remove test data when we have actual data from the server loaded
//		messages?.append(Message(testName: "James", withTestMessage: "Hey Guys!"))
//		messages?.append(Message(testName:"Paul", withTestMessage:"What's up?"))
//		messages?.append(Message(testName:"Amy", withTestMessage:"Hey! :)"))
//		messages?.append(Message(testName:"James", withTestMessage:"Want to grab some food later?"))
//		messages?.append(Message(testName:"Paul", withTestMessage:"Sure, time and place?"))
//		messages?.append(Message(testName:"Amy", withTestMessage:"YAS! I am starving!!!"))
//		messages?.append(Message(testName:"James", withTestMessage:"1 hr at the Local Burger sound good?"))
//		messages?.append(Message(testName:"Paul", withTestMessage:"Sure thing"))
//		messages?.append(Message(testName:"Amy", withTestMessage:"See you there :P"))
		
	
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if isUserLoggedIn() { //if there is user
			self.user = User.currentUser() //set the user so we can also observe messages
		}
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.removeObserver(self)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
	}
	
	
//MARK: Helpers
	@objc func handleSend() {
		guard let text = chatTextField.text else { return }
		let properties: [String: AnyObject] = ["text": text] as [String : AnyObject]
		sendMessageWithProperties(properties: properties)
	}
	
	private func sendMessageWithProperties(properties: [String: AnyObject]) {
		let ref = Database.database().reference().child(kMESSAGE)
		let childRef = ref.childByAutoId()
		guard let user = User.currentUser() else { return }
		var values: [String: AnyObject] = [kUSERID: user.userID, kNAME: user.name, kAVATARURL: user.avatarURL] as [String: AnyObject]
		
		properties.forEach {values[$0] = $1} //basically, forEach key: value pairs from properties, append each one of them to our values dictionary
		childRef.updateChildValues(values) { (error, ref) in //updateChildValues with completion handler to not broadcast everyone's messages
			if let error = error {
				Service.presentAlert(on: self, title: "Error", message: "\(error.localizedDescription)")
				return
			}
			
			self.chatTextField.text = ""
		}
	}
	
	func viewFirebaseMessages() {
		let allMessagesRef = Database.database().reference().child(kMESSAGE)
		allMessagesRef.observe(.childAdded, with: { (snapshot) in
			let messageIDs = snapshot.key
			
			allMessagesRef.child(messageIDs).observeSingleEvent(of: .value, with: { (snapshot2) in
//				print("SNAPSHOT VALUES AREEE \(snapshot2.value)") //snapshot.value has all each of the messages that can be converected as dictionary
				guard let dictionary = snapshot2.value as? [String: AnyObject] else { print("snapshot2 error"); return } //grab each message of messages as a dictionary
				let message = Message(_dictionary: dictionary)
				self.messages?.append(message)
				DispatchQueue.main.async {
					self.chatTable.reloadData()
					let indexPath = IndexPath(item: (self.messages?.count)! - 1, section: 0)
					self.chatTable.scrollToRow(at: indexPath, at: .bottom, animated: true) //scroll down to the latest message
				}
			}, withCancel: nil)
			
		}, withCancel: nil)
	}
	
	
	private func fetchMessages() {
		ChatClient.fetchChatData({ (messages) in
			guard let messages = messages else { return }
			for message in messages {
				self.messages?.append(message)
			}
			
			DispatchQueue.main.async {
				self.chatTable.reloadData()
			}
		}, withError: { (error) in
			guard let error = error else { return }
			Service.presentAlert(on: self, title: "Parse Error", message: error)
		})
	}
	
	private func configureTable(tableView: UITableView) {
		tableView.delegate = self
		tableView.dataSource = self
		tableView.keyboardDismissMode = .interactive
		tableView.register(UINib(nibName: "ChatTableViewCell", bundle: nil), forCellReuseIdentifier: "chatCell")
		tableView.tableFooterView = UIView(frame: .zero)
	}

	
// MARK: - IBAction
	@IBAction func sendButtonTapped(_ sender: Any) {
		handleSend()
	}
}


//MARK: UITableView Delegate and DataSource
extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
//UITableViewDelegate
	func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
		return 300
	}
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return UITableView.automaticDimension
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
//UITableViewDataSource
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "chatCell", for: indexPath) as! ChatTableViewCell
		cell.setCellData(message: messages![indexPath.row])
		return cell
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return messages!.count
	}
	
}


//MARK: Keyboard handlers
extension ChatViewController {
//show/hide keyboard and handling the views
	func handleKeyboardObservers(){
		NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: UIResponder.keyboardDidShowNotification , object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleViewsOnKeyboardShowOrHide(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleViewsOnKeyboardShowOrHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleViewsOnKeyboardShowOrHide(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
		
	}
	
	@objc func handleKeyboardDidShow() {
		let indexPath = IndexPath(item: messages!.count - 1, section: 0)
		chatTable.scrollToRow(at: indexPath, at: .bottom, animated: true)
	}
	
	@objc func handleViewsOnKeyboardShowOrHide(notification: Notification) {
//		print("Keyboard will show: \(notification.name.rawValue)")
		guard let keyboardRect = (notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
		
		let keyboardDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
		
		if (notification.name == UIResponder.keyboardWillShowNotification) || (notification.name == UIResponder.keyboardWillChangeFrameNotification) {
			chatTextFieldView_BottomConstraint.constant = -keyboardRect.height
			UIView.animate(withDuration: keyboardDuration) {
				self.view.layoutIfNeeded()
			}
			
		} else if notification.name == UIResponder.keyboardWillHideNotification {
			chatTextFieldView_BottomConstraint.constant = 0
			UIView.animate(withDuration: keyboardDuration) {
				self.view.layoutIfNeeded()
			}
		}
	}
}


extension ChatViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		switch textField {
		case chatTextField:
			handleSend()
		default:
			textField.resignFirstResponder()
		}
		return true
	}
}


/*
import UIKit

class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

/**
* =========================================================================================
* INSTRUCTIONS
* =========================================================================================
* 1) Make the UI look like it does in the mock-up.
*
* 2) Using the following endpoint, fetch chat data
*    URL: http://dev.datechnologies.co/Tests/scripts/chat_log.php
*
* 3) Parse the chat data using 'Message' model
*
**/

// MARK: - Properties
private var client: ChatClient?
private var messages: [Message]?

// MARK: - Outlets
@IBOutlet weak var chatTable: UITableView!

// MARK: - Lifecycle
override func viewDidLoad() {
super.viewDidLoad()

messages = [Message]()
configureTable(tableView: chatTable)
title = "Chat"

// TODO: Remove test data when we have actual data from the server loaded
messages?.append(Message(testName: "James", withTestMessage: "Hey Guys!"))
messages?.append(Message(testName:"Paul", withTestMessage:"What's up?"))
messages?.append(Message(testName:"Amy", withTestMessage:"Hey! :)"))
messages?.append(Message(testName:"James", withTestMessage:"Want to grab some food later?"))
messages?.append(Message(testName:"Paul", withTestMessage:"Sure, time and place?"))
messages?.append(Message(testName:"Amy", withTestMessage:"YAS! I am starving!!!"))
messages?.append(Message(testName:"James", withTestMessage:"1 hr at the Local Burger sound good?"))
messages?.append(Message(testName:"Paul", withTestMessage:"Sure thing"))
messages?.append(Message(testName:"Amy", withTestMessage:"See you there :P"))

chatTable.reloadData()
}

// MARK: - Private
private func configureTable(tableView: UITableView) {
tableView.delegate = self
tableView.dataSource = self
tableView.register(UINib(nibName: "ChatTableViewCell", bundle: nil), forCellReuseIdentifier: "ChatTableViewCell")
tableView.tableFooterView = UIView(frame: .zero)
}

// MARK: - UITableViewDataSource
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
var cell: ChatTableViewCell? = nil
if cell == nil {
let nibs = Bundle.main.loadNibNamed("ChatTableViewCell", owner: self, options: nil)
cell = nibs?[0] as? ChatTableViewCell
}
cell?.setCellData(message: messages![indexPath.row])
return cell!
}

func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
return messages!.count
}

// MARK: - UITableViewDelegate
func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
return 58.0
}

// MARK: - IBAction
@IBAction func backAction(_ sender: Any) {
let mainMenuViewController = MenuViewController()
self.navigationController?.pushViewController(mainMenuViewController, animated: true)
}
}
*/

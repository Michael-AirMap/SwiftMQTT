//
//  ViewController.swift
//  SwiftMQTTExample
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import UIKit
import SwiftMQTT

class MQTTViewController: UIViewController, MQTTSessionDelegate {

    var mqttSession: MQTTSession!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var channelTextField: UITextField!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.text = nil
        establishConnection()
        
        NotificationCenter.default.addObserver(self, selector: #selector(MQTTViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MQTTViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(MQTTViewController.hideKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func hideKeyboard() {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo! as NSDictionary
        let kbHeight = (userInfo.object(forKey: UIKeyboardFrameBeginUserInfoKey) as! NSValue).cgRectValue.size.height
        bottomConstraint.constant = kbHeight
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        bottomConstraint.constant = 0
    }
    
    func establishConnection() {
        let host = "localhost"
        let port: UInt16 = 1883
        let clientID = self.clientID()
        
        mqttSession = MQTTSession(host: host, port: port, clientID: clientID, cleanSession: true, keepAlive: 15, useSSL: false)
        mqttSession.delegate = self
        appendStringToTextView("Trying to connect to \(host) on port \(port) for clientID \(clientID)")

        mqttSession.connect { (error) in
            DispatchQueue.main.async { [weak self] in
                switch error {
                case .none:
                    self?.appendStringToTextView("Connected.")
                    self?.subscribeToChannel()
                default:
                    self?.appendStringToTextView("Error occurred during connection \(error.localizedDescription as Any)")
                }
            }
        }
    }
    
    func subscribeToChannel() {
        let subChannel = "/#"
        mqttSession.subscribe(to: subChannel, delivering: .atMostOnce) { (error) in
            DispatchQueue.main.async { [weak self] in
                switch error {
                case .none:
                    self?.appendStringToTextView("Subscribed to \(subChannel)")
                default:
                    self?.appendStringToTextView("Error occurred during subscription: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func appendStringToTextView(_ string: String) {
        textView.text = "\(textView.text ?? "")\n\(string)"
        let range = NSMakeRange(textView.text.count - 1, 1)
        textView.scrollRangeToVisible(range)
    }
    
    // MARK: - MQTTSessionDelegates

    func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
        DispatchQueue.main.async { [weak self] in
            self?.appendStringToTextView("data received on topic \(message.topic) message \(message.stringRepresentation ?? "<>")")
        }
    }

    func mqttDidDisconnect(session: MQTTSession, reason: MQTTSessionDisconnectReason, error: MQTTSessionError?) {
        DispatchQueue.main.async { [weak self] in
            self?.appendStringToTextView("Session Disconnected.")
        }
    }

    func mqttDidAcknowledgePing(from session: MQTTSession) {
        DispatchQueue.main.async { [weak self] in
            self?.appendStringToTextView("Ping acknowledged.")
        }
    }
    
    // MARK: - IBActions
    
    @IBAction func resetButtonPressed(_ sender: AnyObject) {
        textView.text = nil
        channelTextField.text = nil
        messageTextField.text = nil
        establishConnection()
    }
    
    @IBAction func sendButtonPressed(_ sender: AnyObject) {

        guard let channel = channelTextField.text, let message = messageTextField.text,
            !channel.isEmpty && !message.isEmpty
            else { return }

        let data = message.data(using: .utf8)!
        mqttSession.publish(data, in: channel, delivering: .atMostOnce, retain: false) { (error) in
            DispatchQueue.main.async { [weak self] in
                switch error {
                case .none:
                    self?.appendStringToTextView("Published \(message) on channel \(channel)")
                default:
                    self?.appendStringToTextView("Error Occurred During Publish \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Utilities

    func clientID() -> String {

        let userDefaults = UserDefaults.standard
        let clientIDPersistenceKey = "clientID"
        let clientID: String

        if let savedClientID = userDefaults.object(forKey: clientIDPersistenceKey) as? String {
            clientID = savedClientID
        } else {
            clientID = randomStringWithLength(5)
            userDefaults.set(clientID, forKey: clientIDPersistenceKey)
            userDefaults.synchronize()
        }
        
        return clientID
    }
    
    // http://stackoverflow.com/questions/26845307/generate-random-alphanumeric-string-in-swift
    func randomStringWithLength(_ len: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        var randomString = String()
        for _ in 0..<len {
            let length = UInt32(letters.count)
            let rand = arc4random_uniform(length)
            let index = String.Index(encodedOffset: Int(rand))
            randomString += String(letters[index])
        }
        return String(randomString)
    }
}

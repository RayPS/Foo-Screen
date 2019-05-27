//
//  ViewController.swift
//  Foo Screen
//
//  Created by Ray on 5/25/19.
//  Copyright © 2019 Ray. All rights reserved.
//

import UIKit
import WebKit
import Foundation

class ViewController: UIViewController, UITableViewDelegate,  UITableViewDataSource {


    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var addressBar: UIView!
    @IBOutlet weak var addressBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var addressUrlField: UITextField!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    @IBOutlet weak var historyTableView: UITableView!

    let defaults = UserDefaults.standard
    let indexUrl = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "index")!
    var isStatusBarHidden = true

    override var prefersStatusBarHidden: Bool { return isStatusBarHidden }
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()

        grantInternetAccess()
        addGestureRecognizers()
        observeKeyboardEvents()
        loadDefaultIndex()

        addressBar.layer.cornerRadius = 8.0
        addressBar.layer.masksToBounds = true
        controlsView.alpha = 0.0

        historyTableView.delegate = self
        historyTableView.dataSource = self
    }

    func addGestureRecognizers() {
        let threeFingerSwipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeUp))
        let threeFingerSwipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeDown))
        threeFingerSwipeUpGesture.direction = .up
        threeFingerSwipeUpGesture.numberOfTouchesRequired = 3
        threeFingerSwipeDownGesture.direction = .down
        threeFingerSwipeDownGesture.numberOfTouchesRequired = 3
        threeFingerSwipeUpGesture.delegate = webView as? UIGestureRecognizerDelegate
        threeFingerSwipeDownGesture.delegate = webView as? UIGestureRecognizerDelegate
        webView.addGestureRecognizer(threeFingerSwipeUpGesture)
        webView.addGestureRecognizer(threeFingerSwipeDownGesture)
    }

    @objc func handleThreeFingerSwipeDown(_ sender: UISwipeGestureRecognizer) {
        webView.reload()
        generateHapticFeedback()
    }

    @objc func handleThreeFingerSwipeUp(_ sender: UISwipeGestureRecognizer) {
        if let webviewUrl = webView.url, webviewUrl != indexUrl {
            addressUrlField.text = webviewUrl.absoluteString
        }
        isStatusBarHidden = false
        UIView.animate(withDuration: 0.25) {
            self.controlsView.alpha = 1.0
            self.setNeedsStatusBarAppearanceUpdate()
        }
        UIView.animate(withDuration: 0.5) {
            self.addressUrlField.becomeFirstResponder()
            self.view.layoutIfNeeded()
        }
        historyTableView.reloadData()
    }

    @IBAction func dismissControlsView(_ sender: Any) {
        isStatusBarHidden = true
        UIView.animate(withDuration: 0.25) {
            self.controlsView.alpha = 0.0
            self.addressUrlField.resignFirstResponder()
            self.view.layoutIfNeeded()
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    @IBAction func go(_ sender: UITextField) {
        if !validateUrl(addressUrlField.text!) {
            addressUrlField.text = "http://" + addressUrlField.text!
        }
        if let url = URL(string: addressUrlField.text!) {
            webView.load(URLRequest(url: url))
            dismissControlsView(self)
            historyInsertItem(url.absoluteString)
        }
    }

    @objc func handleConstrainForKeyboard(notification: NSNotification) {
        let userInfo = notification.userInfo!
        let keyboardScreenEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

        if notification.name == UIResponder.keyboardWillHideNotification {
            addressBarHeightConstraint.constant = 46.0
        } else {
            addressBarHeightConstraint.constant = 46.0 + keyboardViewEndFrame.height
        }
    }

    func observeKeyboardEvents() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(handleConstrainForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(handleConstrainForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    func loadDefaultIndex() {
        webView.loadFileURL(indexUrl, allowingReadAccessTo: indexUrl)
    }

    func generateHapticFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.prepare()
        notificationFeedbackGenerator.notificationOccurred(type)
    }

    func grantInternetAccess() {
        URLSession.shared.dataTask(
            with: URL(string: "http://captive.apple.com/generate_204")!
        ).resume()
    }

    func validateUrl(_ string: String) -> Bool {
        let urlRegEx = "^(https?://).*"
        let urlTest = NSPredicate(format:"SELF MATCHES %@", urlRegEx)
        let result = urlTest.evaluate(with: string)
        return result
    }

    func historyInsertItem(_ url: String) {
        var history: Array = defaults.array(forKey: "history") as? [String] ?? [String]()
        history = history.filter { $0 != url }
        history.insert(url, at: 0)
        defaults.set(history, forKey: "history")
    }

    @objc func clearHistory() {
        defaults.removeObject(forKey: "history")
        historyTableView.reloadData()
    }

    func pasteboardUrlString() -> String {
        if validateUrl(UIPasteboard.general.string ?? "") {
            return UIPasteboard.general.string!
        } else {
            return ""
        }
    }





    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let history = defaults.array(forKey: "history")
        let historyLength = history != nil ? min(5, history!.count) : 1
        return section == 0 ? 1 : historyLength
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "Clipboard" }
        else { return "Recent History" }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Item", for: indexPath)
        cell.textLabel?.textColor = UIColor(hue: 0, saturation: 0, brightness: 1.0, alpha: 0.8)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13.0)
        let selectionBackgroundView = UIView()
        selectionBackgroundView.backgroundColor = UIColor(hue: 0, saturation: 0, brightness: 1.0, alpha: 0.1)
        cell.selectedBackgroundView = selectionBackgroundView


        if indexPath.section == 0 {
            cell.textLabel?.text = pasteboardUrlString() != "" ? pasteboardUrlString() : "None"
            cell.selectionStyle = .none
        }

        if indexPath.section == 1 {
            let history = defaults.array(forKey: "history")
            if history != nil {
                cell.textLabel?.text = (history as! [String])[indexPath.row]
            } else {
                cell.textLabel?.text = "None"
                cell.selectionStyle = .none
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.setSelected(false, animated: true)
        if cell?.textLabel?.text != "None" {
            addressUrlField.text = cell?.textLabel?.text
            go(addressUrlField)
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 1 && defaults.array(forKey: "history") != nil {
            let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 48))
            let button = UIButton(frame: CGRect(x: 0, y: 0, width: footerView.frame.size.width, height: footerView.frame.size.height))
            button.setTitle("Clear History", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            button.setTitleColor(UIColor(hue: 0, saturation: 0, brightness: 1.0, alpha: 0.3), for: .normal)
            button.addTarget(self, action: #selector(clearHistory), for: .touchUpInside)
            
            footerView.addSubview(button)
            return footerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int){
        view.tintColor = UIColor.clear
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.white
        header.textLabel?.alpha = 0.3
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 36.0
    }

}




class FullScreenWKWebView: WKWebView, UIGestureRecognizerDelegate {

    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }
}

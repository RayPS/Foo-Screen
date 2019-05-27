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

class ViewController: UIViewController {


    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var addressBar: UIView!
    @IBOutlet weak var addressBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var addressUrlField: UITextField!
    @IBOutlet weak var controlsView: UIVisualEffectView!
    @IBOutlet weak var historyTableView: UITableView!
    @IBOutlet weak var progressBar: UIProgressView!

    let defaults = UserDefaults.standard
    let indexUrl = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "index")!
    var isStatusBarHidden = true
    var webViewProgressObserver: NSKeyValueObservation?

    override var prefersStatusBarHidden: Bool { return isStatusBarHidden }
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()

        grantInternetAccess()
        addGestureRecognizers()
        observeKeyboardEvents()
        observeWebViewProgress()
        loadDefaultIndex()

        addressBar.layer.cornerRadius = 8.0
        addressBar.layer.masksToBounds = true
        controlsView.alpha = 0.0

        webView.navigationDelegate = self
        historyTableView.delegate = self
        historyTableView.dataSource = self
    }

    func addGestureRecognizers() {
        #if targetEnvironment(simulator)
            let numberOfTouchesRequired = 2
        #else
            let numberOfTouchesRequired = 3
        #endif
        let threeFingerSwipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeUp))
        let threeFingerSwipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeDown))
        threeFingerSwipeUpGesture.direction = .up
        threeFingerSwipeUpGesture.numberOfTouchesRequired = numberOfTouchesRequired
        threeFingerSwipeDownGesture.direction = .down
        threeFingerSwipeDownGesture.numberOfTouchesRequired = numberOfTouchesRequired
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

    func observeWebViewProgress() {
        webViewProgressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            self?.progressBar.setProgress(progress, animated: true)
            if progress > 0.9 {
                self?.dismissControlsView(self?.addressBar as Any)
            }
        }
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
        let alert = UIAlertController(title: "Confirm", message: "Clear history?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .default))
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
            self.defaults.removeObject(forKey: "history")
            self.historyTableView.reloadData()
        }))
        UIApplication.shared.windows.last?.rootViewController?.present(alert, animated: true)
    }

    func pasteboardUrlString() -> String {
        if validateUrl(UIPasteboard.general.string ?? "") {
            return UIPasteboard.general.string!
        } else {
            return ""
        }
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


extension ViewController: UITableViewDelegate, UITableViewDataSource {

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
        cell.textLabel?.textColor = UIColor(white: 1, alpha: 0.8)
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13.0)
        let selectionBackgroundView = UIView()
        selectionBackgroundView.backgroundColor = UIColor(white: 1, alpha: 0.1)
        cell.selectedBackgroundView = selectionBackgroundView


        if indexPath.section == 0 {
            cell.textLabel?.text = pasteboardUrlString() != "" ? pasteboardUrlString() : "None"
            cell.selectionStyle = .none
        }

        if indexPath.section == 1 {
            let history = defaults.array(forKey: "history")
            if history != nil {
                cell.textLabel?.text = (history as! [String])[indexPath.row]
                cell.selectionStyle = .default
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
            let button = UIButton(frame: footerView.frame)
            button.setTitle("Clear History", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
            button.setTitleColor(UIColor(white: 1, alpha: 0.3), for: .normal)
            button.setTitleColor(UIColor(white: 1, alpha: 0.7), for: .highlighted)
            button.autoresizingMask = .flexibleWidth
            button.addTarget(self, action: #selector(clearHistory), for: .touchUpInside)

            footerView.addSubview(button)
            return footerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 1 && defaults.array(forKey: "history") != nil {
            return 48.0
        } else {
            return 0.0
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



extension ViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressBar.alpha = 1.0
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressBar.alpha = 0.0
        progressBar.setProgress(0.0, animated: false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let alert = UIAlertController(title: "Fail", message: "Fail to load \"\(webView.url!)\"", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
            webView.stopLoading()
            self.progressBar.setProgress(0.0, animated: false)
        }))
        UIApplication.shared.windows.last?.rootViewController?.present(alert, animated: true)
    }
}

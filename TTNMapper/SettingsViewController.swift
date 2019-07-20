//
//  SettingsViewController.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 15/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit
import Crashlytics

extension CALayer {
    var borderColorFromUIColor: UIColor {
        set {
            self.borderColor = newValue.cgColor
        }
        
        get {
            return UIColor(cgColor: self.borderColor!)
        }
    }
}

class SettingsViewController: UIViewController, UITextFieldDelegate, MQTTServiceDelegate {
    
    @IBOutlet weak var uploadSwitch: UISwitch!
    
    @IBOutlet weak var experimentalSwitch: UISwitch!
    @IBOutlet weak var experimentalLabel: UILabel!
    @IBOutlet weak var experimentalHelpTextView: UITextView!
    @IBOutlet weak var experimentalDataView: UIView!
    @IBOutlet weak var experimentalDataViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var iCloudStorageSwitch: UISwitch!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stagingConfigurationView: UIView!
    
    @IBOutlet weak var experimentalDataSetTextView: UITextField!
    @IBOutlet weak var devEUITextView: UITextField!
    @IBOutlet weak var appEUITextView: UITextField!
    @IBOutlet weak var accessKeyTextView: UITextField!
    @IBOutlet weak var handlerRegionTextView: UITextField!
    @IBOutlet weak var versionNumberLabel: UILabel!
    @IBOutlet weak var testConfigurationButton: UIButton!
    @IBOutlet weak var testingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var editRegionButton: UIButton!
    @IBOutlet weak var scanQrButton: UIButton!
    
    @IBOutlet weak var stagingConfigurationViewHeight: NSLayoutConstraint!
    
    weak var delegate: LiveMapViewController!
    
    var experimentalTextViewBorderRed = CALayer()
    var devEUITextViewBorderRed = CALayer()
    var appEUITextViewBorderRed = CALayer()
    var accessKeyTextViewBorderRed = CALayer()
    var handlerRegionTextViewBorderRed = CALayer()
    
    var handlerRegionPort = 1883
    var deepLinkConf : TTNMapperConfiguration?
    var conf: TTNMapperConfiguration?
    var deeplinked = false
    var qrScanned = false
    
    var mqttService : MQTTService?
    var manualDisconnect = false
    var defaultTestButtonColor : CGColor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set custom back button
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(title: "Back to map", style: UIBarButtonItem.Style.plain, target: self, action: #selector(SettingsViewController.back(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton
        
        // Set callback to hide keyboard on enter.
        devEUITextView.delegate = self
        appEUITextView.delegate = self
        accessKeyTextView.delegate = self
        experimentalDataSetTextView.delegate = self
        handlerRegionTextView.delegate = self
        
        // Scroll to show content in text view.
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.keyboardWillShow(_:)), name:UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.keyboardWillHide(_:)), name:UIResponder.keyboardWillHideNotification, object: nil)
        
        // Load conf from user prefs.
        conf = TTNMapperConfigurationStorage.sharedInstance.load()
        
        // Populate fields.
        if let deepLinkConf = deepLinkConf {
            // Take experimental properties from configuration.
            deepLinkConf.isExperimental = conf!.isExperimental
            deepLinkConf.experimentName = conf!.experimentName
            deepLinkConf.storeLocal = conf!.storeLocal
            
            // Populate from deep link
            populateFieds(configuration: deepLinkConf)
            populateHandlerRegionFromAppId(appId: deepLinkConf.appEUI)
            
        } else {
            // Populate from user prefs.
            populateFieds(configuration: conf)
        }
    
        // Reset deep link config.
        deepLinkConf = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Animation for displaying / hiding of the experimental details.
        displayExperimentalDataView(experimentalSwitch)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Methods that should show and hide the keyboard.
    
    @IBAction func btnEditHandlerClick(_ sender: UIButton) {
        handlerRegionTextView.isEnabled = !handlerRegionTextView.isEnabled
        if handlerRegionTextView.isEnabled {
            handlerRegionTextView.becomeFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    @objc func keyboardWillShow(_ notification:Notification) {
        
        var userInfo = notification.userInfo!
        var keyboardFrame:CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        keyboardFrame = self.view.convert(keyboardFrame, from: nil)
        
        var contentInset:UIEdgeInsets = self.scrollView.contentInset
        contentInset.bottom = keyboardFrame.size.height + 10
        self.scrollView.contentInset = contentInset
    }
    
    @objc func keyboardWillHide(_ notification:Notification) {
        self.scrollView.contentInset = UIEdgeInsets.zero
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField === appEUITextView && !handlerRegionTextView.isEnabled {
            let nsString = textField.text as NSString?
            let newString = nsString?.replacingCharacters(in: range, with: string)
            populateHandlerRegionFromAppId(appId: newString!)
        }
        return true
    }
    
    private func populateHandlerRegionFromAppId(appId: String){
        let handler = TTNDiscoveryService.sharedInstance.getHandler(appId: appId)
        if let ttnhandler = handler {
            let handlerUrlComponents = ttnhandler.mqttAddress.components(separatedBy: ":")
            if handlerUrlComponents.count == 2 {
                self.handlerRegionTextView.text = handlerUrlComponents[0]
                if let ttnbrokerport = Int(handlerUrlComponents[1]){
                    self.handlerRegionPort = ttnbrokerport
                }
            }
        } else {
            self.handlerRegionTextView.text = ""
        }
    }
    
    @objc func back(sender: UIBarButtonItem) {
        // Check if config has changed.
        if hasConfigurationChanged() {
            
            // Validate configuration before alerting the user that things have changed.
            // Populate region first just to be sure.
            populateHandlerRegionFromAppId(appId: appEUITextView.text!)
            if !validateInput() {
                // Notify that user has
                let message = "\nSome configuration parameters are invalid. Please check all input fields."
                let alert = UIAlertController(title: "Invalid configuration", message: message, preferredStyle: .alert)
                let continueAction = UIAlertAction(title: "Ok", style: .default)
                alert.addAction(continueAction)
                self.present(alert, animated: true, completion: nil)
            } else {
                let alertController = UIAlertController(title: "Changed configuration", message: "You have updated some settings without saving. Do you want to save your changes?\nNote: Saving these changes will restart your mapping session and clear the map.", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "No", style: .default) { (result : UIAlertAction) -> Void in
                    
                    // Do nothing
                }
                let continueAction = UIAlertAction(title: "Yes", style: .default) { (result : UIAlertAction) -> Void in
                    
                    // Persist changes
                    self.persistConfiguration()
                    
                    // Set the field of the live map vc
                    self.delegate.restartRequired = true
                    
                    // Analytics
                    var method = "manual"
                    if self.qrScanned {
                        method = "qr code"
                    }
                    if self.deeplinked {
                        method = "universal link"
                    }
                    Answers.logCustomEvent(withName: "Configuration updated", customAttributes: ["method": method, "experimental": self.conf!.isExperimental.description, "store local": self.conf!.storeLocal.description])
                    
                    // Go back to live map
                    let navigationController = self.parent as! UINavigationController
                    navigationController.popToRootViewController(animated: true)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(continueAction)
                self.present(alertController, animated: true, completion: nil)
            }
        } else {
            // Go back to the live map (unchanged).
            _ = navigationController?.popViewController(animated: true)
        }
        
    }
    
    func populateFieds(configuration: TTNMapperConfiguration?) {
        devEUITextView.text = configuration!.deviceEUI
        appEUITextView.text = configuration!.appEUI
        accessKeyTextView.text = configuration!.password
        handlerRegionTextView.text = configuration!.ttnbrokerRegion
        
        uploadSwitch.isOn = configuration!.doUpload
        iCloudStorageSwitch.isOn = configuration!.storeLocal
        experimentalSwitch.isOn = configuration!.isExperimental
        experimentalDataSetTextView.text = ""
        experimentalDataSetTextView.text = configuration!.experimentName
        if experimentalDataSetTextView.text == "" {
            // Set default name for experiment
            let calendar = Calendar.current
            let components = (calendar as NSCalendar).components([.day , .month , .year, .hour, .minute, .second], from: Date())
            
            experimentalDataSetTextView.text = String(format:"experiment %d-%02d-%02d %02d:%02d:%02d", components.year!, components.month!, components.day!, components.hour!, components.minute!, components.second!)
        }
        
        self.versionNumberLabel.text = versionBuild()
    }
    
    func versionBuild() -> String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let appBuild = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        
        return appVersion == appBuild ? "v\(appVersion)" : "v\(appVersion) (\(appBuild))"
    }
    
    func createRedBorderLayer(_ textField: UITextField) -> CALayer {
        let border = CALayer()
        border.borderColor = UIColor.red.cgColor
        border.frame = CGRect(x: 0, y: 0, width:  textField.frame.size.width, height: textField.frame.size.height)
        border.cornerRadius = 5
        border.borderWidth = CGFloat(1.0)
        return border
    }
    
    @IBAction func uploadSwitchChanged(_ sender: Any) {
        if let uploadSwitch = sender as? UISwitch {
            if !uploadSwitch.isOn {
                experimentalSwitch.isOn = false
                displayExperimentalDataView(experimentalSwitch)
                experimentalSwitch.isEnabled = false
                experimentalLabel.isEnabled = false
                experimentalHelpTextView.alpha = 0.4
            } else {
                experimentalSwitch.isEnabled = true
                experimentalLabel.isEnabled = true
                experimentalHelpTextView.alpha = 1.0
            }
        }
    }
    
    @IBAction func experimentalSwitchChanged(_ sender: AnyObject) {
        hideKeyboard()
        
        if let experimentalSwitch = sender as? UISwitch {
            displayExperimentalDataView(experimentalSwitch)
        }
    }
    
    func displayExperimentalDataView(_ experimentalSwitch: UISwitch){
        if experimentalSwitch.isOn {
            experimentalDataViewHeight.constant = 80
        } else {
            experimentalDataViewHeight.constant = 0
        }
    }
    
    @IBAction func iCloudStorageSwitchChanged(_ sender: AnyObject) {
        hideKeyboard()
    }

    func hideKeyboard() {
        if experimentalDataSetTextView.isFirstResponder {
            experimentalDataSetTextView.endEditing(true)
        }
        if devEUITextView.isFirstResponder{
            devEUITextView.endEditing(true)
        }
        if appEUITextView.isFirstResponder {
            appEUITextView.endEditing(true)
        }
        if accessKeyTextView.isFirstResponder {
            accessKeyTextView.endEditing(true)
        }
        if handlerRegionTextView.isFirstResponder {
            handlerRegionTextView.endEditing(true)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let qrScannerVC = segue.destination as? QRScannerViewController
        if let qrScannerVC = qrScannerVC {
            qrScannerVC.delegate = self
        }
    }
    
    @IBAction func validateButtonTapped(_ sender: UIButton) {
        if validateInput() {
            // Show activity indicator.
            testingActivityIndicator.startAnimating()
            testConfigurationButton.setTitle("Testing...     ", for: .normal)
            defaultTestButtonColor = testConfigurationButton.layer.borderColor
            testConfigurationButton.layer.borderColor = UIColor.red.cgColor
            testConfigurationButton.setTitleColor(UIColor.red, for: .normal)
            self.view.isUserInteractionEnabled = false

            // Disable buttons
            saveButton.isEnabled = false
            saveButton.layer.borderColor = UIColor.gray.cgColor
            cancelButton.isEnabled = false
            cancelButton.layer.borderColor = UIColor.gray.cgColor
            scanQrButton.isEnabled = false
            scanQrButton.layer.borderColor = UIColor.gray.cgColor
            editRegionButton.isEnabled = false
            
            let testConfig = TTNMapperConfiguration()
            
            // Set broker to production.
            testConfig.ttnbroker = Constants.TTNBROKER_PROD
            
            // Experimental.
            testConfig.isExperimental = experimentalSwitch.isOn
            if experimentalSwitch.isOn {
                testConfig.experimentName = experimentalDataSetTextView.text!
            }
            
            // Local storage
            testConfig.storeLocal = iCloudStorageSwitch.isOn
            
            // Broker config
            testConfig.ttnbrokerport = handlerRegionPort
            testConfig.ttnbrokerRegion = handlerRegionTextView.text!
            testConfig.deviceEUI = devEUITextView.text!
            testConfig.appEUI = appEUITextView.text!
            testConfig.username = appEUITextView.text!
            testConfig.password = accessKeyTextView.text!
            
            self.mqttService = MQTTService(configuration: testConfig)
            self.mqttService!.delegate = self
            self.mqttService!.mqttConnect(nil)
        }
    }
    
    // MARK: - MQTTService callback methods
    
    func connected(_ mapperSession: TTNMapperSession) {
        // Disconnect immediately
        self.manualDisconnect = true
        self.mqttService!.mqttDisconnect()
        
        // Display alert.
        let message = "Succesfully connected to TTN!"
        let alertController = UIAlertController(title: "Configuration Valid", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func disconnected(_ reason: DisconnectReason) {
        // Hide activity indicator.
        testingActivityIndicator.stopAnimating()
        testConfigurationButton.setTitle("Test config", for: .normal)
        testConfigurationButton.layer.borderColor = defaultTestButtonColor
        testConfigurationButton.setTitleColor(self.view.tintColor, for: .normal)
        self.view.isUserInteractionEnabled = true
        // Enable buttons
        saveButton.isEnabled = true
        saveButton.layer.borderColor = defaultTestButtonColor
        cancelButton.isEnabled = true
        cancelButton.layer.borderColor = defaultTestButtonColor
        scanQrButton.isEnabled = true
        scanQrButton.layer.borderColor = defaultTestButtonColor
        editRegionButton.isEnabled = true
        
        if self.manualDisconnect {
            self.manualDisconnect = false
        } else {
            // Display alert.
            var message = "Error connecting to TTN!\nReason: \(reason.rawValue)"
            if reason == .connectionRefused {
                message = "Error connecting to TTN!\nReason: \(reason.rawValue)\n(Check your access key)"
            }
            let alertController = UIAlertController(title: "Configuration Error", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: .default,handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func reconnecting(_ sessionReconnect: Int) {
        // Ignore. Should never happen when testing the connection.
        NSLog("This should never happen")
    }
    
    
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        let navigationController = self.parent as! UINavigationController
        navigationController.popToRootViewController(animated: true)
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        if validateInput() {
            
            // Check whether the configuration has been changed.
            let hasChanged = hasConfigurationChanged()
            
            // Check if we have changed to configuratio while mapping.
            if hasChanged && self.delegate.mappingSwitch.isOn {
                // Ask user if session needs to be continued.
                let alertController = UIAlertController(title: "Current session", message: "You have updated some settings while mapping. Saving these changes will restart your mapping session. Do you want to restart your mapping session?\nNote: Restaring your session will clear the map.", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "No", style: .default) { (result : UIAlertAction) -> Void in
                    
                    // Do nothing
                }
                let continueAction = UIAlertAction(title: "Yes", style: .default) { (result : UIAlertAction) -> Void in
                    
                    // Persist changes
                    self.persistConfiguration()
                    
                    // Set the field of the live map vc
                    self.delegate.restartRequired = true
                    
                    // Analytics
                    var method = "manual"
                    if self.qrScanned {
                        method = "qr code"
                    }
                    if self.deeplinked {
                        method = "universal link"
                    }
                    Answers.logCustomEvent(withName: "Configuration updated", customAttributes: ["method": method, "experimental": self.conf!.isExperimental.description, "store local": self.conf!.storeLocal.description])
                    
                    // Go back to live map
                    let navigationController = self.parent as! UINavigationController
                    navigationController.popToRootViewController(animated: true)
                }
                alertController.addAction(cancelAction)
                alertController.addAction(continueAction)
                self.present(alertController, animated: true, completion: nil)
                return
            } else {
                
                // Persist changes
                self.persistConfiguration()
                
                // Analytics
                var method = "manual"
                if qrScanned {
                    method = "qr code"
                }
                if self.deeplinked {
                    method = "universal link"
                }

                Answers.logCustomEvent(withName: "Configuration updated", customAttributes: ["method": method, "experimental": conf!.isExperimental.description, "store local": conf!.storeLocal.description])
                
                // Go back to live map
                let navigationController = self.parent as! UINavigationController
                navigationController.popToRootViewController(animated: true)

            }
        }
    }
    
    func hasConfigurationChanged() -> Bool {
        // Check if we switched experimental modes.
        if  conf!.isExperimental == experimentalSwitch.isOn {
            // Compare all fields (except the experiment name).
            let isEqual =
                conf!.storeLocal == iCloudStorageSwitch.isOn &&
                conf!.ttnbrokerRegion == handlerRegionTextView.text! &&
                conf!.deviceEUI == devEUITextView.text! &&
                conf!.appEUI == appEUITextView.text! &&
                conf!.username == appEUITextView.text! &&
                conf!.password == accessKeyTextView.text!
            
            // Only check experiment names if the configuration is experimental.
            if conf!.isExperimental {
                return !(conf!.experimentName == experimentalDataSetTextView.text! && isEqual)
            } else {
                return !isEqual
            }
        }
        return true
    }
    
    fileprivate func persistConfiguration () {        
        // Clear configuration object.
        clearConfiguration()
        
        // Set broker to production.
        conf!.ttnbroker = Constants.TTNBROKER_PROD

        // Upload
        conf!.doUpload = uploadSwitch.isOn
        
        // Experimental.
        conf!.isExperimental = experimentalSwitch.isOn
        if experimentalSwitch.isOn {
            conf!.experimentName = experimentalDataSetTextView.text!
        }

        // Local storage
        conf!.storeLocal = iCloudStorageSwitch.isOn
        
        // Broker config
        conf!.ttnbrokerport = handlerRegionPort
        conf!.ttnbrokerRegion = handlerRegionTextView.text!
        conf!.deviceEUI = devEUITextView.text!
        conf!.appEUI = appEUITextView.text!
        conf!.username = appEUITextView.text!
        conf!.password = accessKeyTextView.text!
        
        // Persist changes
        conf!.changedOn = CFAbsoluteTimeGetCurrent()
        TTNMapperConfigurationStorage.sharedInstance.store(conf!);
    }
    
    func clearConfiguration() {
        if conf != nil {
            conf!.ttnbrokerRegion = ""
            conf!.appEUI = ""
            conf!.deviceEUI = ""
            conf!.password = ""
            conf!.ttnbroker = ""
            conf!.username = ""
            conf!.experimentName = ""
        }
    }
    
    // MARK: - Configuration storage and validation
    
    func validateInput() -> Bool {
        var isValid = true
        experimentalTextViewBorderRed.removeFromSuperlayer()
        devEUITextViewBorderRed.removeFromSuperlayer()
        appEUITextViewBorderRed.removeFromSuperlayer()
        accessKeyTextViewBorderRed.removeFromSuperlayer()
        handlerRegionTextViewBorderRed.removeFromSuperlayer()
        
        if experimentalSwitch.isOn && experimentalDataSetTextView.text == "" {
            // Invalid experimental data set name (empty)
            experimentalTextViewBorderRed = createRedBorderLayer(experimentalDataSetTextView)
            experimentalDataSetTextView.layer.addSublayer(experimentalTextViewBorderRed)
            experimentalDataSetTextView.layer.masksToBounds = true
            isValid = false
        }
        
        // Production
        if handlerRegionTextView.text == "" {
            handlerRegionTextViewBorderRed = createRedBorderLayer(handlerRegionTextView)
            handlerRegionTextView.layer.addSublayer(handlerRegionTextViewBorderRed)
            handlerRegionTextView.layer.masksToBounds = true
            isValid = false
        }
        if devEUITextView.text == "" {
            devEUITextViewBorderRed = createRedBorderLayer(devEUITextView)
            devEUITextView.layer.addSublayer(devEUITextViewBorderRed)
            devEUITextView.layer.masksToBounds = true
            isValid = false
        }
        // For staging we also need an appEUI, username and password
        if appEUITextView.text == "" {
            appEUITextViewBorderRed = createRedBorderLayer(appEUITextView)
            appEUITextView.layer.addSublayer(appEUITextViewBorderRed)
            appEUITextView.layer.masksToBounds = true
            isValid = false
        }
        if accessKeyTextView.text == "" || accessKeyTextView.text?.count != 58 {
            accessKeyTextViewBorderRed = createRedBorderLayer(accessKeyTextView)
            accessKeyTextView.layer.addSublayer(accessKeyTextViewBorderRed)
            accessKeyTextView.layer.masksToBounds = true
            isValid = false
        }
        
        return isValid
    }
}

    //
//  LiveMapViewController.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 12/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Crashlytics

class LiveMapViewController: BaseMapViewController, CLLocationManagerDelegate, UIGestureRecognizerDelegate, MQTTServiceDelegate, TTNMapperSessionDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var autoscaleButton: UISwitch!
    @IBOutlet weak var autoscaleLabel: UITextField!
    @IBOutlet weak var mappingSwitch: UISwitch!
    @IBOutlet weak var mappingLabel: UITextField!
    
    @IBOutlet weak var diagnosticsDatapointsLabel: UITextField!
    @IBOutlet weak var diagnosticsGatewaysLabel: UITextField!
    @IBOutlet weak var connectionInfoLabel: UITextField!
    
    var mapPanGesture : UIPanGestureRecognizer?
    var defaultOnTintColor : UIColor?
    
    let locationManager = CLLocationManager()
    var location: CLLocation?
    
    fileprivate var conf : TTNMapperConfiguration?
    fileprivate var mqttService : MQTTService?
    
    var restartRequired = false
    var startMappingOnForeground = false
    var universalLinkError = false
    
    var localStorageSession: TTNMapperLocalStorageSession?
    var uploader: TTNMapperUploader?
    
    // MARK: - View Controller overrides
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check if config has been updated recently.
        // If so reconnect to MQTT broker.
        NSLog("Restart required: " + self.restartRequired.description)
        self.conf = TTNMapperConfigurationStorage.sharedInstance.load()
        
        if self.universalLinkError {
            self.universalLinkError = false

            // Notify that user has
            let message = "\nApp was lauchned using an invalid universal link.\n\n(This alert will close in 3 seconds.)"
            let alert = UIAlertController(title: "Invalid universal link", message: message, preferredStyle: .alert)
            self.present(alert, animated: true, completion: nil)

            // change to desired number of seconds (in this case 5 seconds)
            let when = DispatchTime.now() + 3
            DispatchQueue.main.asyncAfter(deadline: when){
                // your code with delay
                alert.dismiss(animated: true, completion: nil)
            }
        }
        
        if self.restartRequired {
            self.restartRequired = false
            if mappingSwitch.isOn {
                // Analytics
                Answers.logCustomEvent(withName: "MQTT Service", customAttributes: ["status": "Reconnecting", "disconnect reason": "Reconnect on configuration update"])
                
                // Reconnect
                NSLog("Reconnect")
                stopMapping()
                startMapping()
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Catch app going to background.
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Let's get the default tint color for our mapping switch.
        defaultOnTintColor = mappingSwitch.onTintColor
        
        // Init configuration.
        self.conf = TTNMapperConfigurationStorage.sharedInstance.load()
        
        if let conf = conf {
            if conf.doUpload {
                // Set up the uploader.
                uploader = TTNMapperUploader(configuration: conf)
            }
        }
        
        // Let's initialize map and start mapping.
        if !CLLocationManager.locationServicesEnabled() {
            // Display error message.
            alert("Enable location services", message: "Please enable location services for your phone. This can be done in your iPhone Settings > Privacy > Location Services.")
        } else {
            // Initialize the map.
            initializeMap()
            
            // Let's start mapping.
            startMapping()
        }
    }
    
    @objc func didEnterBackground(_ notification: NSNotification) {
        // code to execute
        NSLog("Going to background")
        startMappingOnForeground = mappingSwitch.isOn
        stopMapping()
    }
    
    @objc func willEnterForeground(_ notification: NSNotification) {
        // code to execute
        NSLog("Entering foreground")
        if startMappingOnForeground {
            startMappingOnForeground = false
            startMapping(true)
        }
    }
    
    // Util function to display an alert message.
    func alert(_ title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        // If we are transitioning to the session viewer we should check whether we 
        // have an ongoing mapping session. If so the user should cancel it first.
        if let identifier = identifier {
            if identifier == "sessionSegue" {
                if mappingSwitch.isOn {
                    alert("Active mapping session", message: "You currently have an active mapping session. Please stop mapping before opening a stored session in the viewer.")
                    return false
                }
            }
        }
        return true
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Add the vc as a delegate when transitioning to settings screen.
        if let settingsVC = segue.destination as? SettingsViewController {
            settingsVC.delegate = self
        }
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Location methods
    
    func initializeMap() {
        
        // Initialize location manager for geotagging.
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        
        // In mapper mode set delegate on map and show current location.
        self.mapView.showsUserLocation = true
        self.mapView.delegate = self
        
        // Set gesture delegate for autoscale disabling.
        mapPanGesture = UIPanGestureRecognizer(target: self, action: #selector(LiveMapViewController.disableAutoScale(_:)))
        mapPanGesture!.delegate = self
        self.mapView.addGestureRecognizer(mapPanGesture!)
    }
    
    // Disables the map from autoscaling.
    @objc func disableAutoScale(_ sender:UITapGestureRecognizer) {
        
        autoscaleButton.isOn = false
        self.mapView.removeGestureRecognizer(mapPanGesture!)
    }
    
    // Allow to recognize multiple gestures simultaneously (UIGestureRecognizerDelegate method)
    // This is needed for disabling autoscale.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // Updates the map when the users location has been update and autoscale is on.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Update the current location.
        self.location = locations.last! as CLLocation
        
        // Update mapper session's current location.
        if let ttnmapperSession = ttnmapperSession {
            ttnmapperSession.currentLocation = location
        }
        
        // Auto scale around current location.
        if autoscaleButton.isOn {
            setRegion(center: location!)
        }
    }
    
    @IBAction func mappingSwitchPressed(_ sender: UISwitch) {
        // Sender is the current (updated) state of the switch.
        // Stop mapping.
        if !sender.isOn {
            // Analytics
            Answers.logCustomEvent(withName: "MQTT Service", customAttributes: ["status": "Disconnected", "disconnect reason": "User disconnected"])
            
            stopMapping()
        }
        
        // Start mapping.
        if sender.isOn {
            // Switch connected state (green background) is set by the connect callback.
            // Between connection set up and connected we set the background to orange.
            sender.onTintColor = UIColor.orange
            
            // Check if we have a previous mapper session.
            if let ttnmapperSession = self.ttnmapperSession {
                if ttnmapperSession.status == .stopped && ttnmapperSession.datapoints.count > 0 {
                    // Ask user if session needs to be continued.
                    let alertController = UIAlertController(title: "Previous session", message: "Do you want to start a new mapping session or continue your previous session?\nNote: a new session will clear the map.", preferredStyle: .alert)
                    let continueAction = UIAlertAction(title: "Continue", style: .default) { (result : UIAlertAction) -> Void in
                        // Continue mapping session.
                        self.startMapping(true)
                    }
                    let newAction = UIAlertAction(title: "New", style: .destructive) { (result : UIAlertAction) -> Void in
                        // Start a new mapping session.
                        self.startMapping()
                    }
                    alertController.addAction(continueAction)
                    alertController.addAction(newAction)
                    self.present(alertController, animated: true, completion: nil)
                    return
                }
            }
            // Start a new mapping session.
            startMapping()
        }
    }
    
    @IBAction func autoScalePressed(_ sender: UISwitch) {
        if sender.isOn {
            if let currentLocation = location {
                setRegion(center: currentLocation)
            }
            self.mapView.addGestureRecognizer(mapPanGesture!)
        }
    }
    
    @IBAction func coverageSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            Answers.logCustomEvent(withName: "Tile service", customAttributes: ["status":"Off"])
            self.mapView.addOverlay(tileOverlay!)
        } else {
            Answers.logCustomEvent(withName: "Tile service", customAttributes: ["status":"On"])
            self.mapView.removeOverlay(tileOverlay!)
        }
    }
    
    // MARK: - Mapping methods
    
    func startMapping(_ continueSession: Bool = false) {
        // Set up local storage if configured.
        conf = TTNMapperConfigurationStorage.sharedInstance.load()
        
        // Perform sanity checks.
        let status = CLLocationManager.authorizationStatus()
        if status != .authorizedWhenInUse && status != .notDetermined {
                // Alert user about authorization status.
            alert("Authorize location services", message: "Please authorize location services for the app. This can be done in your iPhone settings > Privacy > Location Services. Select TTN Mapper and set access to 'While Using the App'.")
        } else if conf!.ttnbroker == Constants.TTNBROKER_NONE {
            // Alert user to configure app.
            alert("Configure TTN Mapper", message: "You need to configure the app before you can start mapping. Please tap on 'Configure' in the right corner of the screen.")
        } else if !conf!.isValid() {
            // Alert user that the configuration is invalid.
            alert("Invalid configuration", message: "Your configuration seems to be invalid. Please update your configuration.")
        } else {
            // Everything checks out so let's start mapping.
            // Remove delegates because they will be added later.
            if let ttnmapperSession = ttnmapperSession {
                ttnmapperSession.delegates.removeAllDelegates()
            }
            
            // Check if we need to reset map.
            if !continueSession {
                // Remove all annotations and user location from map.
                let overlays = self.mapView.overlays
                self.mapView.removeOverlays(overlays)
                let allAnnotations = self.mapView.annotations
                self.mapView.removeAnnotations(allAnnotations)
                
                // Reset diagnostic labels.
                self.diagnosticsDatapointsLabel.text = "Num datapoints: 0"
                self.diagnosticsGatewaysLabel.text = "Num gateways: 0"
                
                // Reset local storage and mapper session
                self.localStorageSession = nil
                self.ttnmapperSession = nil
            }
            
            // Start location tracking.
            locationManager.startUpdatingLocation()
            
            // Connect to the mqtt service.
            if self.mqttService == nil {
                self.mqttService = MQTTService(configuration: conf!)
            } else {
                self.mqttService!.updateConfiguration(conf!)
            }
            self.mqttService!.delegate = self
            self.mqttService!.mqttConnect(ttnmapperSession)
        }
    }
    
    func stopMapping(shouldDisconnect: Bool = true) {
        if shouldDisconnect {
            // Disconnect to mqtt service.
            if let mqttService = mqttService {
                mqttService.mqttDisconnect()
            }
        }
        
        // Stop tracking the phone's location.
        locationManager.stopUpdatingLocation()
        
        // Visual feedback.
        mappingSwitch.isOn = false
        mappingSwitch.tintColor = defaultOnTintColor
        connectionInfoLabel.text = "Disconnected"
    }
    
    func setRegion(center: CLLocation) {
        let region = Util.centerMapRegion(center, annotations: mapView.annotations, capMaxRegion: true)
        self.mapView.setRegion(region, animated: true)
    }
    
    // MARK: - MQTTService callback methods
    
    func connected(_ mapperSession: TTNMapperSession) {
        mappingSwitch.onTintColor = defaultOnTintColor
        
        // Connected to mqtt service.
        // Let's track the mapper session.
        ttnmapperSession = mapperSession
        ttnmapperSession!.delegates.addDelegate(self)
        ttnmapperSession!.delegates.addDelegate(uploader!)
        if let conf = conf {
            if conf.storeLocal {
                if localStorageSession == nil {
                    // Initiate a new local storage.
                    localStorageSession = TTNMapperLocalStorage.sharedInstance.newSession()
                }
                ttnmapperSession!.delegates.addDelegate(localStorageSession!)
            }
        }
        
        // Visual feedback.
        mappingSwitch.isOn = true
        connectionInfoLabel.text = "Connected: \(ttnmapperSession!.ttnbroker)"
        
        // Analytics
        Answers.logCustomEvent(withName: "MQTT Service", customAttributes: ["status": "Connected"])
    }
    
    func disconnected(_ reason: DisconnectReason) {
        mappingSwitch.onTintColor = defaultOnTintColor
        
        // Check disconnect reason.
        if reason == .connectionClosedByBroker {
            alert("Connection lost", message: "The TTN MQTT server has closed the connection. We are going to stop mapping.")
        }
        
        if reason == .connectionRefused {
            alert("Connection refused", message: "Unable to connect to the TTN MQTT broker. Please check your configuration for errors.")
        }
        
        // Analytics
        Answers.logCustomEvent(withName: "MQTT Service", customAttributes: ["status": "Disconnected", "disconnect reason": reason.rawValue])
        
        // Stop mapping
        stopMapping(shouldDisconnect: false)
    }
    
    func reconnecting(_ sessionReconnect: Int) {
        connectionInfoLabel.text = "Reconnecting to: \(conf!.ttnbroker) (\(sessionReconnect))"
        mappingSwitch.onTintColor = UIColor.orange
        mappingSwitch.isOn = true
        
        if sessionReconnect == 9 {
            // Analytics
            Answers.logCustomEvent(withName: "MQTT Service", customAttributes: ["status": "Reconnecting", "disconnect reason": "Connection lost"])
        }
    }
    
    // MARK: - TTNMapperSession callback methods
    
    func receivedNewDatapoints(_ datapoints: [TTNMapperDatapoint]) {
        for datapoint in datapoints {
            // Draw marker on the map
            self.mapView.addAnnotation(datapoint)
            if autoscaleButton.isOn {
                if let ttnmapperSession = ttnmapperSession {
                    if let currentLocation = ttnmapperSession.currentLocation {
                        setRegion(center: currentLocation)
                    }
                }
            }
        }
        
        self.diagnosticsDatapointsLabel.text = "Num datapoints: " + (ttnmapperSession?.datapoints.count.description)!
    }
    
    func receivedNewGateway(_ gateway: TTNMapperGateway) {
        // Note: Croft does not provide gateway location information.
        if gateway.isValid() {
            self.mapView.addAnnotation(gateway)
            self.diagnosticsGatewaysLabel.text = "Num gateways: " + (ttnmapperSession?.gateways.count.description)!
        }
    }
    
    func receivedInvalidGateway(_ gateway: TTNMapperGateway) {
        // Ignore for now.
    }
}

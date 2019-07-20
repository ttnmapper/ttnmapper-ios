//
//  MapViewerViewController.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 10/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit
import MapKit

class ArchiveMapViewController: BaseMapViewController, UIGestureRecognizerDelegate, TTNMapperSessionDelegate {

    @IBOutlet weak var mapView: MKMapView!

    @IBOutlet weak var autoscaleSwitch: UISwitch!
    @IBOutlet weak var timelapseSwitch: UISwitch!
    @IBOutlet weak var diagnosticsDatapointsLabel: UITextField!
    @IBOutlet weak var diagnosticsGatewaysLabel: UITextField!
    @IBOutlet weak var connectionInfoLabel: UITextField!    
    @IBOutlet weak var timelapseLabel: UITextField!

    var mapPanGesture : UIPanGestureRecognizer?
    
    var datapointsCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegate for map view.
        self.mapView.delegate = self
        
        // Set gesture delegate for autoscale disabling.
        mapPanGesture = UIPanGestureRecognizer(target: self, action: #selector(ArchiveMapViewController.disableAutoScale(_:)))
        mapPanGesture!.delegate = self
        self.mapView.addGestureRecognizer(mapPanGesture!)
    }
    
    // Disables the map from autoscaling.
    @objc func disableAutoScale(_ sender:UITapGestureRecognizer) {
        
        autoscaleSwitch.isOn = false
        self.mapView.removeGestureRecognizer(mapPanGesture!)
    }
    
    // Allow to recognize multiple gestures simultaneously (UIGestureRecognizerDelegate method)
    // This is needed for disabling autoscale.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reset view.
        resetView()
        
        // Hide the autoscale and mapping switches.
        if !autoscaleSwitch.isOn {
            autoscaleSwitch.isOn = true
            self.mapView.addGestureRecognizer(mapPanGesture!)
        }
        
        // Connect to mapper session delegate.
        if let ttnmapperSession = ttnmapperSession {
            ttnmapperSession.delegates.addDelegate(self)
            ttnmapperSession.reload(timelapseSwitch.isOn)
        
            if let currentLocation = ttnmapperSession.currentLocation {
                let region = Util.centerMapRegion(currentLocation, annotations: mapView.annotations)
                self.mapView.setRegion(region, animated: true)
            }
        }

    }
    
    func resetView() {
        // Set diagnostics labels.
        connectionInfoLabel.text = "Data from broker: \(ttnmapperSession!.ttnbroker)"
        diagnosticsDatapointsLabel.text = "Num datapoints: 0 of 0"
        diagnosticsGatewaysLabel.text = "Num gateways: 0"
        
        // Remove all annotations and user location from map.
        let overlays = mapView.overlays
        self.mapView.removeOverlays(overlays)
        let allAnnotations = self.mapView.annotations
        self.mapView.removeAnnotations(allAnnotations)
        self.mapView.showsUserLocation = false
        datapointsCounter = 0
        
        if isGateways() {
            timelapseLabel.text = "Coverage"
            let blueColor = Util.UIColorFromRGB(0x0D94FC) // RGB (13, 148, 252)
            timelapseSwitch.onTintColor = blueColor
        } else {
            timelapseLabel.text = "Timelapse"
            timelapseSwitch.onTintColor = UIColor.orange
        }
    }
    
    // Back button event handler. Stop session reload here if needed.
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            // Stop the session reload timer.
            if let ttnmapperSession = ttnmapperSession {
                ttnmapperSession.invalidateTimer()
            }
        }
    }
    
    @IBAction func autoScalePressed(_ sender: UISwitch) {
        if sender.isOn {
            if let ttnmapperSession = ttnmapperSession {
                if let currentLocation = ttnmapperSession.currentLocation {
                    let region = Util.centerMapRegion(currentLocation, annotations: mapView.annotations)
                    self.mapView.setRegion(region, animated: true)
                }
            }
            self.mapView.addGestureRecognizer(mapPanGesture!)
        }
    }
    
    @IBAction func timelapseSwitchChanged(_ sender: UISwitch) {
        if let ttnmapperSession = ttnmapperSession {
            ttnmapperSession.invalidateTimer()
            resetView()
            self.mapView.setNeedsDisplay()
            if isGateways() {
                // Gateway file. Show coverage
                if sender.isOn {
                    self.mapView.addOverlay(tileOverlay!)
                } else {
                    self.mapView.removeOverlay(tileOverlay!)
                }
            }
            ttnmapperSession.reload(sender.isOn)
        }
    }
    
    fileprivate func isGateways() -> Bool {
        if let ttnmapperSession = ttnmapperSession {
            if ttnmapperSession.datapoints.count == 0 && ttnmapperSession.gateways.count > 0 {
                return true
            }
        }
        return false
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - MQTTService callback methods
    
    func receivedNewDatapoints(_ datapoints: [TTNMapperDatapoint]) {
        
        NSLog("Drawing \(datapoints.count) datapoints")
        
        // Proces datapoints.
        for datapoint in datapoints {
            // Draw marker on the map
            self.mapView.addAnnotation(datapoint)
            if autoscaleSwitch.isOn {
                if let ttnmapperSession = ttnmapperSession {
                    if let currentLocation = ttnmapperSession.currentLocation {
                        let region = Util.centerMapRegion(currentLocation, annotations: mapView.annotations)
                        self.mapView.setRegion(region, animated: true)
                    }
                }
            }
        }
        // Increment data counter and set label.
        datapointsCounter += 1
        if let ttnmapperSession = ttnmapperSession {
            self.diagnosticsDatapointsLabel.text = "Num datapoints: \(datapointsCounter) of " +  ttnmapperSession.datapoints.count.description
            if datapointsCounter == ttnmapperSession.datapoints.count {
                timelapseSwitch.isOn = false
            }
        }
        NSLog("Drawing \(datapoints.count) datapoints ... [Done]")
    }
    
    func receivedNewGateway(_ gateway: TTNMapperGateway) {
        // Note: Croft does not provide gateway location information.
        if gateway.isValid() {
            self.mapView.addAnnotation(gateway)
        }
        // Set label.
        if let ttnmapperSession = ttnmapperSession {
            self.diagnosticsGatewaysLabel.text = "Num gateways: " + ttnmapperSession.gateways.count.description
        }
    }
    
    func receivedInvalidGateway(_ gateway: TTNMapperGateway) {
        // Skip for now.
    }
}

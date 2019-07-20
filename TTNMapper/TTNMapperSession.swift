//
//  TTNMapperSession.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 13/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//
//  

import Foundation
import CoreLocation

protocol TTNMapperSessionDelegate {
    func receivedNewDatapoints(_ datapoints: [TTNMapperDatapoint])
    func receivedNewGateway(_ gateway: TTNMapperGateway)
    func receivedInvalidGateway(_ gateway: TTNMapperGateway)
}

enum MapperSessionStatus { case new, started, stopped, archived }

class TTNMapperSession {
    
    var delegates = MulticastDelegate<TTNMapperSessionDelegate>()

    fileprivate(set) var createdOn : Date
    var status : MapperSessionStatus
    
    // Wrapper class for properly releasing the timer.
    fileprivate class TimerTargetWrapper {
        weak var session: TTNMapperSession?
        
        init(session: TTNMapperSession) {
            self.session = session
        }
        
        @objc func newDatapointRelease(_ timer: Timer?) {
            session?.newDatapointRelease()
        }
    }
    
    fileprivate var timer: Timer?
    fileprivate var counter = 0
    
    var currentLocation : CLLocation?
    
    // A list of gateways that have valid location information.
    var gateways = [String : TTNMapperGateway]()
    var datapoints = [TTNMapperDatapoint]()
    
    // When connecting we need to know to which broker.
    // When loading an archived session we will derive the broker.
    fileprivate var _ttnbroker : TTNBroker
    var ttnbroker : TTNBroker {
        get {
            // Attempt to derive the broker 
            if _ttnbroker == .none && datapoints.count != 0 {
                if datapoints[0].appEUI == nil {
                    return .Croft
                } else {
                    return .Production
                }
            } else {
                return _ttnbroker
            }
        }
    }

    init(ttnbroker: TTNBroker) {
        _ttnbroker = ttnbroker
        createdOn = Date()
        status = .new
    }
    
    deinit{
        print("TTNMapperSession deinited")
    }
    
    func addDataPoints(_ datapoints: [TTNMapperDatapoint]) {
        // Ignore datapoints if we cannot geotag them.
        if currentLocation == nil {
            return
        }
        
        // Geotag datapoints.
        for datapoint in datapoints {
            // Set datapoint location.
            datapoint.location = currentLocation
            
            // Store in innerlist.
            self.datapoints.append(datapoint)
            
            // Check for new gateway.
            if let gateway = datapoint.gateway {
                if gateways[gateway.gatewayId] == nil {
                    // Only add gateways with proper location information.
                    if gateway.isValid() {
                        // Add gateway to list.
                        gateways[gateway.gatewayId] = gateway
                        
                        // Notify subscribers of newly found gateway.
                        self.delegates.invoke {
                            $0.receivedNewGateway(gateway)
                        }
                    } else {
                        // Notify subscribers of gateway with invalid location.
                        self.delegates.invoke {
                            $0.receivedInvalidGateway(gateway)
                        }
                    }
                }
            }
        }
        
        // Notify subscribers of received datapoints.
        self.delegates.invoke {
            $0.receivedNewDatapoints(datapoints)
        }
    }

    func reload(_ timelapsed: Bool) {
        // Compute center if we have datapoints.
        if datapoints.count > 0 {
            let(centerLat, centerLon) = computeCenter()
            currentLocation = CLLocation(latitude: centerLat, longitude: centerLon)
        }
        
        // Notify all gateways (so they can be drawn first).
        for gateway in gateways {
            self.delegates.invoke {
                $0.receivedNewGateway(gateway.1)
            }
        }
        
        if timelapsed {
            // Start a timed session.
            timer = Timer.scheduledTimer(timeInterval: 0.1, target: TimerTargetWrapper(session: self), selector: #selector(TimerTargetWrapper.newDatapointRelease(_:)), userInfo: nil, repeats: true)
        } else {
            // Notify all datapoints.
            self.delegates.invoke {
                $0.receivedNewDatapoints(self.datapoints)
            }
        }
    }

    @objc func newDatapointRelease() {
        if counter == self.datapoints.count {
            invalidateTimer()
            counter = 0
        } else {
            var dps = [TTNMapperDatapoint]()
            dps.append(self.datapoints[counter])
            counter += 1
            
            self.delegates.invoke {
                $0.receivedNewDatapoints(dps)
            }
        }
    }
    
    fileprivate func computeCenter() -> (CLLocationDegrees, CLLocationDegrees) {
        // Set current location to center fo auto scale. (It's a bit of a hack).
        var topmost = datapoints[0].coordinate.latitude
        var bottommost = datapoints[0].coordinate.latitude
        var leftmost = datapoints[0].coordinate.longitude
        var rightmost = datapoints[0].coordinate.longitude
        
        for datapoint in datapoints {
            if datapoint.coordinate.latitude > topmost {
                topmost = datapoint.coordinate.latitude
            }
            if datapoint.coordinate.latitude < bottommost {
                bottommost = datapoint.coordinate.latitude
            }
            if datapoint.coordinate.longitude > leftmost {
                leftmost = datapoint.coordinate.longitude
            }
            if datapoint.coordinate.longitude < rightmost {
                rightmost = datapoint.coordinate.longitude
            }
        }
        
        for gateway in gateways {
            if gateway.1.isValid() {
                if gateway.1.location!.coordinate.latitude > topmost {
                    topmost = gateway.1.location!.coordinate.latitude
                }
                if gateway.1.location!.coordinate.latitude < bottommost {
                    bottommost = gateway.1.location!.coordinate.latitude
                }
                if gateway.1.location!.coordinate.longitude > leftmost {
                    leftmost = gateway.1.location!.coordinate.longitude
                }
                if gateway.1.location!.coordinate.longitude < rightmost {
                    rightmost = gateway.1.location!.coordinate.longitude
                }
            }
        }
        let centerLat = bottommost + (topmost - bottommost ) / 2
        let centerLon = leftmost + (rightmost - leftmost) / 2
        
        return (centerLat, centerLon)
    }
    
    func invalidateTimer() {
        if let timer = self.timer {
            NSLog("Invalidating")
            timer.invalidate()
            self.timer = nil
        }
        counter = 0
    }
}

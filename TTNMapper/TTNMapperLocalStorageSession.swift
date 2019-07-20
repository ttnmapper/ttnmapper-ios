//
//  TTNMapperLocalStorageSession.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 04/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation

class TTNMapperLocalStorageSession: TTNMapperSessionDelegate {

    fileprivate(set) var createdOn : Date
    var datapoints = [TTNMapperDatapoint]()
    var gateways = [String: TTNMapperGateway]()
    
    var filename : String {
        get {
            let calendar = Calendar.current
            let components = (calendar as NSCalendar).components([.day , .month , .year, .hour, .minute, .second], from: createdOn)
            
            return String(format:"%d%02d%02d-%02d%02d%02d-ttnmapper.csv", components.year!, components.month!, components.day!, components.hour!, components.minute!, components.second!)
        }
    }
    
    init() {
        createdOn = Date()
        gateways = TTNMapperLocalStorage.sharedInstance.loadGateways()
    }
    
    func getContentsForLocalStorage() -> NSMutableString {
        let convertMutable = NSMutableString()
        convertMutable.appendFormat("time,nodeaddr,appeui,gwaddr,datarate,snr,rssi,freq,lat,lon,alt,accuracy\r")
        
        convertMutable.append(getContentsForLocalStorage(datapoints) as (String))
        
        return convertMutable
    }
    
    fileprivate func getContentsForLocalStorage(_ datapoints: [TTNMapperDatapoint]) -> NSMutableString {
        let convertMutable = NSMutableString()
        
        // Set string ready for file writing.
        for datapoint in datapoints {
            convertMutable.appendFormat("%@,", datapoint.time!)
            convertMutable.appendFormat("%@,", datapoint.nodeAddr!)
            if let appEUI = datapoint.appEUI {
                convertMutable.appendFormat("%@,", appEUI)
            } else {
                convertMutable.appendFormat("%@,", "")
            }
            convertMutable.appendFormat("%@,", datapoint.gateway!.gatewayId)
            convertMutable.appendFormat("%@,", datapoint.dataRate!)
            convertMutable.appendFormat("%@,", (datapoint.snr?.description)!)
            convertMutable.appendFormat("%@,", (datapoint.rssi?.description)!)
            convertMutable.appendFormat("%@,", (datapoint.frequency?.description)!)
            convertMutable.appendFormat("%@,", datapoint.location!.coordinate.latitude.description)
            convertMutable.appendFormat("%@,", datapoint.location!.coordinate.longitude.description)
            convertMutable.appendFormat("%@,", datapoint.location!.altitude.description)
            convertMutable.appendFormat("%@\r", datapoint.location!.horizontalAccuracy.description)
        }
        return convertMutable
    }
    
    // MARK: - MQTTService callback methods
    
    func receivedNewDatapoints(_ datapoints: [TTNMapperDatapoint]) {
        // Append datapoints to list
        for datapoint in datapoints {
            self.datapoints.append(datapoint)
        }
        
        //TODO: - Check if the file exists and append data.
        
        // For now we simple write everything.
        TTNMapperLocalStorage.sharedInstance.store(self, canOverride: true)
        
    }
    
    func receivedNewGateway(_ gateway: TTNMapperGateway) {
        // Check for new gateway.
        let cachedGateway = gateways[gateway.gatewayId]
        if cachedGateway == nil {
            
            // Only add gateways with proper location information.
            if gateway.isValid() {
                // Add gateway to list.
                gateways[gateway.gatewayId] = gateway
                
                // Store gateways
                TTNMapperLocalStorage.sharedInstance.store(gateways)
            }
        }
    }
    
    func receivedInvalidGateway(_ gateway: TTNMapperGateway) {
        // Skip for now.
    }
    
}

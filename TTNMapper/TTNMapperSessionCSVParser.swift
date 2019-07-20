//
//  TTNMapperSessionCSVParser.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 09/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import CoreLocation

class TTNMapperSessionCSVParser {
    
    var cachedGateways = [String: TTNMapperGateway]()
    
    init() {
        cachedGateways = TTNMapperLocalStorage.sharedInstance.loadGateways()
    }
    
    func parse(_ content: NSString) -> TTNMapperSession {
        let mapperSession = TTNMapperSession(ttnbroker: .None)
        
        // Split content in lines
        let lines:[String] = content.components(separatedBy: CharacterSet.newlines) as [String]
        
        for line in lines {
            let csvLine = CSVSessionLine(line: line)
            
            if !csvLine.isHeader() {
                // Build up datapoint
                let datapoint = TTNMapperDatapoint()
                datapoint.time = csvLine.safeGetValue(CSVSessionLine.header.time.rawValue)
                datapoint.nodeAddr = csvLine.safeGetValue(CSVSessionLine.header.nodeaddr.rawValue)
                datapoint.appEUI = csvLine.safeGetValue(CSVSessionLine.header.appeui.rawValue)
                datapoint.dataRate = csvLine.safeGetValue(CSVSessionLine.header.datarate.rawValue)
                datapoint.snr = 0.0
                if let snr = csvLine.safeGetValue(CSVSessionLine.header.snr.rawValue) {
                    datapoint.snr = Double(snr)
                }
                // If we don't have a valid rssi then skip this data point.
                if let rssi = csvLine.safeGetValue(CSVSessionLine.header.rssi.rawValue) {
                    datapoint.rssi = Double(rssi)
                } else {
                    // Skip
                    continue
                }
                datapoint.frequency = 0.0
                if let frequency = csvLine.safeGetValue(CSVSessionLine.header.freq.rawValue) {
                    datapoint.frequency = Double(frequency)
                }
                // If we don't have a valid location then skip this data point.
                if let lat = csvLine.safeGetValue(CSVSessionLine.header.lat.rawValue), let lon = csvLine.safeGetValue(CSVSessionLine.header.lon.rawValue) {
                    var accuracy = 0.0
                    if csvLine.safeGetValue(CSVSessionLine.header.accuracy.rawValue) != nil {
                        accuracy = Double(csvLine.safeGetValue(CSVSessionLine.header.accuracy.rawValue)!)!
                    }
                    var alt = 0.0
                    if (csvLine.safeGetValue(CSVSessionLine.header.alt.rawValue) != nil) {
                        alt = Double(csvLine.safeGetValue(CSVSessionLine.header.alt.rawValue)!)!
                    }
                    let coordinate = CLLocationCoordinate2D(latitude: Double(lat)!, longitude: Double(lon)!)
                    let location = CLLocation(coordinate: coordinate, altitude: alt, horizontalAccuracy: accuracy, verticalAccuracy: 0.0, timestamp: Date())
                    datapoint.location = location
                } else {
                    // Skip
                    continue
                }
                
                // Gateways are loaded when new session is created.
                // Thus, we should retrieve the gateways from the innerlist.
                let gatewayEUI = csvLine.safeGetValue(CSVSessionLine.header.gwaddr.rawValue)
                let cachedGateway = cachedGateways[gatewayEUI!]
                if let gateway = cachedGateway {
                    // Add gateway from cache.
                    mapperSession.gateways[gatewayEUI!] = gateway
                    datapoint.gateway = gateway
                } else {
                    // Should never happen but just in case.
                    // Create a new instance and store it in gateway cache.
                    let gateway = TTNMapperGateway(gatewayId: gatewayEUI!, timestamp: Date().description, location: nil)
                    mapperSession.gateways[gatewayEUI!] = gateway
                    datapoint.gateway = gateway
                }
                mapperSession.datapoints.append(datapoint)
            }
        }
        return mapperSession
    }
    
    class CSVSessionLine : CSVLine {
        fileprivate enum header : Int {
            case time,nodeaddr,appeui,gwaddr,datarate,snr,rssi,freq,lat,lon,alt,accuracy
            static var count: Int { return header.accuracy.rawValue + 1 }
        }
        
        var headerLine : String {
            get {
                return "time,nodeaddr,appeui,gwaddr,datarate,snr,rssi,freq,lat,lon,alt,accuracy\r"
            }
        }
        
        func isHeader() -> Bool {
            let firstItem = safeGetValue(header.time.rawValue)
            if firstItem != nil {
                if firstItem == "" || firstItem == "\(header.time)" {
                    return true
                }
            }
            return false
        }
    }

}

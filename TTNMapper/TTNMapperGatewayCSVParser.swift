//
//  TTNMapperGatewayCSVParser.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 09/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import CoreLocation

class TTNMapperGatewayCSVParser {

    func parse(_ content: NSString) -> [String: TTNMapperGateway] {
        
        var result = [String: TTNMapperGateway]()
        let lines:[String] = content.components(separatedBy: CharacterSet.newlines) as [String]
        
        for line in lines {
            
            let csvLine = CSVGatewayLine(line: line)
            if !csvLine.isHeader() {
                let time = csvLine.safeGetValue(CSVGatewayLine.header.time.rawValue)
                let gatewayEUI = csvLine.safeGetValue(CSVGatewayLine.header.gwaddr.rawValue)
                let lat = Double(csvLine.safeGetValue(CSVGatewayLine.header.gwlat.rawValue)!)
                let lon = Double(csvLine.safeGetValue(CSVGatewayLine.header.gwlon.rawValue)!)
                var gatewayLocation : CLLocation? = nil
                if lat != nil && lon != nil {
                    let alt = Double(csvLine.safeGetValue(CSVGatewayLine.header.gwalt.rawValue)!)
                    let accuracy = Double(csvLine.safeGetValue(CSVGatewayLine.header.accuracy.rawValue)!)
                    let coordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
                    gatewayLocation = CLLocation(coordinate: coordinate, altitude: alt!, horizontalAccuracy: accuracy!, verticalAccuracy: 0.0, timestamp: Date())
                }
                let gateway = TTNMapperGateway(gatewayId: gatewayEUI!, timestamp: time!, location: gatewayLocation)
                
                // Add new gateway to dictionary.
                result[gateway.gatewayId] = gateway
            }
        }
        return result
    }
    
    func convertToData(_ gateways: [String: TTNMapperGateway]) -> Data? {
        let headerLine = "time,gwaddr,gwlat,gwlon,gwalt,accuracy\r"
        
        // Convert objects to string.
        let convertMutable = NSMutableString()
        convertMutable.appendFormat(headerLine as NSString)
        for gateway in gateways {
            convertMutable.appendFormat("%@,", gateway.1.timestamp)
            convertMutable.appendFormat("%@,", gateway.1.gatewayId)
            if let location = gateway.1.location {
                let coordinate = location.coordinate
                convertMutable.appendFormat("%@,", coordinate.latitude.description)
                convertMutable.appendFormat("%@,", coordinate.longitude.description)
                convertMutable.appendFormat("%@,", location.altitude.description)
                convertMutable.appendFormat("%@\r",location.horizontalAccuracy.description)
            } else {
                convertMutable.appendFormat("%@,", "")
                convertMutable.appendFormat("%@,", "")
                convertMutable.appendFormat("%@,", "")
                convertMutable.appendFormat("%@\r", "")
            }
        }
        
        // Convert above NSMutableString to NSData
        return convertMutable.data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
    }
    
    class CSVGatewayLine : CSVLine {
        fileprivate enum header : Int {
            case time,gwaddr,gwlat,gwlon,gwalt,accuracy
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

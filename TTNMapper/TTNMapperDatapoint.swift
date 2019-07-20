//
//  TTNMapperPacket.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 08/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import MapKit

class TTNMapperDatapoint: NSObject, MKAnnotation {
    
    var nodeAddr : String?
    var appEUI : String?
    var time : String?
    var frequency : Double?
    var dataRate : String?
    var rssi : Double?
    var snr : Double?
    var location : CLLocation?
    var gateway : TTNMapperGateway?
    
    // MARK: - MKAnnotation properties
    
    var timestamp: String
    var title: String? {
        get {
            if let _time = time {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                guard let date = dateFormatter.date(from: _time) else {
                    NSLog("ERROR: Date conversion failed due to mismatched format.")
                    return ""
                }
                
                let dateFormatterPrint = DateFormatter()
                dateFormatterPrint.dateFormat = "yyyy-MM-dd @ HH:mm"
                return dateFormatterPrint.string(from: date)
                
            } else {
                return "Datapoint"
            }
        }
    }
    var coordinate: CLLocationCoordinate2D {
        get {
            return location!.coordinate
        }
    }
    
    var lines: [String] {
        get {
            let divider = "-------------------------"
            var _lines: [String] = []
            _lines.append(divider)
            if let _gateway = gateway {
                _lines.append("gateway: \(_gateway.gatewayId)")
                if let _location = location, let _gwLocation = _gateway.location {
                    let distanceInMeters = Util.roundToPlaces(value: _gwLocation.distance(from: _location), places: 0)
                    _lines.append("distance: \(distanceInMeters) m")
                } else {
                    _lines.append("(unknown location)")
                }
                _lines.append(divider)
            }
            if let _dataRate = dataRate {
                _lines.append("data rate: \(_dataRate)")
            }
            if let _frequency = frequency {
                _lines.append("frequency: \(_frequency)")
            }
            if let _rssi = rssi {
                _lines.append("rssi: \(_rssi)")
            }
            if let _snr = snr {
                _lines.append("snr: \(_snr)")
            }
            return _lines
        }
    }
    
    override init() {
        timestamp = Util.getCurrentDateFormatted()
        super.init()
    }
    
    func isValid() -> Bool {
        if nodeAddr != nil && time != nil && frequency != nil && dataRate != nil && rssi != nil && snr != nil /*&& location != nil*/ && gateway != nil {
            return true
        }
        
        NSLog("Error invalid datapoint")
        return false
    }
}

//
//  Util.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 21/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import MapKit

extension Formatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}

extension Date {
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}

class Util {
    
    fileprivate static let minRegionLatitudeDelta = 0.005
    fileprivate static let minRegionLongitudeDelta = 0.005
    fileprivate static let maxRegionLatitudeDelta = 0.03
    fileprivate static let maxRegionLongitudeDelta = 0.03
    fileprivate static let deltaBuffer = 0.005
    
    fileprivate static let defaultRssi = -1.0

    fileprivate static let blueThreshold = -120.0
    fileprivate static let cyanThreshold = -115.0
    fileprivate static let greenThreshold = -110.0
    fileprivate static let yellowThreshold = -105.0
    fileprivate static let orangeThreshold = -100.0
    
    static func gatewayMarkerType() -> String {
        return "gateway_dot"
    }

    static func parseMarkerType(_ datapoint: TTNMapperDatapoint) -> String {
        let rssi = datapoint.rssi ?? defaultRssi
        let markerType = parseMarkerType(rssi)

        guard let gateway = datapoint.gateway, let _ = gateway.location else {
            return "\(markerType)_unknown"
        }
        return markerType
    }
    
    private static func parseMarkerType(_ rssi: Double) -> String {
        let markerType : String?
        
        if (rssi < blueThreshold) {
            markerType = "blue_dot";
        } else if (rssi < cyanThreshold) {
            markerType = "cyan_dot";
        } else if (rssi < greenThreshold) {
            markerType = "green_dot";
        } else if (rssi < yellowThreshold) {
            markerType = "yellow_dot";
        } else if (rssi < orangeThreshold) {
            markerType = "orange_dot";
        } else {
            markerType = "red_dot";
        }
        
        return markerType!
    }
    
    static func gettColorForRssi(_ rssi: Double) -> UIColor {
        let hex : UInt?
        
        if (rssi == 0) {
            hex = 0xFFFFFF  // White
        } else if (rssi < blueThreshold) {
            hex = 0x0000ff  //blue_dot
        } else if (rssi < cyanThreshold) {
            hex = 0x00ffff  //cyan_dot
        } else if (rssi < greenThreshold) {
            hex = 0x01A23A //0x00ff00  //green_dot
        } else if (rssi < yellowThreshold) {
            hex = 0xFFDF01 //0xffff00  //yellow_dot
        } else if (rssi < orangeThreshold) {
            hex = 0xFF6502 //0xff7f00  //orange_dot
        } else {
            hex = 0xF01413 //0xff0000  //red_dot
        }
        
        return UIColorFromRGB(hex!)
    }
 
    static func UIColorFromRGB(_ rgbValue: UInt) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    static func getCurrentDateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    static func centerMapRegion(_ location: CLLocation, annotations: [MKAnnotation], capMaxRegion: Bool = false) -> MKCoordinateRegion {
    
        let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    
        let spanCoordinate = computeRegionSpan(center, annotations: annotations, capMaxRegion: capMaxRegion)
    
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: spanCoordinate.latitude, longitudeDelta: spanCoordinate.longitude))
    
        return region
    }
    
    fileprivate static func computeRegionSpan(_ center : CLLocationCoordinate2D, annotations: [MKAnnotation], capMaxRegion: Bool = false) -> CLLocationCoordinate2D {
        
        // Set minimal region
        var result = CLLocationCoordinate2D(latitude: minRegionLatitudeDelta, longitude: minRegionLongitudeDelta)
        
        // Iterate through all annotations in order to determine region
        for annotation in annotations {
            let latitudeDelta = abs(center.latitude - annotation.coordinate.latitude)
            if latitudeDelta > result.latitude {
                result.latitude = latitudeDelta
            }
            let longitudeDelta = abs(center.longitude - annotation.coordinate.longitude)
            if longitudeDelta > result.longitude {
                result.longitude = longitudeDelta
            }
        }
        // Scale span to fit
        result.latitude = (result.latitude * 2) + deltaBuffer
        result.longitude = (result.longitude * 2) + deltaBuffer
        
        // Cap to maximum region size if specified.
        if capMaxRegion {
            if result.latitude > maxRegionLatitudeDelta || result.longitude > maxRegionLongitudeDelta {
                result.latitude = maxRegionLatitudeDelta
                result.longitude = maxRegionLongitudeDelta
            }
        }
        
        return result
    }

    static func roundToPlaces(value:Double, places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return round(value * divisor) / divisor
    }

    /*
     * Util function for creating a one second run loop.
     */
    func runLoop(_ seconds: Int) {
        let now = Date()
        let next = (Calendar.current as NSCalendar)
            .date(
                byAdding: NSCalendar.Unit.second,
                value: seconds,
                to: now,
                options: []
        )
        RunLoop.current.run(until: next!)
    }

}

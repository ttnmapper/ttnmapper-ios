//
//  TTNMapperGateway.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 27/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import MapKit

extension CLLocationCoordinate2D {
    func isEqual(_ coord: CLLocationCoordinate2D) -> Bool {
        return (fabs(self.latitude - coord.latitude) < .ulpOfOne) && (fabs(self.longitude - coord.longitude) < .ulpOfOne)
    }
}

class TTNMapperGateway : NSObject, MKAnnotation {
    
    var title: String? {
        return gatewayId
    }
    var subtitle: String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = dateFormatter.date(from: timestamp) {
            let dateFormatterPrint = DateFormatter()
            dateFormatterPrint.dateFormat = "yyyy-MM-dd @ HH:mm"
            return "First seen: \(dateFormatterPrint.string(from: date))"
        }
        // Let's try a different format just to be sure (used by raspberry pi gateways for example).
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = dateFormatter.date(from: timestamp) {
            let dateFormatterPrint = DateFormatter()
            dateFormatterPrint.dateFormat = "yyyy-MM-dd @ HH:mm"
            return "First seen: \(dateFormatterPrint.string(from: date))"
        }
        return ""
    }
    
    let gatewayId: String
    let timestamp: String
    let location: CLLocation?
    var coordinate: CLLocationCoordinate2D
    fileprivate let noLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    
    init(gatewayId: String, timestamp: String, location: CLLocation?) {
        self.gatewayId = gatewayId
        self.timestamp = timestamp
        self.location = location
        self.coordinate = noLocation
        if location != nil {
            self.coordinate = location!.coordinate
        }
        
        super.init()
    }
    
    func isValid() -> Bool {
        if coordinate.isEqual(noLocation)  {
            return false
        }
        return true
    }
}

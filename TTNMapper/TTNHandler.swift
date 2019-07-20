//
//  TTNHandler.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 30/08/2017.
//  Copyright © 2017 Timothy Sealy. All rights reserved.
//

import Foundation

class TTNHandler {
    
    var id: String
    var apiAddress: String
    var netAddress: String
    var mqttAddress: String
    
    init(id: String, apiAddress: String, netAddress: String, mqttAddress: String) {
        self.id = id
        self.apiAddress = apiAddress
        self.netAddress = netAddress
        self.mqttAddress = mqttAddress
    }
}

//
//  TTNMapperConfiguration.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 12/06/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation

enum TTNBroker { case None, Croft, Staging, Production }

class TTNMapperConfiguration {
    
    var changedOn: CFAbsoluteTime!
    var version = 0
    
    var ttnbroker: String = Constants.TTNBROKER_NONE
    var ttnbrokerurl: String {
        get {
            if ttnbroker == Constants.TTNBROKER_PROD {
                return ttnbrokerRegion
            }
            return ""
        }
    }
    var ttnbrokerport = 1883
    
    var topic: String {
        get {
            if !deviceEUI.isEmpty && !appEUI.isEmpty {
                return appEUI + "/devices/" + deviceEUI + "/up"
            }
            return ""
        }
    }
    var authenticationRequired: Bool {
        get {
            return true
        }
    }
    
    var ttnbrokerRegion: String = ""
    var username: String = ""
    var password: String = ""
    var appEUI: String = ""
    var deviceEUI: String = ""
    
    // Default to always upload results
    var doUpload : Bool = true

    var experimentName: String = ""
    var isExperimental: Bool = true
    var storeLocal: Bool = false
    let qos : Int32 = 0
    
    func isValid() -> Bool {
        if ttnbroker != Constants.TTNBROKER_PROD {
            return false
        }
        if isExperimental && experimentName == "" {
            return false
        }
        return true
    }
}

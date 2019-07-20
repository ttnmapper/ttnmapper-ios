//
//  TTNMapperConfigurationStorage.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 12/01/17.
//  Copyright © 2017 Timothy Sealy. All rights reserved.
//

import Foundation

class TTNMapperConfigurationStorage {
    
    fileprivate let CURRENT_CONFIGURATION_VERSION = 1
    
    fileprivate let KEY_CONFIGURATION_VERSION : String = "KEY_CONFIGURATION_VERSION"
    fileprivate let KEY_TTNBROKER_REGION : String = "KEY_TTNBROKER_REGION"
    fileprivate let KEY_TTNBROKER_PORT : String = "KEY_TTNBROKER_PORT"
    fileprivate let KEY_TTNBROKER : String = "KEY_TTNBROKER"
    fileprivate let KEY_USERNAME : String = "KEY_USERNAME"
    fileprivate let KEY_PASSWD : String = "KEY_PASSWD"
    fileprivate let KEY_APPEUI : String = "KEY_APPEUI"
    fileprivate let KEY_DEVEUI : String = "KEY_DEVEUI"
    fileprivate let KEY_UPLOAD : String = "KEY_UPLOAD"
    fileprivate let KEY_EXPERIMENTAL : String = "KEY_EXPERIMENTAL"
    fileprivate let KEY_EXPERIMEN_NAME : String = "KEY_EXPERIMEN_NAME"
    fileprivate let KEY_STORELOCAL : String = "KEY_STORELOCAL"
    fileprivate let KEY_CHANGED_ON : String = "KEY_CHANGED_ON"
    
    // Singleton
    static let sharedInstance = TTNMapperConfigurationStorage()
    fileprivate init() {}
    
    func store(_ conf: TTNMapperConfiguration) {
        
        if conf.isValid() {
            // Store configuration in user defaults
            let defaults = UserDefaults.standard
            
            defaults.set(conf.version, forKey: KEY_CONFIGURATION_VERSION)
            defaults.set(conf.ttnbrokerRegion, forKey: KEY_TTNBROKER_REGION)
            defaults.set(conf.ttnbrokerport, forKey: KEY_TTNBROKER_PORT)
            defaults.set(conf.ttnbroker, forKey: KEY_TTNBROKER)
            defaults.set(conf.username, forKey: KEY_USERNAME)
            defaults.set(conf.password, forKey: KEY_PASSWD)
            defaults.set(conf.appEUI, forKey: KEY_APPEUI)
            defaults.set(conf.deviceEUI, forKey: KEY_DEVEUI)
            defaults.set(conf.doUpload, forKey: KEY_UPLOAD)
            
            defaults.set(conf.isExperimental, forKey: KEY_EXPERIMENTAL)
            defaults.set(conf.experimentName, forKey: KEY_EXPERIMEN_NAME)
            defaults.set(conf.storeLocal, forKey: KEY_STORELOCAL)
            
            defaults.set(conf.changedOn, forKey: KEY_CHANGED_ON)
            
            defaults.synchronize()
        }
    }
    
    func load() -> TTNMapperConfiguration {
        let conf = TTNMapperConfiguration()
        
        // Load configuration from user defaults
        let defaults = UserDefaults.standard
        
        conf.version = defaults.integer(forKey: KEY_CONFIGURATION_VERSION)
        if let ttnbrokerRegionStored = defaults.string(forKey: KEY_TTNBROKER_REGION) {
            conf.ttnbrokerRegion = ttnbrokerRegionStored
            
            // Update configuration to next version.
            // Convert shorthand to full mqtt handler url.
            if conf.version == 0 && conf.version != CURRENT_CONFIGURATION_VERSION {
                if !conf.ttnbrokerRegion.hasSuffix(".thethings.network") {
                    conf.ttnbrokerRegion = ttnbrokerRegionStored + ".thethings.network"
                }
                conf.version = CURRENT_CONFIGURATION_VERSION
            }
        }
        conf.ttnbrokerport = defaults.integer(forKey: KEY_TTNBROKER_PORT)
        
        if let ttnbrokerStored = defaults.string(forKey: KEY_TTNBROKER) {
            conf.ttnbroker = ttnbrokerStored
        }
        if let usernameStored = defaults.string(forKey: KEY_USERNAME) {
            conf.username = usernameStored
        }
        if let passwordStored = defaults.string(forKey: KEY_PASSWD) {
            conf.password = passwordStored
        }
        if let appEUIStored = defaults.string(forKey: KEY_APPEUI) {
            conf.appEUI = appEUIStored
        }
        if let deviceEUIStored = defaults.string(forKey: KEY_DEVEUI) {
            conf.deviceEUI = deviceEUIStored
        }
        
        conf.isExperimental = defaults.bool(forKey: KEY_EXPERIMENTAL)
        if let experimentNameStored = defaults.string(forKey: KEY_EXPERIMEN_NAME) {
            conf.experimentName = experimentNameStored
        }
        conf.storeLocal = defaults.bool(forKey: KEY_STORELOCAL)
        
        if let changedOnStored = defaults.object(forKey: KEY_CHANGED_ON) {
            conf.changedOn = changedOnStored as? CFAbsoluteTime
        }
        
        return conf
    }
}

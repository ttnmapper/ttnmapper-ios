//
//  TTNMapperLocalStorage.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 13/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import CoreLocation

class TTNMapperLocalStorage {
    
    static let filenameGateways = "gateways-ttnmapper.csv"
    
    static let sharedInstance = TTNMapperLocalStorage()
    
    //This prevents others from using the default '()' initializer for this class.
    fileprivate init() {}
    
    // MARK: - Session methods
    
    func newSession() -> TTNMapperLocalStorageSession {
        return TTNMapperLocalStorageSession()
    }

    func listSessions() -> [String] {
        var sessions : [String] = []
        
        let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            do {
                let listing = try FileManager.default.contentsOfDirectory(atPath: iCloudDocumentsURL.path)
                
                // Set gateways on top. 
                // Note sort is inefficient.
                for file in listing {
                    if file == TTNMapperLocalStorage.filenameGateways {
                        sessions.append(file)
                        break
                    }
                }
                
                // Filter hidden files.
                let filteredListing = listing.filter({!$0.hasPrefix(".")})
                
                if sessions.count == 0 {
                    sessions = filteredListing
                } else {
                    for file in filteredListing {
                        if file != TTNMapperLocalStorage.filenameGateways {
                            sessions.append(file)
                        }
                    }
                }
                
            } catch let error as NSError {
                NSLog("Error listing directory: \(error.localizedDescription)")
            }
        }
        return sessions
    }
    
    func store(_ session: TTNMapperLocalStorageSession, canOverride: Bool = false) {
       
        // Open "Documents" directory
        let iCloudDocumentsURL = getICloudDocumentsURL()
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            if session.datapoints.count > 0 {
                // Check if file already exists.
                let iCloudFileURL = iCloudDocumentsURL.appendingPathComponent(session.filename)
                
                // Convert above NSMutableString to NSData
                let data = session.getContentsForLocalStorage().data(using: String.Encoding.utf8.rawValue, allowLossyConversion: false)
                if let data = data { // Unwrap since data is optional and print
                
                    if !FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                        let created = FileManager.default.createFile(atPath: iCloudFileURL.path, contents: data, attributes: nil)
                        if !created {
                            NSLog("Error creating file: " + session.filename)
                        }
                    } else if canOverride {
                        try? data.write(to: iCloudFileURL, options: [.atomic])
                    }
                }
            }
        }
    }
    
    func loadSession(_ filename: String) -> TTNMapperSession? {
        
        // Open "Documents" directory
        let iCloudDocumentsURL = getICloudDocumentsURL()
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            let iCloudFileURL = iCloudDocumentsURL.appendingPathComponent(filename)
            
            if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                
                let data = FileManager.default.contents(atPath: iCloudFileURL.path)
                if let content = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
                    // Parse content.
                    if filename == TTNMapperLocalStorage.filenameGateways {
                        let parser = TTNMapperGatewayCSVParser()
                        let mapperSession = TTNMapperSession(ttnbroker: .None)
                        mapperSession.status = .archived
                        mapperSession.gateways = parser.parse(content)
                        return mapperSession
                    } else {
                        let parser = TTNMapperSessionCSVParser()
                        let mapperSession = parser.parse(content)
                        mapperSession.status = .archived
                        return mapperSession
                    }
                }
            }
        }
        return nil
    }
    
    func deleteSession(_ filename: String) {
    
        let iCloudDocumentsURL = getICloudDocumentsURL()
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            let iCloudFileURL = iCloudDocumentsURL.appendingPathComponent(filename)
            
            if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                do {
                    try FileManager.default.removeItem(at: iCloudFileURL)
                } catch let error as NSError {
                    NSLog("Can't delete file \(error)")
                }
            }
        }
    }

    // MARK: - Gateways methods
    
    func store(_ gateways: [String: TTNMapperGateway]) {
        
        // Convert gateways to data.
        let parser = TTNMapperGatewayCSVParser()
        let data = parser.convertToData(gateways)
        if let data = data {
            // Open "Documents" directory.
            let iCloudDocumentsURL = getICloudDocumentsURL()
            if let iCloudDocumentsURL = iCloudDocumentsURL {
                // Open gateway file
                let iCloudFileURL = iCloudDocumentsURL.appendingPathComponent(TTNMapperLocalStorage.filenameGateways)
                if !FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                    // Create the file if needed.
                    let created = FileManager.default.createFile(atPath: iCloudFileURL.path, contents: data, attributes: nil)
                    
                    if !created {
                        NSLog("Error creating file: " + TTNMapperLocalStorage.filenameGateways)
                    }
                } else {
                    try? data.write(to: iCloudFileURL, options: [.atomic])
                }
            }
        }
    }
    
    
    func loadGateways() -> [String: TTNMapperGateway] {
        
        let iCloudDocumentsURL = getICloudDocumentsURL()
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            let iCloudFileURL = iCloudDocumentsURL.appendingPathComponent(TTNMapperLocalStorage.filenameGateways)
            
            if FileManager.default.fileExists(atPath: iCloudFileURL.path) {
                let data = FileManager.default.contents(atPath: iCloudFileURL.path)
                
                if let content = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
                    // Parse content.
                    let parser = TTNMapperGatewayCSVParser()
                    return parser.parse(content)
                }
            }
        }
        return [String: TTNMapperGateway]()
    }
    
    // MARK: - Util functions
        
    func getICloudDocumentsURL() -> URL? {
        
        let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    
        if let iCloudDocumentsURL = iCloudDocumentsURL {
            // Create directory if it does not exist.
            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
            
                do {
                    try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch let error as NSError {
                    NSLog("Error creating directory: \(error.localizedDescription)")
                }
            }
        }
        return iCloudDocumentsURL
    }
}

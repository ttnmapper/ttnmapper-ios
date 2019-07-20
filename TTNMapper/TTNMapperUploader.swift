//
//  TTNMapperUploader.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 17/06/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import MapKit
import Crashlytics

class TTNMapperUploader: TTNMapperSessionDelegate {
    
    fileprivate let NODE_UPLOAD_URL = "https://ttnmapper.org/appapi/upload.php"
    fileprivate let GATEWAY_UPLOAD_URL = "https://ttnmapper.org/appapi/update_gateway.php"
    
    // This string identifies the ios app un ttnmapper.org
    fileprivate var userAgent : String
    
    // Properties that are read from configuration.
    fileprivate(set) var topic : String
    fileprivate(set) var ttnbroker : String
    fileprivate(set) var isExperimental : Bool
    fileprivate(set) var experimentName : String
    // Initialize instanceID with some default UUID
    fileprivate(set) var instanceID: String = "4C2DCA2E-1A1B-4E31-B181-57207D220B82"
    
    init(configuration: TTNMapperConfiguration) {
        // Initialize some fields from the configuration.
        self.topic = configuration.topic
        self.ttnbroker = configuration.ttnbroker
        self.experimentName = configuration.experimentName
        self.isExperimental = configuration.isExperimental
        
        // Build a userAgent string for ttnmapper.org
        let systemVersion = "iOS " + UIDevice.current.systemVersion
        let versionName = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? NSString
        self.userAgent = systemVersion + " - " + (versionName! as String)
        let versionCode = Bundle.main.infoDictionary?["CFBundleVersion"] as? NSString
        self.userAgent = userAgent + ":" + (versionCode! as String)
        
        if let identifierForVendor = UIDevice.current.identifierForVendor {
            self.instanceID = identifierForVendor.description
        }
    }
    
    // MARK: - MQTTService callback methods
    
    func receivedNewDatapoints(_ datapoints: [TTNMapperDatapoint]) {
        for datapoint in datapoints {
            upload(datapoint)
        }
    }
    
    func receivedNewGateway(_ gateway: TTNMapperGateway) {
        // Ignore. We will upload the gateways from the datapoints received.
    }
    
    func receivedInvalidGateway(_ gateway: TTNMapperGateway) {
        // Ignore. We will upload the gateways from the datapoints received.
    }
    
    //
    // Uploads a received data point (including location information) to ttnmapper.org.
    //
    fileprivate func upload(_ ttnmapperPacket: TTNMapperDatapoint) {
        
        guard ttnmapperPacket.gateway != nil else {
            NSLog("Dropped packet because gateways is nil")
            return
        }
        guard ttnmapperPacket.location != nil else {
            NSLog("Dropped packet because location is nil")
            return
        }
        
        let data: NSMutableDictionary = NSMutableDictionary()
        data.setValue(ttnmapperPacket.appEUI, forKey: "appeui")
        data.setValue(ttnmapperPacket.nodeAddr, forKey: "nodeaddr")
        data.setValue(ttnmapperPacket.gateway!.gatewayId, forKey: "gwaddr")
        data.setValue(instanceID, forKey: "iid")
        
        data.setValue(ttnmapperPacket.time, forKey: "time")
        data.setValue(ttnmapperPacket.dataRate, forKey: "datarate")
        data.setValue(ttnmapperPacket.snr, forKey: "snr")
        data.setValue(ttnmapperPacket.rssi, forKey: "rssi")
        data.setValue(ttnmapperPacket.frequency, forKey: "freq")
        data.setValue(ttnmapperPacket.location!.coordinate.latitude ,forKey: "lat")
        data.setValue(ttnmapperPacket.location!.coordinate.longitude, forKey: "lon")
        if ttnmapperPacket.location!.altitude != 0 {
            data.setValue(ttnmapperPacket.location!.altitude, forKey: "alt")
        }
        if ttnmapperPacket.location!.horizontalAccuracy != 0 {
            data.setValue(ttnmapperPacket.location!.horizontalAccuracy ,forKey: "accuracy")
        }
        data.setValue("ios", forKey: "provider")
        data.setValue(self.topic, forKey: "mqtt_topic")
        data.setValue(self.userAgent, forKey: "user_agent")
        
        let experimentName = self.experimentName
        if self.isExperimental {
            data.setValue(experimentName, forKey: "experiment")
        }
        
        // JSONify data.
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions())
            let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
            
            // Upload data to ttnmapper.org.
            NSLog("Upload node JSON: " + jsonString)
            postToServer(URL(string: NODE_UPLOAD_URL), jsonString: jsonString)
            
            // Staging supplies the gateways in packet metadata
            // We do not trust experiments to update our gateway table
            if !self.isExperimental {
                
                // Let's parse the gateways.
                // Log the gateways to the server.
                // This is how the mapper learns about new gateways.
                let dataGateway: NSMutableDictionary = NSMutableDictionary()
                dataGateway.setValue(ttnmapperPacket.time, forKey: "time")
                dataGateway.setValue(ttnmapperPacket.gateway!.gatewayId, forKey: "gwaddr")
                dataGateway.setValue(ttnmapperPacket.gateway!.coordinate.latitude, forKey: "lat")
                dataGateway.setValue(ttnmapperPacket.gateway!.coordinate.longitude, forKey: "lon")
                var altitude = 0.0
                if ttnmapperPacket.gateway!.location != nil {
                    altitude = ttnmapperPacket.gateway!.location!.altitude
                }
                dataGateway.setValue(altitude, forKey: "alt")
                dataGateway.setValue(instanceID, forKey: "iid")
                
                // JSONify data
                let jsonDataGateway = try! JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions())
                let jsonGatewayString = NSString(data: jsonDataGateway, encoding: String.Encoding.utf8.rawValue)! as String
                
                NSLog("Upload gateway JSON: " + jsonGatewayString)
                postToServer(URL(string: GATEWAY_UPLOAD_URL), jsonString: jsonGatewayString)
            }
        } catch {
            NSLog("Error JSONifying string")
        }
    }
    
    fileprivate func postToServer(_ url: URL?, jsonString: String) {
        // Create the request & response
        let request = NSMutableURLRequest(url: url!, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.httpBody = jsonString.data(using: String.Encoding.utf8, allowLossyConversion: true)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in

            guard let _ = data, error == nil else {
                print("POST Error -> \(String(describing: error))")
                
                // Monitor on answers
                var message = ""
                if data == nil {
                    message = "Data is nil"
                }
                if let error = error {
                    message = error.localizedDescription
                }
                Answers.logCustomEvent(withName: "Error uploading data to ttnmapper.org", customAttributes: ["status":"Error", "url": url!.absoluteString, "message": message])
                return
            }
            
            // Monitor uploads with answers.
            if let data = data {
                do {
                    // Let's parse the received JSON.
                    let json = try JSONSerialization.jsonObject(with: data, options:[]) as! [String: AnyObject]
                    
                    // Check error and message attributes.
                    var isError = false
                    if let errorAttribute = json["error"] as? Bool {
                        isError = errorAttribute
                    }
                    var errorMessage = "Unknown error"
                    if let errorMessageAttribute = json["error_message"] as? String {
                        errorMessage = errorMessageAttribute
                    }
                    
                    // Push proper analytics call.
                    if isError {
                        Answers.logCustomEvent(withName: "Error uploading data to ttnmapper.org", customAttributes: ["status":"Error", "url": url!.absoluteString, "message": errorMessage])
                    } else {
                        Answers.logCustomEvent(withName: "Succesfully uploaded data to ttnmapper.org", customAttributes: ["status":"Success", "url": url!.absoluteString])
                    }
                } catch {
                    // Push analytics in case of JSON parsing error.
                    NSLog("TTNMapperUploader.Error: Cannot parse JSON response")
                    Answers.logCustomEvent(withName: "Error uploading data to ttnmapper.org", customAttributes: ["status":"Error", "url": url!.absoluteString, "message": "Cannot JSON parse response"])
                }
            }
        })
        
        task.resume()
    }
}

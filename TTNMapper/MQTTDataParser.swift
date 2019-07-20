//
//  TTNMQTTDataParser.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 05/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import CoreLocation

class MQTTDataParser {
    
    fileprivate(set) var ttnbroker : String
    fileprivate(set) var appEUI : String?
    fileprivate(set) var deviceId : String?
    
    init(ttnbroker: String, deviceId: String, appId: String?) {
        self.ttnbroker = ttnbroker
        self.appEUI = appId
        self.deviceId = deviceId
    }
    
    func parseJsonPacket(_ packet: [String : AnyObject]) -> [TTNMapperDatapoint] {
        var ttnmapperPackets = [TTNMapperDatapoint]()
        
        if (ttnbroker == Constants.TTNBROKER_PROD) {
            let parsedPackets = parseProductionJsonPacket(packet)
            
            for parsedPacket in parsedPackets {
                if parsedPacket.isValid() {
                    ttnmapperPackets.append(parsedPacket)
                }
            }
        }
        
        return ttnmapperPackets
    }

    fileprivate func parseProductionJsonPacket(_ packet: [String : AnyObject]) -> [TTNMapperDatapoint] {
    
        /* New format: 
        {
            "port":1,
            "counter":1,
            "payload_raw":"Pw==",
            "metadata":
            {
                "time":"2017-01-06T19:22:48.834531954Z",
                "frequency":867.1,
                "modulation":"LORA",
                "data_rate":"SF7BW125",
                "coding_rate":"4/5",
                "gateways":
                [{
                    "gtw_id":"eui-aa555a000806053f",
                    "timestamp":117541739,
                    "time":"2017-01-06T19:22:48.812439Z",
                    "channel":3,
                    "rssi":-120,
                    "snr":-5.5,
                    "latitude":52.22121,
                    "longitude":6.88569,
                    "altitude":66
                }]
            }
        }
        */
        var ttnmapperPackets = [TTNMapperDatapoint]()
        
        let metadata = packet["metadata"] as? [String: AnyObject]
        if let metadata = metadata {
            let gatewayData = metadata["gateways"] as? [[String: AnyObject]]
            if let gatewayData = gatewayData {
                for gatewayItem in gatewayData {
                    let ttnmapperPacket = TTNMapperDatapoint()
                    ttnmapperPacket.nodeAddr = self.deviceId
                    //TODO Check with JP if the dev_id needs to be parsed in case of a wildcard.
                    let devId = packet["dev_id"] as? String
                    if let devId = devId {
                        ttnmapperPacket.nodeAddr = devId
                    }
                    ttnmapperPacket.appEUI = self.appEUI
                    ttnmapperPacket.time = metadata["time"] as? String
                    ttnmapperPacket.frequency = metadata["frequency"] as? Double
                    ttnmapperPacket.dataRate = metadata["data_rate"] as? String
                    ttnmapperPacket.rssi = gatewayItem["rssi"] as? Double
                    ttnmapperPacket.snr = gatewayItem["snr"] as? Double
                    
                    let gatewayId = gatewayItem["gtw_id"] as? String
                    let gatewayLatitude = gatewayItem["latitude"] as? Double
                    let gatewayLongitude = gatewayItem["longitude"] as? Double
                    var gatewayAltitude = gatewayItem["altitude"] as? Double
                    if gatewayAltitude == nil {
                        gatewayAltitude = 0.0
                    }
                    var gatewayTime = gatewayItem["time"] as? String
                    if gatewayTime == nil {
                        gatewayTime = ""
                    }
                    // Use current local time if no timestamp has been provided by the gateway.
                    if gatewayTime == "" {
                        gatewayTime = Date().iso8601
                    }
                    if gatewayId == nil || gatewayId ==  "" {
                        continue
                    }
                    var gatewayLocation: CLLocation?
                    if gatewayLatitude != nil && gatewayLongitude != nil {
                        let gatewayCoordinates = CLLocationCoordinate2D(latitude: gatewayLatitude!, longitude: gatewayLongitude!)
                        gatewayLocation = CLLocation(coordinate: gatewayCoordinates, altitude: gatewayAltitude! as CLLocationDistance, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
                    }
                    let gateway = TTNMapperGateway(gatewayId: gatewayId!, timestamp: gatewayTime!, location: gatewayLocation)
                    
                    ttnmapperPacket.gateway = gateway
                    ttnmapperPackets.append(ttnmapperPacket)
                }
            }
        }
        return ttnmapperPackets
    }
    
    fileprivate func parseCroftJsonPacket(_ packet: [String : AnyObject]) -> TTNMapperDatapoint {
        
        // Sample JSON:
        // {"gatewayEui":"00FE34FFFFD30DA7",
        // "nodeEui":"02017201",
        // "time":"2016-06-06T01:12:09.101797367Z",
        // "frequency":868.099975,
        // "dataRate":"SF7BW125",
        // "rssi":-46,
        // "snr":9,
        // "rawData":"QAFyAQIAxAABJeu0TLc=",
        // "data":"IQ=="}
        
        let ttnmapperPacket = TTNMapperDatapoint()
        ttnmapperPacket.nodeAddr = packet["nodeEui"] as? String
        ttnmapperPacket.appEUI = self.appEUI
        ttnmapperPacket.time = packet["time"] as? String
        ttnmapperPacket.frequency = packet["frequency"] as? Double
        ttnmapperPacket.dataRate = packet["dataRate"] as? String
        ttnmapperPacket.rssi = packet["rssi"] as? Double
        ttnmapperPacket.snr = packet["snr"] as? Double
        
        let gatewayAddr = packet["gatewayEui"] as? String
        let gateway = TTNMapperGateway(gatewayId: gatewayAddr!, timestamp: ttnmapperPacket.time!, location: CLLocation())
        ttnmapperPacket.gateway = gateway
        
        return ttnmapperPacket
    }
    
    fileprivate func parseStagingJsonPacket(_ packet: [String : AnyObject]) -> [TTNMapperDatapoint] {
        
        // Sample JSON:
        //["dev_eui": 0000000002017202, "metadata": (
        //{
        //    altitude = 0;
        //    channel = 0;
        //    codingrate = "4/5";
        //    crc = 1;
        //    datarate = SF7BW125;
        //    frequency = "868.1";
        //    "gateway_eui" = 00FE34FFFFD30DA7;
        //    "gateway_timestamp" = 2591438720;
        //    latitude = 0;
        //    longitude = 0;
        //    lsnr = 9;
        //    modulation = LORA;
        //    rfchain = 0;
        //    rssi = "-50";
        //    "server_time" = "2016-06-15T14:12:49.351337424Z";
        //}
        //), "payload": IQ==, "counter": 14729, "port": 1]
        
        var ttnmapperPackets = [TTNMapperDatapoint]()
        
        let nodeAddr = packet["dev_eui"] as? String
        let metadata = packet["metadata"]! as! [[String: AnyObject]]
        
        for item in metadata {
            let ttnmapperPacket = TTNMapperDatapoint()
            ttnmapperPacket.nodeAddr = nodeAddr
            ttnmapperPacket.appEUI = self.appEUI
            ttnmapperPacket.time = item["server_time"] as? String
            ttnmapperPacket.frequency = item["frequency"] as? Double
            ttnmapperPacket.dataRate = item["datarate"] as? String
            ttnmapperPacket.rssi = item["rssi"] as? Double
            ttnmapperPacket.snr = item["lsnr"] as? Double
            
            // Store gateway information.
            let gatewayId = item["gateway_eui"] as? String
            let gatewayLatitude = item["latitude"] as? Double
            let gatewayLongitude = item["longitude"] as? Double
            let gatewayAltitude = item["altitude"] as? Double
            let gatewayCoordinates = CLLocationCoordinate2D(latitude: gatewayLatitude!, longitude: gatewayLongitude!)
            let gatewayLocation = CLLocation(coordinate: gatewayCoordinates, altitude: gatewayAltitude! as CLLocationDistance, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
            let gateway = TTNMapperGateway(gatewayId: gatewayId!, timestamp: ttnmapperPacket.time!, location: gatewayLocation)
            ttnmapperPacket.gateway = gateway
            
            ttnmapperPackets.append(ttnmapperPacket)
        }
        
        return ttnmapperPackets
    }
}

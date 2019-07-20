//
//  MQTTDataparserTests.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 21/01/2017.
//  Copyright © 2017 Timothy Sealy. All rights reserved.
//

import Foundation
import XCTest
@testable import TTNMapper

class MQTTDataParserTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testCorrectProductionDataParsing(){
        let string = "{\"port\":1,\"counter\":1,\"payload_raw\":\"Pw==\",\"metadata\":{\"time\":\"2017-01-06T19:22:48.834531954Z\",\"frequency\":867.1,\"modulation\":\"LORA\",\"data_rate\":\"SF7BW125\",\"coding_rate\":\"4/5\",\"gateways\":[{\"gtw_id\":\"eui-aa555a000806053f\",\"timestamp\":117541739,\"time\":\"2017-01-06T19:22:48.812439Z\",\"channel\":3,\"rssi\":-120,\"snr\":-5.5,\"latitude\":52.22121,\"longitude\":6.88569,\"altitude\":66}]}}"
        if let data = string.data(using: String.Encoding.utf8) {
            do {
                let err : NSErrorPointer = nil
                let parsedObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as? Dictionary<String, AnyObject>
            
                if let parsedObject = parsedObject {
                    // Check whether we have a valid JSON.
                    let valid = JSONSerialization.isValidJSONObject(parsedObject)
                    XCTAssertTrue(valid,"Not a valid JSON")
                    
                    // Test our parser.
                    let parser = MQTTDataParser(ttnbroker: Constants.TTNBROKER_PROD, deviceId: "dev_id",appId: "app_id")
                    let ttnmapperPackets = parser.parseJsonPacket(parsedObject)
                    XCTAssertEqual(ttnmapperPackets.count, 1, "Did not parse correct amount of ttnmapper packets")
                } else {
                    if (err != nil) {
                        NSLog("Error: \(String(describing: err))")
                    }
                    else {
                        NSLog("Error: unexpected error parsing json string")
                    }
                }
            } catch {
                NSLog("Exception")
            }
        }
    }
    
    func testIncorrectProductionDataParsing(){
//        let string = "{\"port\":1,\"counter\":1,\"payload_raw\":\"Pw==\",\"metadata\":{\"time\":\"2017-01-06T19:22:48.834531954Z\",\"frequency\":867.1,\"modulation\":\"LORA\",\"data_rate\":\"SF7BW125\",\"coding_rate\":\"4/5\",\"gateways\":[{\"gtw_id\":\"eui-aa555a000806053f\",\"timestamp\":117541739,\"time\":\"2017-01-06T19:22:48.812439Z\",\"channel\":3,\"rssi\":-120,\"snr\":-5.5,\"latitude\":0.0,\"longitude\":0.0,\"altitude\":0}]}}"
        let string = "{\"port\":1,\"counter\":1,\"payload_raw\":\"Pw==\",\"metadata\":{\"time\":\"2017-01-06T19:22:48.834531954Z\",\"frequency\":867.1,\"modulation\":\"LORA\",\"data_rate\":\"SF7BW125\",\"coding_rate\":\"4/5\"}}"
        
        if let data = string.data(using: String.Encoding.utf8) {
            do {
                let err : NSErrorPointer = nil
                let parsedObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as? Dictionary<String, AnyObject>
                
                if let parsedObject = parsedObject {
                    // Check whether we have a valid JSON.
                    let valid = JSONSerialization.isValidJSONObject(parsedObject)
                    XCTAssertTrue(valid,"Not a valid JSON")
                    
                    // Test our parser.
                    let parser = MQTTDataParser(ttnbroker: Constants.TTNBROKER_PROD, deviceId: "dev_id",appId: "app_id")
                    let ttnmapperPackets = parser.parseJsonPacket(parsedObject)
                    XCTAssertEqual(ttnmapperPackets.count, 0, "Did not parse correct amount of ttnmapper packets")
                } else {
                    if (err != nil) {
                        NSLog("Error: \(String(describing: err))")
                    }
                    else {
                        NSLog("Error: unexpected error parsing json string")
                    }
                }
            } catch {
                NSLog("Exception")
            }
        }
    }

    
    func testIncorrectProductionDataParsingErik(){
        let string = "{\"metadata\":{\"time\": \"2017-01-21T19:06:33.845854305Z\",\"frequency\": 868.1,\"modulation\": \"LORA\",\"data_rate\": \"SF7BW125\",\"coding_rate\": \"4/5\",\"gateways\": [{\"gtw_id\": \"eui-5ccf7ff42f0674fb\",\"timestamp\": 654199487,\"time\": \"2017-01-21T19:06:33.752357Z\",\"channel\": 0,\"rssi\": -61,\"snr\": 9,\"latitude\": 51.94032,\"longitude\": 5.90311}]}}"
        
        if let data = string.data(using: String.Encoding.utf8) {
            do {
                let err : NSErrorPointer = nil
                let parsedObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableLeaves) as? Dictionary<String, AnyObject>
                
                if let parsedObject = parsedObject {
                    // Check whether we have a valid JSON.
                    let valid = JSONSerialization.isValidJSONObject(parsedObject)
                    XCTAssertTrue(valid,"Not a valid JSON")
                    
                    // Test our parser.
                    let parser = MQTTDataParser(ttnbroker: Constants.TTNBROKER_PROD, deviceId: "dev_id",appId: "app_id")
                    let ttnmapperPackets = parser.parseJsonPacket(parsedObject)
                    XCTAssertEqual(ttnmapperPackets.count, 1, "Did not parse correct amount of ttnmapper packets")
                } else {
                    if (err != nil) {
                        NSLog("Error: \(String(describing: err))")
                    }
                    else {
                        NSLog("Error: unexpected error parsing json string")
                    }
                }
            } catch {
                NSLog("Exception")
            }
        }
    }

    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

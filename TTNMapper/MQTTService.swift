//
//  MQTTService.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 13/06/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import MQTTClient

protocol MQTTServiceDelegate {
    func connected(_ mapperSession: TTNMapperSession)
    func disconnected(_ reason: DisconnectReason)
    func reconnecting(_ sessionReconnect: Int)
}

enum DisconnectReason : String {
    case connectionRefused = "Connection refused"
    case connectionClosed = "Connection closed"
    case connectionError = "Connection error"
    case connectionClosedByBroker = "Connection closed by broker"
}

class MQTTService : NSObject, MQTTSessionDelegate {
    
    private let syncQueue = DispatchQueue(label: "org.ttnmapper.sessionqueue")
    var delegate: MQTTServiceDelegate?
    
    var mapperSession: TTNMapperSession?
    var conf = TTNMapperConfiguration()
    var continuePreviousSession = false
    
    var ttnbroker: String = Constants.TTNBROKER_NONE
    var topic: String?
    var session: MQTTSession?
    var sessionConnected = false
    var sessionRefuseError = false
    var sessionError = false
    var sessionSubAcked = false
    var sessionShouldReconnect = false
    var sessionReconnecting = false
    var sessionReconnect = 10
    final var sessionMaxReconnect = 10
    fileprivate var timer = Foundation.Timer()
    
    init(configuration: TTNMapperConfiguration) {
        self.conf = configuration;
    }

    // MARK: - MQTTService methods
    
    /*
     * Updates the configuration of the MQTT service.
     * Note: We will (re)connect with a new session to the TTN backend using the new configuration.
     */
    func updateConfiguration(_ configuration: TTNMapperConfiguration) {
        
        // Update configuration.
        self.conf = configuration
        
        if sessionConnected {
            // Disconnect service if connected.
            mqttDisconnect()
            
            // Connect to TTN backend.
            mqttConnect(nil)
        }
    }

    func mqttConnect(_ continueSession: TTNMapperSession?) {
        // Check if we should continue previous session
        if let continueSession = continueSession {
            continuePreviousSession = true
            mapperSession = continueSession
        } else {
            mapperSession = nil
        }
        
        // Load configuration here (so we have the latest version).
        ttnbroker = conf.ttnbroker
        topic = conf.topic

        // Let's startup a session
        session = MQTTSession()
        session!.delegate = self
        session!.keepAliveInterval = 60
        session!.clientId = UUID().uuidString
        
        // Check whether authentication is required
        if conf.authenticationRequired {
            session!.userName = conf.username
            session!.password = conf.password
        }
        
        // Connect
        let transport = MQTTCFSocketTransport()
        transport.host = conf.ttnbrokerurl
        transport.port = UInt32(conf.ttnbrokerport)
        session!.transport = transport
        session!.connect()
    }

    func mqttDisconnect() {
        timer.invalidate()
        
        // We should close the connection if we are connected.
        if sessionConnected {
            // We should unsubscribe if we have an active subscription.
            if sessionSubAcked {
                session?.unsubscribeTopic(topic)
            }
            session?.close()
        }
        
        // Reset flags.
        sessionConnected = false
        sessionError = false
        sessionSubAcked = false
        sessionReconnecting = false
        sessionReconnect = sessionMaxReconnect
    }
    
    @objc fileprivate func mqttReconnect() {

        if sessionReconnect > 0 {
            session?.close()
            sessionConnected = false
            sessionError = false
            sessionSubAcked = false
            sessionReconnect -= 1
            
            mqttConnect(mapperSession)
            
            self.delegate?.reconnecting(sessionReconnect)
        } else {
            timer.invalidate()
        }
    }
    
    // MARK: - MQTTSessionDelegate protocol methods
    
    func handleEvent(_ session: MQTTSession!, event eventCode: MQTTSessionEvent, error: Error!) {
        
        // Parse mqtt session event to disconnect reason.
        var disconnectReason: DisconnectReason = .connectionError
        
        switch eventCode {
        case .connected:
            NSLog("TTNSession handle event: connected")
            sessionConnected = true
            sessionReconnecting = false
            sessionReconnect = sessionMaxReconnect
            // Stop timer if we have connected via a reconnect.
            timer.invalidate()
            if !sessionSubAcked {
                // Subscribe
                session!.subscribe(toTopic: topic, at: .atMostOnce)
            }
        case .connectionRefused:
            NSLog("TTNSession handle event: conenction refused")
            disconnectReason = .connectionRefused
            sessionConnected = false
            sessionRefuseError = true
        case .connectionClosed:
            NSLog("TTNSession handle event: connection closed")
            disconnectReason = .connectionClosed
            // After a connection refused this event is raised
            // (suppressing the connection refused error *sigh* )
            if sessionRefuseError {
                disconnectReason = .connectionRefused
                sessionRefuseError = false
            }
            sessionConnected = false
            // If connection was closed by error then we should try to reconnect.
            if sessionShouldReconnect {
                sessionReconnecting = true
            }
        case .connectionClosedByBroker:
            NSLog("TTNSession handle event: connection closed by broker")
            disconnectReason = .connectionClosedByBroker
            sessionConnected = false
        case .connectionError:
            NSLog("TTNSession handle event: connection error")
            if !sessionReconnecting {
                sessionShouldReconnect = true
            }
            sessionConnected = false
            sessionError = true
        default:
            NSLog("TTNSession handle event... (default)")
            if !sessionReconnecting {
                sessionShouldReconnect = true
            }
            sessionConnected = false
            sessionError = true
        }
        
        if sessionReconnecting && sessionShouldReconnect {
            // Schedule reconnect
            sessionShouldReconnect = false
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.mqttReconnect), userInfo: nil, repeats: true)
        }

        // Stop reconnecting when max reconnect has been reached.
        if sessionReconnecting && sessionReconnect <= 0 {
            timer.invalidate()
            sessionReconnecting = false
            sessionReconnect = sessionMaxReconnect
        }
        
        // Notify of disconnect
        if !sessionConnected && !sessionReconnecting && !sessionShouldReconnect {
            if let mapperSession = mapperSession {
                mapperSession.status = .stopped
            }
            self.delegate?.disconnected(disconnectReason)
        }
    }

    
    func subAckReceived(_ session: MQTTSession!, msgID: UInt16, grantedQoss qoss: [NSNumber]!) {
        NSLog("TTNSession subscribed to \(String(describing: self.topic))")
        sessionSubAcked = true
        
        // TODO: convert all strings to enum.
        var broker : TTNBroker
        if ttnbroker == Constants.TTNBROKER_STAGING {
            broker = .Staging
        } else if ttnbroker == Constants.TTNBROKER_PROD {
            broker = .Production
        } else {
            broker = .None
        }
        
        if continuePreviousSession {
            mapperSession?.status = .started
            continuePreviousSession = false
        } else {
            mapperSession = TTNMapperSession(ttnbroker: broker)
        }
        
        // Gaurd on nil delegates/session
        var shouldDisconnect = false
        syncQueue.sync {
            if let mapperSession = self.mapperSession,
                let self_delegate = self.delegate {
                self_delegate.connected(mapperSession)
            } else {
                shouldDisconnect = true
            }
        }
        // Disconnect is outside sync block because it could lead to succeful reconnect
        // which will result in a subAck leading to a deadlock.
        if shouldDisconnect {
            mqttDisconnect()
        }
        
    }
    
    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        
        // Let's parse the received JSON into strong typed ttnmapperPackets.
        do {
            let json = try JSONSerialization.jsonObject(with: data, options:[]) as! [String: AnyObject]
            let parser = MQTTDataParser(ttnbroker: ttnbroker, deviceId: conf.deviceEUI, appId: conf.appEUI)
            let datapoints = parser.parseJsonPacket(json)

            // Add datapoints to mapper session.
            mapperSession?.addDataPoints(datapoints)
        } catch {
            NSLog("MQTTService.Error: Cannor parse JSON")
        }
    }
    
}

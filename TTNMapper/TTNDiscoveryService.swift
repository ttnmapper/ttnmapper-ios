//
//  TTNDiscoveryService.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 30/08/2017.
//  Copyright © 2017 Timothy Sealy. All rights reserved.
//

import Foundation


class TTNDiscoveryService : NSObject, URLSessionDelegate {
    
    fileprivate let TTN_DISCOVERY_URL = "http://discovery.thethingsnetwork.org:8080/announcements/handler"
    fileprivate var appsToHandlers = [String: TTNHandler]()
    
    // Singleton
    static let sharedInstance = TTNDiscoveryService()
    fileprivate override init() {
        super.init()
    }
    
    
    func getHandler(appId: String) -> TTNHandler? {
        if let handler = appsToHandlers[appId] {
            return handler
        }
        return nil
    }
    
    func getHandlerById(handler: String) -> TTNHandler? {
        //TODO: optimise by storing data in seperate array.
        for storedHandler in appsToHandlers.values {
            print("Handler id: \(storedHandler.id)")
            if storedHandler.id == handler {
                return storedHandler
            }
        }
        return nil
    }
    
    func queryHandlers() {
        let _ = load(url: NSURL(string: TTN_DISCOVERY_URL)! as URL, completion: { (data, response, error) -> Void in
            // Parse data if any.
            if let discoveryData = data {
                self.parseHandlers(data: discoveryData)
            }
        })

    }
    
    /**
     * Load the data from URL (first attempt from network otherwise from cache)
     */
    func load(url: URL, completion: @escaping (Data?, Error?, Error?) -> ()) {
        
        let networkSession = session(withPolicy: .reloadIgnoringLocalCacheData)
        let localSession = session(withPolicy: .returnCacheDataDontLoad)
        
        networkSession.dataTask(with: url) { (networkData, networkResponse, networkError) in
            
            guard networkError == nil else {
                localSession.dataTask(with: url) { (cacheData, cacheResponse, cacheError) in
                    completion(cacheData, networkError, cacheError)
                    }.resume()
                return
            }
            completion(networkData, nil, nil)
            }.resume()
    }
    
    func session(withPolicy policy:NSURLRequest.CachePolicy, timeout: TimeInterval = 5)-> URLSession {
        // Default configuration
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = policy
        config.timeoutIntervalForRequest = 60
        
        // Enable url cache in session configuration and assign capacity (Mem: 4mb, diskL 40mb)
        config.urlCache = URLCache.shared
        config.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 40 * 1024 * 1024, diskPath: "offline-cache")
        
        return URLSession(configuration: config)
    }

    
    private func parseHandlers(data: Data?) {
        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            if let jsonObject = json as? [String: Any] {
                if let jsonArray = jsonObject["services"] as? [[String: Any]] {
                    // Clear dictioniary
                    self.appsToHandlers.removeAll()
                    // Parse JSON
                    for handlerJson in jsonArray {
                        if  let id = handlerJson["id"],
                            let apiAddress = handlerJson["api_address"],
                            let netAddress = handlerJson["net_address"],
                            let mqttAddress = handlerJson["mqtt_address"] {
                            
                            let handler = TTNHandler(id: id as! String, apiAddress: apiAddress as! String, netAddress: netAddress as! String, mqttAddress: mqttAddress as! String)
                            
                            if let appsArray = handlerJson["metadata"] as? [[String: Any]] {
                                for appJson in appsArray {
                                    if let appId = appJson["app_id"] {
                                        self.appsToHandlers[appId as! String] = handler
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: URLDelegateSession methods.
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // We've got a URLAuthenticationChallenge - we simply trust the HTTPS server and we proceed
        NSLog("urlSession.didReceive challenge")
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // We've got an error
        if let err = error {
            NSLog("urlSession.Error: \(err.localizedDescription)")
        } else {
            NSLog("urlSession.Error. Giving up")
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        NSLog("Discovery didFinishEvents")
    }
}

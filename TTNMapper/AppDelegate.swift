//
//  AppDelegate.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 12/06/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Prevent phone from going to sleep.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Crash reporting stuff
        Fabric.with([Crashlytics.self])
        
        // Get handlers from the TTN discovery service.
        TTNDiscoveryService.sharedInstance.queryHandlers()
        
        return true
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    
        // Check if we have a proper url
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                Answers.logCustomEvent(withName: "Universal link", customAttributes: ["status":"Error (invalid url)"])
                return false
        }

        var parameters = "none"
        var universalLinkError = true
        var deepLinkConf: TTNMapperConfiguration?
        
        if url.path == "/" {
            universalLinkError = false
            
            // If we have some parameters. Let's parse them and see if they are valid.
            if  let appid = components.queryItems?.first(where: { $0.name == "appid" })?.value,
                let accesskey = components.queryItems?.first(where: { $0.name == "accesskey" })?.value {
                parameters = "appid"
            
                // Update configuration
                let conf = TTNMapperConfiguration()
                conf.appEUI = appid
                conf.username = appid
                conf.password = accesskey
                conf.ttnbroker = Constants.TTNBROKER_PROD
                conf.deviceEUI = "+"
                if let devid = components.queryItems?.first(where: { $0.name == "devid" })?.value {
                    parameters = "appid and devid"
                    conf.deviceEUI = devid
                }
                
                var mqtthandler: String?
                if let handler = TTNDiscoveryService.sharedInstance.getHandler(appId: appid) {
                    mqtthandler = handler.mqttAddress
                }
                if let handler = components.queryItems?.first(where: { $0.name == "handler" })?.value {
                    if let discoveredHandler = TTNDiscoveryService.sharedInstance.getHandlerById(handler: handler) {
                        mqtthandler = discoveredHandler.mqttAddress
                    }
                }
                
                if mqtthandler != nil {
                    conf.ttnbrokerport = 1883   // default mqqt port.
                    conf.ttnbrokerRegion = mqtthandler!
                    let handlerUrlComponents = mqtthandler!.components(separatedBy: ":")
                    if handlerUrlComponents.count == 2 {
                        if let ttnbrokerport = Int(handlerUrlComponents[1]){
                            conf.ttnbrokerport = ttnbrokerport
                            conf.ttnbrokerRegion = handlerUrlComponents[0]
                        }
                    }
                }
                // Set deeplink conf
                deepLinkConf = conf
            }
        }
        
        // Find navigation controller.
        if let window = self.window, let rootViewController = window.rootViewController as? UINavigationController {

            // Remove all view controllers (except the first one which should be our live map VC.
            rootViewController.popToRootViewController(animated: false)
            let liveMapController =  rootViewController.topViewController as? LiveMapViewController
            liveMapController!.restartRequired = false
            liveMapController!.universalLinkError = universalLinkError
            
            // Create an instance of the settings view controller and push it on the navigation stack.
            if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController {
                controller.delegate = liveMapController
                controller.deeplinked = true
                controller.deepLinkConf = deepLinkConf
                rootViewController.pushViewController(controller, animated: true)
            }
        }
        
        Answers.logCustomEvent(withName: "Universal link", customAttributes: ["status":"Success", "Parameters": parameters])
        
        return true
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Answers.logCustomEvent(withName: "Memory warning")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}


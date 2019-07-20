//
//  BaseMapViewController.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 10/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit
import MapKit

extension MKPolyline {
    fileprivate struct AssociatedKeys {
        static var DescriptiveName = "nsh_DescriptiveName"
    }
    
    var lineColor: UIColor? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.DescriptiveName) as? UIColor
        }
        
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.DescriptiveName,
                    newValue as UIColor?,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }
}

extension MKAnnotationView {
    
    /*
     * Create a custom view which displays mulitple lines.
     */
    func loadCustomLines(customLines: [String]) {
        let stackView = self.stackView()
        for line in customLines {
            let label = UILabel()
            label.text = line
            label.font = label.font.withSize(14)
            stackView.addArrangedSubview(label)
        }
        self.detailCalloutAccessoryView = stackView
    }
    
    private func stackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        return stackView
    }
}

// TODO: Implement TTNMapperSessionDelegate methods. 
// Make them abstract so the inhereting classes can implement them.

class BaseMapViewController: UIViewController, MKMapViewDelegate {

    var ttnmapperSession : TTNMapperSession?
    var tileOverlay: MyTileOverlay?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create overlay with URL template to the map tiles
        let urlTemplate = "http://ttnmapper.org/tms/?tile={z}/{x}/{y}"
        tileOverlay = MyTileOverlay(urlTemplate:urlTemplate)
        tileOverlay!.canReplaceMapContent = false
        tileOverlay!.alpha = 0.5
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Map annotation methods
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if (overlay is MKPolyline) {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = (overlay as! MKPolyline).lineColor
            polylineRenderer.lineWidth = 2
            return polylineRenderer
        } else if overlay is MKTileOverlay {
            let renderer = MKTileOverlayRenderer(overlay:overlay)
            //Set the renderer alpha to be overlay alpha
            renderer.alpha = (overlay as! MyTileOverlay).alpha
            return renderer
        }
        NSLog("View for overlay - nil")
        
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? TTNMapperGateway {
            // Create different identifier for gateways
            let identifier = Util.gatewayMarkerType()
            return creatAnnotationView(mapView, viewForAnnotation: annotation, identifier: identifier)
        }
        
        if let annotation = annotation as? TTNMapperDatapoint {
            // Create different identifiers for colored markers
            let identifier = Util.parseMarkerType(annotation)
            let anView = creatAnnotationView(mapView, viewForAnnotation: annotation, identifier: identifier)
            
            // Draw line to gateway
            let gatewayLocation = annotation.gateway?.location
            if let gatewayLocation = gatewayLocation {
                drawNodeGatewayLine(mapView, nodeLocation:annotation.coordinate, gatewayLocation: gatewayLocation.coordinate, rssi: annotation.rssi!)
            }
            return anView
        }
        return nil
    }
    
    private func creatAnnotationView(_ mapView: MKMapView, viewForAnnotation annotation: MKAnnotation, identifier: String) -> MKAnnotationView? {
        
        var anView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        if anView == nil {
            anView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            anView!.image = UIImage(named:identifier)
            anView!.canShowCallout = true
            if let _annotation = annotation as? TTNMapperDatapoint {
                anView!.loadCustomLines(customLines: _annotation.lines)
            }
        } else {
            anView!.annotation = annotation
        }
        return anView
    }
    
    func drawNodeGatewayLine(_ mapView: MKMapView, nodeLocation: CLLocationCoordinate2D, gatewayLocation:CLLocationCoordinate2D, rssi: Double) {
        
        // Draw a line to gateway
        var points: [CLLocationCoordinate2D] = [CLLocationCoordinate2D]()
        points.append(nodeLocation)
        points.append(gatewayLocation)
        let polyline = MKPolyline(coordinates: &points, count: points.count)
        polyline.lineColor = Util.gettColorForRssi(rssi)
        mapView.addOverlay(polyline)
    }

    
    class MyTileOverlay : MKTileOverlay {
        var alpha: CGFloat = 1.0
        let cache = NSCache<AnyObject, AnyObject>()
        
        override func url(forTilePath path: MKTileOverlayPath) -> URL {
            return URL(string: String(format: "http://ttnmapper.org/tms/?tile=%d/%d/%d", path.z, path.x, path.y))!
        }
        
        override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
            let url = self.url(forTilePath: path)
            if let cachedData = cache.object(forKey: url as AnyObject) as? Data {
                result(cachedData, nil)
            } else {
                
                // create the request & response
                let request = NSMutableURLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: 5)
                request.httpMethod = "GET"

                let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
                    
                    guard let _ = data, error == nil else {
                        print("TILE Error -> \(String(describing: error))")
                        return
                    }
                    if let data = data {
                        self.cache.setObject(data as AnyObject, forKey: url as AnyObject)
                    }
                    result(data, error)
                })
 
                task.resume()
 
            }
        }
    }
}

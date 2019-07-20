//
//  qrScannerViewController.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 16/06/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit
import AVFoundation

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var objCaptureSession:AVCaptureSession?
    var objCaptureVideoPreviewLayer:AVCaptureVideoPreviewLayer?
    var vwQRCode:UIView?
    
    weak var delegate: SettingsViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Scan Configuration QR"
        
        self.configureVideoCapture()
        self.addVideoPreviewLayer()
        self.initializeQRView()
    }
    
    // QR code scanning
    func configureVideoCapture() {
        let objCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        var error:NSError?
        let objCaptureDeviceInput: AnyObject!
        do {
            objCaptureDeviceInput = try AVCaptureDeviceInput(device: objCaptureDevice!) as AVCaptureDeviceInput
            
        } catch let error1 as NSError {
            error = error1
            objCaptureDeviceInput = nil
        }
        if (error != nil) {
            let alert : UIAlertController = UIAlertController(title: "Device Error", message:"Device not Supported for this Application", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Click", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        objCaptureSession = AVCaptureSession()
        objCaptureSession?.addInput(objCaptureDeviceInput as! AVCaptureInput)
        let objCaptureMetadataOutput = AVCaptureMetadataOutput()
        objCaptureSession?.addOutput(objCaptureMetadataOutput)
        objCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        objCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    }
    
    func addVideoPreviewLayer() {
        objCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: objCaptureSession!)
        objCaptureVideoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        objCaptureVideoPreviewLayer?.frame = view.layer.bounds
        self.view.layer.addSublayer(objCaptureVideoPreviewLayer!)
        objCaptureSession?.startRunning()
    }
    
    func initializeQRView() {
        vwQRCode = UIView()
        vwQRCode?.layer.borderColor = UIColor.red.cgColor
        vwQRCode?.layer.borderWidth = 5
        self.view.addSubview(vwQRCode!)
        self.view.bringSubviewToFront(vwQRCode!)
    }
    
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count == 0 {
            vwQRCode?.frame = CGRect.zero
            return
        }
        let objMetadataMachineReadableCodeObject = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if objMetadataMachineReadableCodeObject.type == AVMetadataObject.ObjectType.qr {
            let objBarCode = objCaptureVideoPreviewLayer?.transformedMetadataObject(for: objMetadataMachineReadableCodeObject as AVMetadataMachineReadableCodeObject) as! AVMetadataMachineReadableCodeObject
            vwQRCode?.frame = objBarCode.bounds;
            if objMetadataMachineReadableCodeObject.stringValue != nil {
                // Do stuff here.
                let qrCapture = objMetadataMachineReadableCodeObject.stringValue?.components(separatedBy: ":")
                
                if qrCapture?.count == 4 {
                    let handlerRegion = qrCapture![0]
                    let appEUITextField = qrCapture![1]
                    let nodeAddressTextField = qrCapture![2]
                    let appAccessKeyField  = qrCapture![3]
                    
                    // Set text
                    delegate.handlerRegionTextView.text = handlerRegion
                    delegate.appEUITextView.text = appEUITextField
                    delegate.devEUITextView.text = nodeAddressTextField
                    delegate.accessKeyTextView.text = appAccessKeyField
                    delegate.qrScanned = true
                    
                    // Clean up the QR code scanning layer and views/
                    objCaptureSession?.stopRunning()
                    self.view.sendSubviewToBack(vwQRCode!)
                    vwQRCode?.removeFromSuperview()
                    objCaptureVideoPreviewLayer?.removeFromSuperlayer()
                    
                    // Let's go back to settings
                    let navigationController = self.parent as! UINavigationController
                    navigationController.popToViewController(delegate, animated: true)
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

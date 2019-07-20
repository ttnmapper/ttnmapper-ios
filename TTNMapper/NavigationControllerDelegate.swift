//
//  NavigationControllerDelegate.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 25/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation
import UIKit

class NavigationControllerDelegate: NSObject, UINavigationControllerDelegate {
    
    fileprivate let animator = FlipAnimator()
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
       
        return animator
    }
    
}

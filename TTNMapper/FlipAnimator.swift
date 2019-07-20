//
//  FlipAnimator.swift
//  
//
//  Created by Timothy Sealy on 25/07/16.
//
//

import UIKit

class FlipAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
        
        containerView.addSubview(toVC!.view)
        
        // Do color transitions.
        if let mapVC = toVC as? LiveMapViewController,
            let navC = mapVC.navigationController {
            
            // Change color and tint color of the navigation bar
            navC.navigationBar.barStyle = UIBarStyle.default
            navC.navigationBar.tintColor = mapVC.view.tintColor
            
            // Reset color of the status bar.
            UIApplication.shared.statusBarStyle = UIStatusBarStyle.default
        }
        
        if let sessionsVC = toVC as? SessionsTableViewController,
            let navC = sessionsVC.navigationController {
            
            // Change color and tint color of the navigation bar
            navC.navigationBar.barStyle = UIBarStyle.black
            navC.navigationBar.tintColor = UIColor.white
            
            // Reset color of the status bar.
            UIApplication.shared.statusBarStyle = UIStatusBarStyle.lightContent
        }
        
        // Do animations.
        if let mapVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) as? LiveMapViewController,
        let sessionsVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) as? SessionsTableViewController {
            
            // Push: from live map to sessions.
            let duration = transitionDuration(using: transitionContext)
            UIView.transition(from: mapVC.view, to: sessionsVC.view, duration: duration, options: UIView.AnimationOptions.transitionFlipFromLeft, completion: { finished in
                    let cancelled = transitionContext.transitionWasCancelled
                    transitionContext.completeTransition(!cancelled)
            })
        } else if let sessionsVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from) as? SessionsTableViewController,
            let mapVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) as? LiveMapViewController {
               
                // Pop: from sessions to live map
                let duration = transitionDuration(using: transitionContext)
                UIView.animate(withDuration: duration, animations: {
                    }, completion: { finished in
                        UIView.transition(from: sessionsVC.view, to: mapVC.view, duration: duration, options: UIView.AnimationOptions.transitionFlipFromLeft, completion: nil)
                        let cancelled = transitionContext.transitionWasCancelled
                        transitionContext.completeTransition(!cancelled)
                })
        } else {
            let cancelled = transitionContext.transitionWasCancelled
            transitionContext.completeTransition(!cancelled)
        }
    }
}

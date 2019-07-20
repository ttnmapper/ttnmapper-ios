//
//  MulticastDelegate.swift
//  TTNMapper
//
//  Source: http://www.gregread.com/2016/02/23/multicast-delegates-in-swift/
//
//  Created by Timothy Sealy on 06/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation

class MulticastDelegate <T> {
    fileprivate var weakDelegates = [WeakWrapper]()
    
    func addDelegate(_ delegate: T) {
        // If delegate is a class, add it to our weak reference array
        weakDelegates.append(WeakWrapper(value: delegate as AnyObject))
    }
    
    func removeDelegate(_ delegate: T) {
        // If delegate is an object, let's loop through weakDelegates to
        // find it.  We
        for (index, delegateInArray) in weakDelegates.enumerated().reversed() {
            // If we have a match, remove the delegate from our array
            if delegateInArray.value === (delegate as AnyObject) {
                weakDelegates.remove(at: index)
            }
        }
    }
    
    func removeAllDelegates() {
        for (index, _) in weakDelegates.enumerated().reversed() {
            weakDelegates.remove(at: index)
        }
    }
    
    func invoke(_ invocation: (T) -> ()) {
        // Enumerating in reverse order prevents a race condition from happening when removing elements.
        for (index, delegate) in weakDelegates.enumerated().reversed() {
            // Since these are weak references, "value" may be nil
            // at some point when ARC is 0 for the object.
            if let delegate = delegate.value {
                invocation(delegate as! T)
            }
                // Else, ARC killed it, get rid of the element from our
                // array
            else {
                weakDelegates.remove(at: index)
            }
        }
    }
}

func += <T: AnyObject> (left: MulticastDelegate<T>, right: T) {
    left.addDelegate(right)
}

func -= <T: AnyObject> (left: MulticastDelegate<T>, right: T) {
    left.removeDelegate(right)
}

private class WeakWrapper {
    weak var value: AnyObject?
    
    init(value: AnyObject) {
        self.value = value
    }
}

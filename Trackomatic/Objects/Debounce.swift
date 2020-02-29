//
//  Debounce.swift
//  Trackomatic
//
//  Created by Tom Cowland on 29/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Foundation

class Debounce: NSObject
{
    var delay : Double;
    
    var selector: Selector;
    var object: NSObject;
    
    weak var timer: Timer?

    init( delay: Double, object: NSObject, selector: Selector )
    {
        self.object = object;
        self.selector = selector;
        self.delay = delay
    }

    func call()
    {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: delay,
            target: self.object, selector: self.selector,
            userInfo: nil, repeats: false
        );
    }
}

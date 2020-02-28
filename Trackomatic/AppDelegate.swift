//
//  AppDelegate.swift
//  Trackomatic
//
//  Created by Tom Cowland on 24/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        initPrefs();
    }

    // MARK: - Prefs
    
    private func initPrefs()
    {
        let shortName = NSUserName();
        let displayName = NSFullUserName();
        
        UserDefaults.standard.register( defaults: [ "shortName" : shortName, "displayName" : displayName ] );
    }

}


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

    override init()
    {
        super.init();
        initPrefs();
    }
    
    func applicationDidFinishLaunching(_ notification: Notification)
    {
        openFolder( self );
    }
    
    // MARK: - Open
    
    @IBAction func openFolder(_ sender: Any)
    {
        let openPanel = NSOpenPanel();
        openPanel.canChooseFiles = false;
        openPanel.canChooseDirectories = true;
        openPanel.allowsMultipleSelection = false;
        
        openPanel.begin { ( result ) in

            if result == .OK
            {
                if let url = openPanel.url
                {
                    NSDocumentController.shared.noteNewRecentDocumentURL( url );
                    self.newWindow( directory: url );
                }
            }
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL])
    {
        for url in urls
        {
            do {
                let info = try url.resourceValues(forKeys: [ .isDirectoryKey ] );
                if (info.isDirectory ?? false)
                {
                    newWindow( directory: url );
                }
            }
            catch {
                print( error );
            };
        }
    }
    
    func newWindow( directory: URL )
    {
        if let w = NSStoryboard.main?.instantiateController(withIdentifier: "trackomaticWindow" ) as? NSWindowController
        {
            w.showWindow( self );
            w.window?.makeKeyAndOrderFront( self );
            
            if let vc = w.contentViewController as? ViewController
            {
                vc.loadFromDirectory(dir: directory );
            }
        }
    }
    
    // MARK: - Prefs
    
    private func initPrefs()
    {
        UserDefaults.standard.register( defaults: [
            "shortName" : NSUserName(),
            "displayName" : NSFullUserName(),
            "chatEnabled" : false,
            "chatURL" : "https://chatomatic.tomcowland.com/?room={room}&user={user}"
        ] );
    }

}


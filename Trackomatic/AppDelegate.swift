//
//  Copyright (c) 2020, Tom Cowland. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//      * Redistributions of source code must retain the above
//        copyright notice, this list of conditions and the following
//        disclaimer.
//
//      * Redistributions in binary form must reproduce the above
//        copyright notice, this list of conditions and the following
//        disclaimer in the documentation and/or other materials provided with
//        the distribution.
//
//      * Neither the name of Tom Cowland nor the names of
//        any other contributors to this software may be used to endorse or
//        promote products derived from this software without specific prior
//        written permission.
//
//      * Any redistribution of the source code, it's binary form, or any
//        project derived from the source code must remain free of charge and
//        on a not for profit basis.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
//  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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


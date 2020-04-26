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
import WebKit

class ChatomaticViewController: NSViewController {

    @IBOutlet weak var tabContainer: NSTabView!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var infoSentLabel: NSTextField!

    var room : String? {
        didSet{ update(); }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad();
        update();
    }
    
    @IBAction func enabledClicked( _ sender: Any )
    {
        UserDefaults.standard.setValue( true, forKey: "chatEnabled" );
        update();
    }
    
    private func update()
    {
        if UserDefaults.standard.bool( forKey: "chatEnabled" )
        {
            tabContainer.selectLastTabViewItem( self );
            updateWebView( room: room );
        }
        else
        {
            var info = "";
            if let name = UserDefaults.standard.string( forKey: "displayName" ), let r = room
            {
                info = "Display Name:\n\(name)\nRoom:\n\(r)";
            }
            
            infoSentLabel.stringValue = info;
            tabContainer.selectFirstTabViewItem( self );
            updateWebView( room: nil );
        }
    }
    
    private func updateWebView( room: String? )
    {
        var urlString = "about:blank";
               
        if let r = room,
           let name = UserDefaults.standard.string( forKey: "displayName" ),
           let chatTemplateURL = UserDefaults.standard.string( forKey: "chatURL" )
        {
            let user = name.addingPercentEncoding( withAllowedCharacters: .urlQueryAllowed ) ?? "Unknown";
            urlString = chatTemplateURL.replacingOccurrences(of: "{room}", with: r );
            urlString = urlString.replacingOccurrences(of: "{name}", with: user );
        }

        guard let url = URL( string: urlString ) else {
            print( "Unlable to build URL from \(urlString)" );
            return;
        }

        let urlRequest = URLRequest( url: url );
        webView.load( urlRequest );
    }
}

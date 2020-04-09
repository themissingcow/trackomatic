//
//  ChatomaticViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 09/04/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
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
                info = "Display Name:\n\(name)\n\nProject ID:\n\(r)";
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
            urlString = urlString.replacingOccurrences(of: "{user}", with: user );
        }

        guard let url = URL( string: urlString ) else {
            print( "Unlable to build URL from \(urlString)" );
            return;
        }

        let urlRequest = URLRequest( url: url );
        webView.load( urlRequest );
    }
}

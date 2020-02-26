//
//  ViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 24/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

fileprivate enum Cells {
    static let Name = NSUserInterfaceItemIdentifier( rawValue: "NameCell" )
    static let Mixer = NSUserInterfaceItemIdentifier( rawValue: "MixerCell" )
    static let Waveform = NSUserInterfaceItemIdentifier( rawValue: "WaveformCell" )
}

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var trackTableView: NSTableView!
    
    
    
    @objc dynamic var player = MultiPlayer();
        
    @IBOutlet weak var position: NSSlider!
        
    @IBAction func openFolder(_ sender: Any)
    {
        let openPanel = NSOpenPanel();
        openPanel.canChooseFiles = false;
        openPanel.canChooseDirectories = true;
        openPanel.allowsMultipleSelection = false;
        
        openPanel.beginSheetModal( for: view.window! ){ ( result ) in

            if result == .OK
            {
                if let url = openPanel.url
                {
                    self.loadFromDirectory( dir: url );
                }
            }
        }
    }
    
    @IBAction func playPressed(_ sender: Any)
    {
        let frameTime = AVAudioFramePosition( position.doubleValue );
        player.play( atFrame: frameTime );
    }
    
    @IBAction func stopPressed(_ sender: Any)
    {
        player.stop();
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        
    }

    // MARK: - Loading
    
    func loadFromDirectory( dir: URL )
    {
        player.files = [];
        trackTableView.reloadData();
        
        do {
            
            let contents = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ]
            );
            
            let suppportedExtensions = Set( [ "aif", "wav" ] );
            var files: [ AVAudioFile ] = [];

            for url in contents
            {
                let info = try url.resourceValues(forKeys: [ .nameKey, .isDirectoryKey ] );
                
                if info.isDirectory! { continue; }
                if !suppportedExtensions.contains( url.pathExtension ) { continue; }
                
                do {
                    let file = try AVAudioFile(forReading: url );
                    files.append( file );
                }
                catch
                {
                    print( "Unable to load \(url)" );
                }
            }
            
            self.player.files = files;
            self.position.doubleValue = 0;
        }
        catch
        {
            print( "\(error)" );
        }
        
        self.trackTableView.reloadData();
    }
    
    // MARK: NSTableView
    
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        return player.files.count;
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        return player.files[ row ];
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        var cell: NSView?;
        
        if tableColumn == trackTableView.tableColumns[ 0 ]
        {
            // Name
            if let c = tableView.makeView( withIdentifier: Cells.Name, owner: nil ) as? TrackNameCellView
            {
                c.textField?.stringValue = player.files[ row ].url.lastPathComponent;
                cell = c;
            }
            
        }
        else if tableColumn == trackTableView.tableColumns[ 1 ]
        {
            // Mixer
            if let c = tableView.makeView( withIdentifier: Cells.Mixer, owner: nil ) as? TrackMixerCellView
            {
                c.state = player.states[ row ];
                cell = c;
            }
        }
        else
        {
            // Waveform
            if let c = tableView.makeView( withIdentifier: Cells.Waveform, owner: nil ) as? TrackWaveformCellView
            {
                c.state = player.states[ row ];
                cell = c;
            }
        }
        
        return cell;
    }
    
}


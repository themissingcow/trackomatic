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
    static let Mixer = NSUserInterfaceItemIdentifier( rawValue: "MixerCell" )
    static let Waveform = NSUserInterfaceItemIdentifier( rawValue: "WaveformCell" )
}

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, TimelineViewDelegate {
    
    @IBOutlet weak var trackTableView: NSTableView!
    @IBOutlet weak var timelineView: TimelineView!
    
    @objc dynamic var player = MultiPlayer();
    
    fileprivate var updateTimer: Timer?;
                
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
        player.play( atFrame: timelineView.position );
    }
    
    @IBAction func stopPressed(_ sender: Any)
    {
        player.stop();
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        timelineView.delegate = self;

        player.addObserver( self, forKeyPath: "playing", options: [.initial, .new] , context: nil );
    }
    
    // MARK: - Updates
        
    func setPlaybackTimers( playing: Bool )
    {
        if playing
        {
            updateTimer = Timer.scheduledTimer( withTimeInterval: 0.1, repeats: true ) { _ in
                self.timelineView.position = self.player.position;
            }
            updateTimer!.fire();
        }
        else
        {
            updateTimer?.invalidate();
            updateTimer = nil;
        }
    }

    // MARK: - Loading
    
    func loadFromDirectory( dir: URL )
    {
        player.stop();
        setPlaybackTimers( playing: false );
        
        player.files = [];
        trackTableView.reloadData();
        
        do {
            
            let contents = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [ .nameKey, .isDirectoryKey ]
            );
            
            let suppportedExtensions = Set( [ "aif", "wav", "mp3", "m4a" ] );
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
            self.timelineView.length = self.player.maxLength;
            self.timelineView.position = 1000;
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
    
    // MARK: - TimelineViewDelegate
    
    func timelineView(_ view: TimelineView, didRequestPositionChange position: AVAudioFramePosition)
    {
        self.timelineView.position = position;
        self.player.play( atFrame: position );
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if let player = object as? MultiPlayer
        {
            setPlaybackTimers( playing: player.playing );
        }
    }
}


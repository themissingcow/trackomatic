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
    static let Group = NSUserInterfaceItemIdentifier( rawValue: "GroupRow" )
    static let Mixer = NSUserInterfaceItemIdentifier( rawValue: "MixerCell" )
    static let Waveform = NSUserInterfaceItemIdentifier( rawValue: "WaveformCell" )
}

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, TimelineViewDelegate {
    
    @IBOutlet weak var trackTableView: NSTableView!
    @IBOutlet weak var timelineView: TimelineView!
    @IBOutlet weak var trackPlayheadView: TimelineView!
    
    @objc dynamic var player = MultiPlayer();
    @objc dynamic var project: Project?;
    
    fileprivate var rows: [ Any ] = [];
    
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
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        timelineView.delegate = self;

        player.addObserver( self, forKeyPath: "playing", options: [.initial, .new] , context: nil );
        player.addObserver( self, forKeyPath: "mixDirty", options: [ .new ], context: nil );
    }
        
    // MARK: - Updates
        
    private func setPlaybackTimers( playing: Bool )
    {
        if playing
        {
            updateTimer = Timer.scheduledTimer( withTimeInterval: 0.1, repeats: true ) { _ in
                self.timelineView.position = self.player.position;
                self.trackPlayheadView.position = self.player.position;
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

        setupPlayer( project: nil );
        setupTracksView( project: nil );

        project?.close();
        project = Project( baseDirectory: dir, watch: true );
        project?.addObserver( self, forKeyPath: "dirty", options: [ .new ], context: nil );
        project?.addObserver( self, forKeyPath: "audioFileGroups", options: [ .new ], context: nil );

        setupPlayer( project: project );
        setupTracksView( project: project );
        
        timelineView.length = player.length;
        trackPlayheadView.length = player.length;
        timelineView.position = 0;
        trackPlayheadView.position = 0;
    }
    
    private func setupPlayer( project: Project? )
    {
        if let p = project
        {
            player.files = p.audioFiles;
            player.load( url: p.userJsonURL( tag: "mix" ), baseDirectory: p.baseDirectory! );
        }
        else
        {
            player.files = [];
        }
    }
    
    private func setupTracksView( project: Project? )
    {
        if let p = project, let dir = p.baseDirectory
        {
            rows = rowsFrom( groups: p.audioFileGroups, baseDirectory: dir );
        }
        else
        {
            rows = [];
        }
        
        trackTableView.reloadData();
    }
    
    private func rowsFrom( groups: [ URL: [ AVAudioFile ] ], baseDirectory dir: URL ) -> [ Any ]
    {
        var rows: [ Any ] = [];
        
        if let rootFiles = groups[ dir ]
        {
            rows.append( contentsOf: rootFiles );
        }
        
        for ( url, files ) in groups
        {
            if url == dir { continue; }
            
            rows.append( url );
            rows.append( contentsOf: files );
        }
        
        return rows;
    }
    
    // MARK: NSTableView
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool
    {
        return rows[ row ] as? URL != nil;
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        return rows.count;
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        return rows[ row ];
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        var view: NSTableCellView?;
        
        // Groups are URLs in the row list, Tracks are AVAudioFiles
        
        if let groupUrl = rows[ row ] as? URL
        {
            view = tableView.makeView( withIdentifier: Cells.Group, owner: nil ) as? NSTableCellView;
            view?.textField?.stringValue = groupUrl.lastPathComponent;
        }
        else if let file = rows[ row ] as? AVAudioFile
        {
            let identifier = ( tableColumn == trackTableView.tableColumns[ 1 ]) ? Cells.Waveform : Cells.Mixer;
            let trackView = tableView.makeView( withIdentifier: identifier, owner: nil ) as? TrackTableCellView
            trackView?.track = player.trackFor( file: file );
            view = trackView;
        }
        
        return view;
    }
    
    // MARK: - TimelineViewDelegate
    
    func timelineView(_ view: TimelineView, didRequestPositionChange position: AVAudioFramePosition)
    {
        self.timelineView.position = position;
        self.player.play( atFrame: position );
    }
    
    // MARK: - Save
    
    private var saveMixDebounceTimer: Timer?;
    @objc private func saveMix( debounceDelay: TimeInterval = 0.0 )
    {
        if debounceDelay > 0.0
        {
            saveMixDebounceTimer?.invalidate();
            saveMixDebounceTimer = Timer.scheduledTimer( withTimeInterval: debounceDelay, repeats: false ) { _ in
                self.saveMix();
            }
        }
        else
        {
            if let p = project
            {
                if player.mixDirty {
                    player.save( url: p.userJsonURL( tag: "mix" ), baseDirectory: p.baseDirectory! );
                }
            }
        }
    }
    
    private var saveProjectDebounceTimer: Timer?;
    @objc private func saveProject( debounceDelay: TimeInterval = 0.0 )
    {
        if debounceDelay > 0.0
        {
            saveProjectDebounceTimer?.invalidate();
            saveProjectDebounceTimer = Timer.scheduledTimer( withTimeInterval: debounceDelay, repeats: false ) { _ in
                self.saveProject();
            }
        }
        else
        {
            if let p = project
            {
                if p.dirty
                {
                    p.save();
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if let player = object as? MultiPlayer
        {
            if keyPath == "playing"
            {
                setPlaybackTimers( playing: player.playing );
            }
            else if keyPath == "mixDirty"
            {
                saveMix( debounceDelay: 2.0 );
            }
        }
        else if let p = object as? Project
        {
            if keyPath == "dirty"
            {
                saveProject( debounceDelay: 2.0 );
            }
            else if keyPath == "audioFileGroups"
            {
                setupPlayer( project: p );
                setupTracksView( project: p );
            }
        }
    }

}

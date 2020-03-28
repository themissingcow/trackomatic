//
//  ViewController.swift
//  Trackomatic
//
//  Created by Tom Cowland on 24/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation
import WebKit

fileprivate enum Cells {
    static let Group = NSUserInterfaceItemIdentifier( rawValue: "GroupRow" )
    static let Mixer = NSUserInterfaceItemIdentifier( rawValue: "MixerCell" )
    static let Waveform = NSUserInterfaceItemIdentifier( rawValue: "WaveformCell" )
}

class ViewController: NSViewController,
        NSTableViewDelegate, NSTableViewDataSource,
        TimelineViewDelegate, TrackCommentsViewDelegate
{
    @IBOutlet weak var trackTableView: NSTableView!
    @IBOutlet weak var timelineView: TimelineView!
    @IBOutlet weak var trackPlayheadView: TimelineView!
    
    @IBOutlet weak var commentsTab: NSView!
    
    @IBOutlet weak var chatWebView: WKWebView!
    
    @IBOutlet weak var exportButton: NSButton!;
    
    @objc dynamic var selectedAnchor: String? { didSet { commentsView?.anchor = selectedAnchor; } };
    @IBOutlet weak var commentsPlaceholderView: NSView!
    private var commentsView: CommentsViewController?
    
    @objc dynamic var player = MultiPlayer();
    @objc dynamic var commentManager = CommentManager();
    @objc dynamic var project: Project?;
    
    fileprivate var rows: [ Any ] = [];
    
    fileprivate var updateTimer: Timer?;
    
    @IBAction func playPressed(_ sender: Any)
    {
        player.play( atTime: timelineView.position );
    }
    
    @IBAction func stopPressed(_ sender: Any)
    {
        player.stop();
    }
    
    @IBAction func exportMix( _ sender: Any )
    {
        let savePanel = NSSavePanel();
        savePanel.canCreateDirectories = true;
        savePanel.allowedFileTypes = [ "aif" ];
        
        savePanel.beginSheetModal( for: view.window! ){ ( result ) in

            if result == .OK
            {
                if let url = savePanel.url
                {
                    self.player.renderTo( output: url, settings: self.player.aiffSettings() );
                }
            }
        }
    }
    
    @IBAction func newComment( _ sender: Any )
    {
        newComment( forAnchor: selectedAnchor );
    }
    
    func newComment( forAnchor anchor: String?, at: Double? = nil, length: Double? = nil )
    {
        guard let vc = storyboard?.instantiateController(
            withIdentifier: NSStoryboard.SceneIdentifier( "newCommentController" )
        ) as? NewCommentViewController
            else { return; }
        
        let comment = commentManager.newComment( anchor: anchor, add: false );
        comment.at = at;
        comment.length = length;
        
        vc.comment = comment;
        vc.commentManager = commentManager;
        
        presentAsSheet( vc );
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
                
        timelineView.delegate = self;
        
        let defaults = UserDefaults.standard;
        commentManager.userShortName = defaults.string( forKey: "shortName" ) ?? "";
        commentManager.userDisplayName = defaults.string( forKey: "displayName" ) ?? "";
        commentManager.player = player;
        commentManager.addObserver( self, forKeyPath: "userCommentsDirty", options: [], context: nil );
        
        player.addObserver( self, forKeyPath: "playing", options: [.initial, .new] , context: nil );
        player.addObserver( self, forKeyPath: "mixDirty", options: [ .new ], context: nil );
        
        if let comments = storyboard!.instantiateController(
            withIdentifier : NSStoryboard.SceneIdentifier( "commentsViewController" )
            ) as? CommentsViewController
        {
            commentsView = comments;
        
            addChild( comments );
            comments.commentManager = commentManager;
            
            commentsTab.addSubview( comments.view );
            comments.view.translatesAutoresizingMaskIntoConstraints = false;
            comments.view.topAnchor.constraint( equalTo: commentsTab.topAnchor, constant: 40 ).isActive = true;
            comments.view.bottomAnchor.constraint( equalTo: commentsTab.bottomAnchor ).isActive = true;
            comments.view.leadingAnchor.constraint( equalTo: commentsTab.leadingAnchor ).isActive = true;
            comments.view.trailingAnchor.constraint( equalTo: commentsTab.trailingAnchor ).isActive = true;
            comments.view.heightAnchor.constraint( greaterThanOrEqualToConstant: 250 ).isActive = true;
        }
        
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
        
        view.window?.setTitleWithRepresentedFilename( dir.path );
        
        updateChat( project: project );
    }
    
    private func setupPlayer( project: Project? )
    {
        if let p = project
        {
            player.baseDirectory = p.baseDirectory;
            player.files = p.allAudioFiles();
            player.load( url: p.userJsonURL( tag: "mix" ) );
        }
        else
        {
            player.files = [];
            player.baseDirectory = nil;
        }
    }
    
    private func setupTracksView( project: Project? )
    {
        commentManager.reset();
        rows = [];

        if let p = project, let dir = p.baseDirectory
        {
            rows = rowsFrom( groups: p.audioFileGroups, baseDirectory: dir );
            commentManager.load( directory: p.sidecarDirectory(), tag: "comments" );
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
        
        let urls = groups.keys.sorted { (a, b) in return a.path < b.path };
        
        for url in urls
        {
            if url == dir { continue; }
            
            rows.append( url );
            rows.append( contentsOf: groups[url]! );
        }
        
        return rows;
    }
    
    // MARK: - Chat
    
    func updateChat( project: Project? )
    {
        var urlString = "about:blank";
        
        if let uuid = project?.uuid,
           let chatTemplateURL = UserDefaults.standard.string( forKey: "chatURL" )
        {
        
            let name = commentManager.userDisplayName;
            let encodedName = name.addingPercentEncoding( withAllowedCharacters: .urlQueryAllowed )
                  ?? commentManager.userShortName;
        
            urlString = chatTemplateURL.replacingOccurrences(of: "{project}", with: uuid );
            urlString = urlString.replacingOccurrences(of: "{user}", with: encodedName );
        }
            
        guard let url = URL( string: urlString ) else {
            print( "Unlable to build URL from \(urlString)" );
            return;
        }
        
        let urlRequest = URLRequest( url: url );
        chatWebView.load( urlRequest );
    }
    
    // MARK: - NSTableView
    
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
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
    {
        return rows[ row ] as? URL != nil ? NSTableRowView() : TrackRowView();
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
            let track = player.trackFor( file: file );
            
            let identifier = ( tableColumn == trackTableView.tableColumns[ 1 ]) ? Cells.Waveform : Cells.Mixer;
            let trackView = tableView.makeView( withIdentifier: identifier, owner: nil ) as? TrackTableCellView
            trackView?.track = track;
            
            if let waveformView = trackView as? TrackWaveformCellView
            {
                waveformView.commentView.anchor = track?.anchor() ?? "";
                waveformView.commentView.delegate = self;
                waveformView.commentView.length = player.length;
                waveformView.commentView.manager = commentManager;
                waveformView.commentView.highlightOnHover = true;
            }
            
            view = trackView;
        }
        
        return view;
    }
    
    func tableViewSelectionDidChange( _ notification: Notification )
    {
        let row = trackTableView.selectedRow;
        
        if row > -1,
            let file = rows[ row ] as? AVAudioFile,
            let track = player.trackFor( file: file )
        {
            let anchor = track.anchor();
            selectedAnchor = anchor;
        }
        else
        {
            // Project comments
            selectedAnchor = nil;
        }
    }
    
    // MARK: - TimelineViewDelegate
    
    func timelineView(_ view: TimelineView, didRequestPositionChange position: Double )
    {
        self.timelineView.position = position;
        self.player.play( atTime: position );
    }
    
    // MARK: - CommentViewDelegate
    
    func trackCommentsView( _ view: TrackCommentsView,
        requestedCommentAt position: Double, ofLength length: Double?
    ) {
        if let anchor = view.anchor
        {
            newComment( forAnchor: anchor, at: position, length: length );
        }
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
                    player.save( url: p.userJsonURL( tag: "mix" ) );
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
    
    private var saveCommentsDebounceTimer: Timer?;
    @objc private func saveComments( debounceDelay: TimeInterval = 0.0 )
    {
        if debounceDelay > 0.0
        {
            saveCommentsDebounceTimer?.invalidate();
            saveCommentsDebounceTimer = Timer.scheduledTimer( withTimeInterval: debounceDelay, repeats: false ) { _ in
                self.saveComments();
            }
        }
        else
        {
            if let p = project
            {
                if commentManager.userCommentsDirty
                {
                    let url = p.userJsonURL( tag: "comments" );
                    commentManager.save( url: url );
                }
            }
        }
    }
    
    // MARK: - KVO
    
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
        else if object as? CommentManager != nil
        {
            if keyPath == "userCommentsDirty"
            {
                saveComments( debounceDelay: 2.0 );
            }
        }
    }

}

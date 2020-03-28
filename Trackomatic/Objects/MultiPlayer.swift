//
//  MultiPlayer.swift
//  Trackomatic
//
//  Created by Tom Cowland on 24/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa
import AVFoundation

class MultiPlayer : NSObject {
    
    class Track : NSObject {
        
        // A muted track does not play unless it is solo'd.
        // Setting solo on one or more tracks overrides any existing mutes.
        @objc dynamic var mute = false { didSet { parent.mixDirty = true; } }
        @objc dynamic var solo = false { didSet { parent.mixDirty = true; } }
        
        @objc dynamic var loop = false { didSet { parent.mixDirty = true; } }
        
        @objc dynamic var volume: Float = 1.0 {
            didSet {
                player.volume = volume;
                parent.mixDirty = true;
            }
        }
        
        @objc dynamic var pan: Float = 0.0 {
            didSet {
                player.pan = pan;
                parent.mixDirty = true;
            }
       }

        @objc dynamic public fileprivate(set) var file: AVAudioFile!;
        
        var length: Double {
            return Double(file.length) / file.fileFormat.sampleRate;
        }
        
        @objc dynamic weak public fileprivate(set) var parent: MultiPlayer!;
        
        fileprivate var player: AVAudioPlayerNode!;
        fileprivate var muteMixer: AVAudioMixerNode!;
        
        func anchor() -> String?
        {
            guard let base = parent.baseDirectory else { return nil; }
            
            let basePathLength = base.path.count;
            let path = file.url.path;
            let pathStart = path.index( path.startIndex, offsetBy: basePathLength + 1 );
            return String( file.url.path[ pathStart... ] );
        }
    }
    
    // MARK: - Pubic properties
    
    var safeStart: TimeInterval = 0.1;
    @objc dynamic var mixDirty = false;
    
    @objc dynamic var sampleRate: Double = 44100.0;
    
    // MARK: - Files
    
    var baseDirectory: URL?;
    
    var files: [ AVAudioFile ] = []
    {
        didSet { setupFrom( files: files ); }
    };
    
    // MARK: - Tracks
    
    @objc dynamic public private(set) var tracks: [ Track ] = [];
    
    func trackFor( file: AVAudioFile ) -> Track?
    {
        return tracks.first { track in
            return track.file == file;
        }
    }
    
    func trackFor( url: URL ) -> Track?
    {
        return tracks.first { track in
            return track.file.url == url;
        }
    }
    
    func trackFor( anchor: String ) -> Track?
    {
        guard let base = baseDirectory else { return nil; }
        let trackURL = URL.init( fileURLWithPath: "\(base.path)/\(anchor)" );
        return trackFor( url: trackURL );
    }
    
    // MARK: - Internal vars

    internal var audioFormat: AVAudioFormat;
    internal var engine: AVAudioEngine;
    internal var mixer: AVAudioMixerNode;
    internal var lastPlayStart: AVAudioFramePosition;
    internal var keyPlayer: AVAudioPlayerNode?;
    
    // MARK: Init
    
    override init()
    {
        lastPlayStart = 0;
        
        // TODO: Move to project sample rate
        audioFormat = AVAudioFormat( standardFormatWithSampleRate: sampleRate, channels: 2 )!;
        
        engine = AVAudioEngine();
        mixer = AVAudioMixerNode();
        
        engine.attach( mixer );
        engine.connect( mixer, to: engine.outputNode, fromBus: 0, toBus: 0, format: audioFormat );
        
        do
        {
            try self.engine.start();
        }
        catch
        {
            print( "Error initialising engine: \(error)" );
        }
        
        super.init();
    }
    
    // MARK: - Transport Control
    
    @objc dynamic var playing: Bool = false;
    
    @objc dynamic var length: Double {
        return Double( frameLength ) / sampleRate;
    }
    
    // We use frames internally so we can maintain accuracy when no SRC is needed
    @objc public private(set) dynamic var frameLength: AVAudioFramePosition = 0 {
        willSet { willChangeValue( forKey: "length" ); }
        didSet { didChangeValue( forKey: "length"); }
    }

    // TODO: Move to the more normal play/stop/position, where seeking is achieved by setting position.

    var position: Double
    {
       if let player = keyPlayer, let time = player.lastRenderTime
       {
            var sampleTime = lastPlayStart;
            if time.isSampleTimeValid
            {
               sampleTime += ( player.playerTime( forNodeTime: time )?.sampleTime ?? 0 );
            }
            return Double( sampleTime ) / sampleRate;
       }
       return 0;
    }
    
    func play( atTime time: Double = 0, offline: Bool = false )
    {
        play( atFrame: AVAudioFramePosition( time * sampleRate ), offline: offline );
    }
    
    private func play( atFrame frame: AVAudioFramePosition = 0, offline: Bool = false )
    {
        if tracks.count == 0 { return; }
        
        lastPlayStart = frame;
        
        self.stop();

        let scheduleOffset = AVAudioFramePosition( audioFormat.sampleRate * safeStart );
        let scheduleTime = ( tracks[0].player.lastRenderTime?.sampleTime ?? 0 ) + scheduleOffset;

        for file in files
        {
            let track = trackFor( file: file )!;
            
            var startFrame = frame;
            
            // If we're not looping and we're past the end, we have nothing to do.
            if file.length <= startFrame
            {
                if track.loop
                {
                    startFrame = startFrame % file.length;
                }
                else
                {
                    continue;
                }
            }
            
            let remainingSamples = AUAudioFrameCount( file.length - startFrame );
            
            func rescheduler( _ : AVAudioPlayerNodeCompletionCallbackType )
            {
                // Check nothing has changed since we started
                if !playing || !track.loop { return; }
                
                track.player.scheduleFile(
                    file, at: nil,
                    completionCallbackType: .dataConsumed, completionHandler: rescheduler
                );
            };

            track.player.scheduleSegment(
                file, startingFrame: startFrame, frameCount: remainingSamples, at: nil,
                completionCallbackType: .dataConsumed, completionHandler: track.loop ? rescheduler : nil
            )
            
            track.player.prepare( withFrameCount: AVAudioFrameCount( audioFormat.sampleRate) );
        }
        
        for track in tracks
        {
            if offline
            {
                track.player.play();
            }
            else
            {
                track.player.play( at: AVAudioTime( sampleTime: scheduleTime, atRate: audioFormat.sampleRate ) );
            }
        }
        playing = true;
    }
    
    func stop()
    {
        playing = false;
        for track in tracks
        {
            track.player.stop();
        }
    }
    
    // MARK: - Track Management

    private func setupFrom( files: [ AVAudioFile ] )
    {
        ensureTracks( count: files.count );
        
        frameLength = 0;
        keyPlayer = nil;
        resetMix();

        for ( index, file ) in files.enumerated()
        {
            tracks[ index ].file = file;
            
            let fileFrameLength: AVAudioFramePosition = file.fileFormat.sampleRate == sampleRate
                ? file.length
                : AVAudioFramePosition( ( Double( file.length ) / file.fileFormat.sampleRate ) * sampleRate );
            
            if fileFrameLength > frameLength
            {
                frameLength = fileFrameLength;
                keyPlayer = tracks[ index ].player;
            }
        }
        
        for track in tracks
        {
            // Automaticlly turn on loop for relatively short files
            if track.length < ( length / 2 )
            {
                track.loop = true;
            }
        }
    }
    
    private func ensureTracks( count: Int )
    {
        while tracks.count > count
        {
            let track = tracks.popLast()!;

            track.player.stop();
            engine.disconnectNodeOutput( track.player );
            engine.detach( track.player );

            engine.disconnectNodeOutput( track.muteMixer );
            engine.detach( track.muteMixer );

            removeObservers( track: track );
        }
            
        while tracks.count < count
        {
            let track = Track();
            track.parent = self;

            track.player = AVAudioPlayerNode();
            engine.attach( track.player );

            track.muteMixer = AVAudioMixerNode();
            engine.attach( track.muteMixer );

            addObservers( track: track );
            tracks.append( track );

            engine.connect( track.player, to: track.muteMixer, fromBus: 0, toBus: 0, format: audioFormat );
            engine.connect( track.muteMixer, to: mixer, fromBus: 0, toBus: tracks.count - 1, format: audioFormat );
        }
    }
    
    // MARK: - mute/solo
    
    func resetMix()
    {
        for track in tracks {
            track.volume = 1.0;
            track.pan = 0.0;
            track.loop = false;
            track.mute = false;
            track.solo = false;
        }
        mixDirty = false;
    }
    
    func clearMutes()
    {
        for track in tracks {
            track.mute = false;
        }
    }
    
    func clearSolos()
    {
        for track in tracks {
            track.solo = false;
        }
    }
    
    private func applyMuteState()
    {
        let haveSolo = tracks.reduce( false ) { ( prev, track ) in return prev || track.solo };
        if haveSolo
        {
            for track in tracks
            {
                track.muteMixer.outputVolume = track.solo ? 1.0 : 0.0;
            }
        }
        else
        {
            for track in tracks
            {
                track.muteMixer.outputVolume = track.mute ? 0.0 : 1.0;
            }
        }
    }
    
    private func addObservers( track: Track )
    {
        track.addObserver( self, forKeyPath: "mute", options: .new, context: nil );
        track.addObserver( self, forKeyPath: "solo", options: .new, context: nil );
    }
    
    private func removeObservers( track: Track )
    {
        track.removeObserver( self, forKeyPath: "mute" );
        track.removeObserver( self, forKeyPath: "solo" );
    }
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?
    ) {
        if object as? Track != nil
        {
            applyMuteState();
        }
    }
}

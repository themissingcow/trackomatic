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
    
    class TrackState : NSObject {
        
        @objc dynamic var mute = false;
        @objc dynamic var solo = false;
        
        @objc dynamic weak var player: AVAudioPlayerNode!;
        @objc dynamic weak var file: AVAudioFile!;
        
        @objc dynamic var projectLength: Int64 = 0;
        
        fileprivate weak var muteMixer: AVAudioMixerNode!;

    }
    
    // MARK: - Pubic properties
    
    var safeStart: TimeInterval = 0.1;
    @objc dynamic var maxLength: AVAudioFramePosition = 0;
    
    var files: [ AVAudioFile ] { didSet { setupFrom( files: files ); } }

    var position: AVAudioFramePosition
    {
        if let player = keyPlayer, let time = player.lastRenderTime
        {
            return player.playerTime( forNodeTime: time )?.sampleTime ?? 0;
        }
        return 0;
    }
    
    @objc dynamic var states: [ TrackState ];

    // MARK: - Internal vars

    fileprivate var audioFormat: AVAudioFormat;
    fileprivate var engine: AVAudioEngine;
    fileprivate var mixer: AVAudioMixerNode;
    fileprivate var lastPlayHostTime: UInt64?;
    fileprivate var keyPlayer: AVAudioPlayerNode?;
    fileprivate var players : [ AVAudioPlayerNode ];
    fileprivate var muteMixers : [ AVAudioMixerNode ];
    
    // MARK: Init
    
    override init()
    {
        files = [];
        players = [];
        muteMixers = [];
        states = [];
        
        audioFormat = AVAudioFormat( standardFormatWithSampleRate: 44100.0, channels: 2 )!;
        
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
    
    func play( atFrame: AVAudioFramePosition = 0 )
    {
        if players.count == 0 { return; }
    
        let scheduleTime = ( players[0].lastRenderTime?.sampleTime ?? 0 ) + Int64( 44100.0 * safeStart );
                
        for i in 0..<files.count
        {
            let file = files[ i ];
            let player = players[ i ];
                        
            var startFrame = atFrame;
            if file.length <= atFrame
            {
                startFrame = atFrame % file.length;
            }
            
            let remainingSamples = AUAudioFrameCount( file.length - startFrame );
                        
            player.scheduleSegment( file, startingFrame: startFrame, frameCount: remainingSamples, at: nil ) {
                player.scheduleFile( file, at: nil );
            };
            
            player.prepare( withFrameCount: 44100 );
        }
        
        for player in players
        {
            player.play( at: AVAudioTime( sampleTime: scheduleTime, atRate: 44100 ) );
        }
    }
    
    func stop()
    {
        for player in players
        {
            player.stop();
            player.reset();
            player.stop();
        }
    }
    
    // MARK: - Player Management

    func setupFrom( files: [ AVAudioFile ] )
    {
        while players.count > files.count
        {
            let player = players.popLast()!;
            player.stop();
            engine.disconnectNodeOutput( player );
            engine.detach( player );
            let muteMixer = muteMixers.popLast()!;
            engine.disconnectNodeOutput( muteMixer );
            engine.detach( muteMixer );
            let state = states.popLast()!;
            removeStateObservers( state: state );
        }
             
        while players.count < files.count
        {
            let player = AVAudioPlayerNode();
            players.append( player );
            engine.attach( player );
            let index = players.firstIndex( of: player )!;
            let muteMixer = AVAudioMixerNode();
            muteMixers.append( muteMixer );
            engine.attach( muteMixer );
            engine.connect( player, to: muteMixer, fromBus: 0, toBus: 0, format: audioFormat );
            engine.connect( muteMixer, to: mixer, fromBus: 0, toBus: index, format: audioFormat );
            let state = TrackState()
            state.player = player;
            state.muteMixer = muteMixer;
            addStateObservers( state: state );
            states.append( state );
        }
        
        maxLength = 0;
        keyPlayer = nil;
        for i in 0..<files.count
        {
            let file = files[ i ];
            states[ i ].file = file;
            if file.length > maxLength
            {
                maxLength = file.length;
                keyPlayer = players[ i ];
            }
        }
        for state in states
        {
            state.projectLength = maxLength;
        }
    }
    
    // MARK: - mute/solo
    
    func clearMutes()
    {
        for s in states {
            s.mute = false;
        }
    }
    
    func clearSolos()
    {
        for s in states {
            s.solo = false;
        }
    }
    
    private func applyMuteState()
    {
        let haveSolo = states.reduce( false ) { (prev, state) in return prev || state.solo };

        if haveSolo
        {
            for state in states
            {
                state.muteMixer.outputVolume = state.solo ? 1.0 : 0.0;
            }
        }
        else
        {
            for state in states
            {
                state.muteMixer.outputVolume = state.mute ? 0.0 : 1.0;
            }
        }
    }
    
    private func addStateObservers( state: TrackState )
    {
        state.addObserver( self, forKeyPath: "mute", options: .new, context: nil );
        state.addObserver( self, forKeyPath: "solo", options: .new, context: nil );
    }
    
    private func removeStateObservers( state: TrackState )
    {
        state.removeObserver( self, forKeyPath: "mute" );
        state.removeObserver( self, forKeyPath: "solo" );
    }
    
    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        if object as? TrackState != nil {
            applyMuteState();
        }
    }
}

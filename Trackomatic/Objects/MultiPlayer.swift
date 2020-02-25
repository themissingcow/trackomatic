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
    
    // MARK: - Pubic properties
    
    var safeStart: TimeInterval = 0.1;
    @objc dynamic var maxLength: AVAudioFramePosition = 0;
    
    var files: [ AVAudioFile ] { didSet { setupFrom( files: files ); } }
    var players : [ AVAudioPlayerNode ];

    var position: AVAudioFramePosition
    {
        if let player = keyPlayer, let time = player.lastRenderTime
        {
            return player.playerTime( forNodeTime: time )?.sampleTime ?? 0;
        }
        return 0;
    }

    // MARK: - Internal vars
    
    fileprivate var audioFormat: AVAudioFormat;
    fileprivate var engine: AVAudioEngine;
    fileprivate var mixer: AVAudioMixerNode;
    fileprivate var lastPlayHostTime: UInt64?;
    fileprivate var keyPlayer: AVAudioPlayerNode?;
    
    // MARK: Init
    
    override init()
    {
        files = [];
        players = [];
        
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
        }
             
        while players.count < files.count
        {
            let player = AVAudioPlayerNode();
            players.append( player );
            engine.attach( player );
            let index = players.firstIndex( of: player )!;
            engine.connect( player, to: mixer, fromBus: 0, toBus: index, format: audioFormat );
        }
        
        maxLength = 0;
        keyPlayer = nil;
        for i in 0..<files.count
        {
            let file = files[ i ];
            if file.length > maxLength
            {
                maxLength = file.length;
                keyPlayer = players[ i ];
            }
        }
    }
}

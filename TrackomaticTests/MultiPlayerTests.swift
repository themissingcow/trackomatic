//
//  TrackomaticTests.swift
//  TrackomaticTests
//
//  Created by Tom Cowland on 24/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import XCTest
@testable import Trackomatic

import AVFoundation

extension AVAudioPCMBuffer
{
    func isNull( tollerance: Float = 0.0 ) -> Bool {
        
        let length: Int = Int( format.channelCount * frameLength );
        
        if let floatSamples = floatChannelData {
            for i in 0..<length {
                let v = abs( floatSamples.pointee[ i ] );
                XCTAssertLessThanOrEqual( v , tollerance );
                if v > tollerance {
                    return false;
                }
            }
        }
        else
        {
            fatalError( "No sample data" );
        }

        return true;
    }
}

class MultiPlayerTests: XCTestCase {
    
    
    func load44100Nulls( player: MultiPlayer )
    {
        var files: [ AVAudioFile ] = [];
               
        let sources = [ "44100_beat", "44100_beat_inverted" ];

        for source in sources
        {
            do {
                let bundle = Bundle( for: MultiPlayerTests.self );
                let url = URL( fileURLWithPath: bundle.path(forResource: source, ofType: "aif" )! );
                let audio = try AVAudioFile( forReading: url );
                files.append( audio );
            }
            catch
            {
                fatalError( "\(error)" )
            }
        }

        player.files = files;
        
        // Force a loop
        player.frameLength = player.frameLength * 3;
    }
    
    func checkPlaybackIsNull( player: MultiPlayer, tollerance: Float = 0.0  )
    {
        var checkedSamples:AVAudioFrameCount = 0;
        var isNull = true;

        player.mixer.installTap( onBus: 0, bufferSize: 4096, format: player.mixer.outputFormat(forBus: 0) ) { ( buffer, when ) in
           
           isNull = isNull && buffer.isNull( tollerance: tollerance );
           checkedSamples += buffer.frameLength;
        }
        
        player.play();

        while isNull && ( checkedSamples < ( player.frameLength / 2 ) )
        {
            sleep( 1 );
        }

        XCTAssertTrue( isNull );

        player.stop();
        player.mixer.removeTap( onBus: 0 );
    }
    
    func checkOutputIsNull( player: MultiPlayer, tollerance: Float = 0.0 ) -> AVAudioFile
    {
        var settings: [ String: Any ] = [:];
        settings[ AVFormatIDKey ] = kAudioFormatLinearPCM;
        settings[ AVSampleRateKey ] = player.sampleRate;
        settings[ AVNumberOfChannelsKey ] = player.audioFormat.channelCount;
        settings[ AVLinearPCMBitDepthKey ] = 32;
        
        let outputURL = URL.init( fileURLWithPath: NSTemporaryDirectory() ).appendingPathComponent( "out.aif" );

        player.renderTo( output: outputURL, settings: settings );
        
        do {
            let result = try AVAudioFile( forReading: outputURL );
            let buffer = AVAudioPCMBuffer( pcmFormat: result.processingFormat, frameCapacity: AVAudioFrameCount(result.length) )!;
            try result.read( into: buffer );
            
            XCTAssertTrue( buffer.isNull( tollerance: tollerance ) );
            
            return result;
        }
        catch
        {
            fatalError( "\(error)" );
        }
    }
    
    func testPlaybackNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        load44100Nulls( player: player );
        checkPlaybackIsNull( player:  player );
    }

    func testRenderNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        load44100Nulls( player: player );
        let output = checkOutputIsNull( player: player );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 44100.0 );
    }
    
    func testPlaybackNulls96000w44100files()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        load44100Nulls( player: player );
        checkPlaybackIsNull( player:  player, tollerance: 0.0001 );
    }

    func testRenderNulls96000w44100files()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        load44100Nulls( player: player );
        let output = checkOutputIsNull( player: player, tollerance: 0.0001 );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 96000.0 );
    }

}

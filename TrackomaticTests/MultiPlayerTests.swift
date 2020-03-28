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
    var isNull: Bool {
        
        let length: Int = Int( format.channelCount * frameLength );
        
        if let floatSamples = floatChannelData {
            for i in 0..<length {
                if floatSamples.pointee[ i ] != Float(0.0) {
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
    
    func testPlaybackNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
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
            
        var checkedSamples:AVAudioFrameCount = 0;
        var isNull = true;
    
        player.mixer.installTap( onBus: 0, bufferSize: 4096, format: player.mixer.outputFormat(forBus: 0) ) { ( buffer, when ) in
            
            isNull = isNull && buffer.isNull;
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

    func testRenderNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
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
        player.frameLength = player.frameLength * 5;
        
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
            
            XCTAssertTrue( buffer.isNull );
        }
        catch
        {
            fatalError( "\(error)" );
        }
        
        
    }

}

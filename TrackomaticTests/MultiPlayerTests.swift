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
        print( "Checking \(length) samples" );
                
        if let floatSamples = floatChannelData {
            for var i in 0..<length {
                if floatSamples.pointee[ i ] != Float(0.0) {
                    return false;
                }
            }
        }
        else
        {
            fatalError( "No float data" );
        }

        return true;
    }
}

class MultiPlayerTests: XCTestCase {

    func testRenderNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        var files: [ AVAudioFile ] = [];
        
        let sources = [ "44100_beat", "44100_beat_inverted" ];
        for var source in sources
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

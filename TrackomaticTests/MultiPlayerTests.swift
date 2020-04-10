//
//  Copyright (c) 2020, Tom Cowland. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//      * Redistributions of source code must retain the above
//        copyright notice, this list of conditions and the following
//        disclaimer.
//
//      * Redistributions in binary form must reproduce the above
//        copyright notice, this list of conditions and the following
//        disclaimer in the documentation and/or other materials provided with
//        the distribution.
//
//      * Neither the name of Tom Cowland nor the names of
//        any other contributors to this software may be used to endorse or
//        promote products derived from this software without specific prior
//        written permission.
//
//      * Any redistribution of the source code, it's binary form, or any
//        project derived from the source code must remain free of charge and
//        on a not for profit basis.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
//  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
    
    func loadFiles( player: MultiPlayer, sources : [ String ] )
    {
        var files: [ AVAudioFile ] = [];

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
        
        var all = player.files;
        all.append( contentsOf: files );
        player.files = all;
    }
      
    func load44100Nulls( player: MultiPlayer )
    {
        loadFiles( player: player, sources: [ "44100_beat", "44100_beat_inverted" ] );
    }
    
    func load96000Nulls( player: MultiPlayer )
    {
        loadFiles( player: player, sources: [ "96000_beat", "96000_beat_inverted" ] );
    }
    
    func loadMixedNulls( player : MultiPlayer )
    {
        loadFiles( player: player, sources: [ "44100_beat", "96000_beat_inverted" ] );
    }
    
    func checkPlaybackIsNull( player: MultiPlayer, position: Double = 0.0, tollerance: Float = 0.0  )
    {
        var checkedSamples:AVAudioFrameCount = 0;
        var isNull = true;

        player.mixer.installTap( onBus: 0, bufferSize: 4096, format: player.mixer.outputFormat(forBus: 0) ) { ( buffer, when ) in
           
           isNull = isNull && buffer.isNull( tollerance: tollerance );
           checkedSamples += buffer.frameLength;
        }
        
        player.play( atTime: position, offline: false );

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
    
    // MARK: - 44.1k
    
    func testPlaybackNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        load44100Nulls( player: player );
        // Force a loop
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player );
    }
    
    func testPlaybackSeekNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;

        load44100Nulls( player: player );
        // Force a loop
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player, position: 1.37 );
    }

    func testRenderNulls44100()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        load44100Nulls( player: player );
        // Force a loop
        player.frameLength = player.frameLength * 3;
        
        let output = checkOutputIsNull( player: player );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 44100.0 );
    }
    
    // MARK: - 96k
    
    func testPlaybackNulls96000()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        load96000Nulls( player: player );
        // Force a loop
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player );
    }
    
    func testPlaybackSeekNulls96000()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;

        load96000Nulls( player: player );
        // Force a loop
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player, position: 1.37 );
    }

    func testRenderNulls96000()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        load96000Nulls( player: player );
        // Force a loop
        player.frameLength = player.frameLength * 3;
        
        let output = checkOutputIsNull( player: player );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 96000.0 );
    }
    
    // MARK: - Mixed rates, matching pairs
    
    func testPlaybackNulls44100wMixedFiles()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        load44100Nulls( player: player );
        load96000Nulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player, tollerance: 0.0001 );
    }

    func testRenderNulls44100wMixedFiles()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        load44100Nulls( player: player );
        load96000Nulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        let output = checkOutputIsNull( player: player, tollerance: 0.0001 );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 44100.0 );
    }
    
    func testPlaybackNulls96000wMixedFiles()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        load44100Nulls( player: player );
        load96000Nulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player, tollerance: 0.0001 );
    }

    func testRenderNulls96000wMixedFiles()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        load44100Nulls( player: player );
        load96000Nulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        let output = checkOutputIsNull( player: player, tollerance: 0.0001 );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 96000.0 );
    }
    
    // MARK: - Mixed pair
    
    func testPlaybackNulls44100wMixedPair()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        loadMixedNulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player, tollerance: 0.001 );
    }
    
    func testPlaybackSeekNulls44100wMixedPair()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;

        loadMixedNulls( player: player );
        
        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;

        checkPlaybackIsNull( player: player, position: 5.76, tollerance: 0.001 );
    }

    func testRenderNulls44100wMixedPair()
    {
        let player = MultiPlayer();
        player.sampleRate = 44100.0;
        
        loadMixedNulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        let output = checkOutputIsNull( player: player, tollerance: 0.001 );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 44100.0 );
    }

    
    func testPlaybackNulls96000wMixedPair()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        loadMixedNulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        checkPlaybackIsNull( player: player, tollerance: 0.001 );
    }
    
    func testPlaybackSeekNulls96000wMixedPair()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;

        loadMixedNulls( player: player );
        
        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;

        checkPlaybackIsNull( player: player, position: 5.76, tollerance: 0.001 );
    }

    func testRenderNulls96000wMixedPair()
    {
        let player = MultiPlayer();
        player.sampleRate = 96000.0;
        
        loadMixedNulls( player: player );

        // Force a loop
        player.tracks.forEach { track in track.loop = true; }
        player.frameLength = player.frameLength * 3;
        
        let output = checkOutputIsNull( player: player, tollerance: 0.001 );
        
        XCTAssertTrue( output.fileFormat.sampleRate == 96000.0 );
    }
    
    // MARK: - AVAudioFile SR conversion helpers
    
    func testLengthConversion()
    {
        do {
            let bundle = Bundle( for: MultiPlayerTests.self );
            
            let url44100 = URL( fileURLWithPath: bundle.path(forResource: "44100_beat", ofType: "aif" )! );
            let audio44100 = try AVAudioFile( forReading: url44100 );
            let url96000 = URL( fileURLWithPath: bundle.path(forResource: "96000_beat", ofType: "aif" )! );
            let audio96000 = try AVAudioFile( forReading: url96000 );
            
            XCTAssertEqual( audio44100.length( atSampleRate: 44100.0 ), audio44100.length );
            XCTAssertEqual( audio96000.length( atSampleRate: 96000.0 ), audio96000.length );
                        
            XCTAssertEqual(
                audio44100.length( atSampleRate: 88200.0 ),
                audio44100.length * 2
            );
            
            XCTAssertEqual(
                audio96000.length( atSampleRate: 48000.0 ),
                audio96000.length / 2
            );
        }
        catch
        {
            fatalError( "\(error)" )
        }
    }
    
    func testPositionConversion()
    {
        do {
            let bundle = Bundle( for: MultiPlayerTests.self );
            
            let url44100 = URL( fileURLWithPath: bundle.path(forResource: "44100_beat", ofType: "aif" )! );
            let audio44100 = try AVAudioFile( forReading: url44100 );
            let url96000 = URL( fileURLWithPath: bundle.path(forResource: "96000_beat", ofType: "aif" )! );
            let audio96000 = try AVAudioFile( forReading: url96000 );
            
            XCTAssertEqual( audio44100.equivalent( positionTo: 1000, atSampleRate: 44100.0 ), 1000 );
            XCTAssertEqual( audio96000.equivalent( positionTo: 1000, atSampleRate: 96000.0 ), 1000 );

            XCTAssertEqual(
                audio44100.equivalent( positionTo: 1100, atSampleRate: 88200.0 ),
                550
            );
            
            XCTAssertEqual(
                audio96000.equivalent( positionTo: 2200, atSampleRate: 48000.0 ),
                4400
            );
        }
        catch
        {
            fatalError( "\(error)" )
        }
    }
    
}
